import { Layout } from .kernel.memory.layout;
import .kernel.memory.phys;

pub const status_ok: i32 = 0;
pub const status_not_initialized: i32 = 1;
pub const status_zero_size: i32 = 2;
pub const status_invalid_alignment: i32 = 3;
pub const status_out_of_pages: i32 = 4;
pub const status_non_contiguous_pre_vm_page: i32 = 5;
pub const status_deallocate_unsupported: i32 = 6;
pub const status_address_overflow: i32 = 7;
pub const status_virtual_map_failed: i32 = 8;

const max_usize: usize = 0 - 1;

extern c("cycor_heap_map_virtual_page") fn heap_map_virtual_page(virtual_addr: c_ulong): c_ulong;

pub struct HeapSnapshot {
    pub page_size: usize;
    pub start: usize;
    pub end: usize;
    pub next: usize;
    pub committed_pages: usize;
    pub used_bytes: usize;
    pub requested_bytes: usize;
    pub virtual_start: usize;
    pub virtual_end: usize;
    pub virtual_next: usize;
    pub returns_virtual: bool;
}

var page_size: usize = 0;
var heap_start: usize = 0;
var heap_end: usize = 0;
var heap_next: usize = 0;
var committed_pages: usize = 0;
var requested_bytes: usize = 0;
var heap_virtual_start: usize = 0;
var heap_virtual_next: usize = 0;
var returns_virtual_addresses = false;
var last_status: i32 = status_not_initialized;

// `heap` is the kernel object allocation policy, not the physical frame
// allocator. It requests pages from `phys`, then suballocates smaller aligned
// ranges inside those committed pages. The first policy is bump-only; reuse can
// be added later without changing callers.

fn align_up(value: usize, alignment: usize): usize {
    return (value + alignment - 1) & (0 - alignment);
}

fn is_power_of_two(value: usize): bool {
    if value == 0 {
        return false;
    }
    return (value & (value - 1)) == 0;
}

pub fn init(map: Layout): void {
    page_size = map.page_size;
    heap_start = 0;
    heap_end = 0;
    heap_next = 0;
    committed_pages = 0;
    requested_bytes = 0;
    heap_virtual_start = 0;
    heap_virtual_next = 0;
    returns_virtual_addresses = false;
    last_status = status_ok;
}

fn commit_page(): bool {
    if returns_virtual_addresses {
        if committed_pages * page_size > max_usize - heap_virtual_start {
            last_status = status_address_overflow;
            return false;
        }
        const virtual_page = heap_virtual_start + (committed_pages * page_size);
        const mapped = heap_map_virtual_page(virtual_page as c_ulong);
        if mapped == 0 {
            last_status = status_virtual_map_failed;
            return false;
        }
        if heap_end > max_usize - page_size {
            last_status = status_address_overflow;
            return false;
        }
        heap_end = heap_end + page_size;
        committed_pages = committed_pages + 1;
        return true;
    }

    const page = phys.alloc_page();
    if page == 0 {
        last_status = status_out_of_pages;
        return false;
    }
    if page > max_usize - page_size {
        last_status = status_address_overflow;
        if !phys.free_page(page) {
            return false;
        }
        return false;
    }

    if committed_pages == 0 {
        heap_start = page;
        heap_end = page + page_size;
        heap_next = page;
        committed_pages = 1;
        return true;
    }

    // Pre-VM heap pages are kept contiguous so the boot memory map can describe
    // them with one `pre_vm_heap` row. Once VM exists, this module should switch
    // to reserving a virtual heap range and map arbitrary physical frames into
    // it instead of requiring contiguous physical pages.
    if page != heap_end {
        if !phys.free_page(page) {
            last_status = status_non_contiguous_pre_vm_page;
            return false;
        }
        last_status = status_non_contiguous_pre_vm_page;
        return false;
    }
    if heap_end > max_usize - page_size {
        last_status = status_address_overflow;
        if !phys.free_page(page) {
            return false;
        }
        return false;
    }

    heap_end = heap_end + page_size;
    committed_pages = committed_pages + 1;
    return true;
}

fn ensure_committed(limit: usize): bool {
    while heap_end < limit {
        if !commit_page() {
            return false;
        }
    }
    return true;
}

pub fn allocate(size: usize, alignment: usize): usize {
    if size == 0 {
        last_status = status_zero_size;
        return 0;
    }
    if !is_power_of_two(alignment) {
        last_status = status_invalid_alignment;
        return 0;
    }
    if page_size == 0 {
        last_status = status_not_initialized;
        return 0;
    }
    if requested_bytes > max_usize - size {
        last_status = status_address_overflow;
        return 0;
    }

    if committed_pages == 0 {
        if !commit_page() {
            return 0;
        }
    }

    const align_padding = alignment - 1;
    if heap_next > max_usize - align_padding {
        last_status = status_address_overflow;
        return 0;
    }
    const base = align_up(heap_next, alignment);
    if base > max_usize - size {
        last_status = status_address_overflow;
        return 0;
    }
    const end = base + size;
    if !ensure_committed(end) {
        return 0;
    }

    heap_next = end;
    if returns_virtual_addresses {
        heap_virtual_next = heap_virtual_start + (heap_next - heap_start);
    }
    requested_bytes = requested_bytes + size;
    last_status = status_ok;
    if returns_virtual_addresses {
        return heap_virtual_start + (base - heap_start);
    }
    return base;
}

pub fn enable_virtual_mapping(virtual_start: usize): bool {
    if committed_pages == 0 {
        return false;
    }
    if virtual_start == 0 {
        return false;
    }
    heap_virtual_start = virtual_start;
    heap_virtual_next = virtual_start + (heap_next - heap_start);
    returns_virtual_addresses = true;
    last_status = status_ok;
    return true;
}

pub fn returns_virtual(): bool {
    return returns_virtual_addresses;
}

pub fn deallocate(addr: usize): bool {
    last_status = status_deallocate_unsupported;
    return false;
}

pub fn status(): i32 {
    return last_status;
}

pub fn snapshot(): HeapSnapshot {
    var used_bytes: usize = 0;
    if committed_pages != 0 {
        used_bytes = heap_next - heap_start;
    }

    return HeapSnapshot {
        page_size: page_size,
        start: heap_start,
        end: heap_end,
        next: heap_next,
        committed_pages: committed_pages,
        used_bytes: used_bytes,
        requested_bytes: requested_bytes,
        virtual_start: heap_virtual_start,
        virtual_end: heap_virtual_start + (committed_pages * page_size),
        virtual_next: heap_virtual_next,
        returns_virtual: returns_virtual_addresses,
    };
}
