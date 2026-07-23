import .memory.boot;
import .memory.heap;
import { Layout } from .memory.layout;
import .memory.phys;

pub const kind_free_ram: i32 = 0;
pub const kind_kernel_image: i32 = 1;
pub const kind_boot_allocator: i32 = 2;
pub const kind_physical_page_bitmap: i32 = 3;
pub const kind_pre_vm_heap: i32 = 4;
pub const kind_device_mmio: i32 = 5;
pub const kind_kernel_stack: i32 = 6;
pub const kind_bootstrap_page_tables: i32 = 7;
pub const kind_kernel_heap_virtual: i32 = 8;

pub struct Region {
    pub start: usize;
    pub end: usize;
    pub kind: i32;
}

pub struct MemoryMapSnapshot {
    pub region_count: usize;
    pub identity_region_count: usize;
    pub free_region_count: usize;
}

pub const max_regions: usize = 16;
const max_owned_regions: usize = 10;

// The early map is a small fixed table so kernel boot has deterministic
// storage and does not depend on heap allocation.
var regions: [16]Region = [Region {
    start: 0,
    end: 0,
    kind: kind_free_ram,
}] ** 16;
var used_regions: usize = 0;

var owned_regions: [10]Region = [Region {
    start: 0,
    end: 0,
    kind: kind_free_ram,
}] ** 10;
var used_owned_regions: usize = 0;

var bootstrap_page_table_start: usize = 0;
var bootstrap_page_table_end: usize = 0;

fn empty_region(): Region {
    return Region {
        start: 0,
        end: 0,
        kind: kind_free_ram,
    };
}

fn reset(): void {
    used_regions = 0;
    used_owned_regions = 0;
}

fn write_region(index: usize, start: usize, end: usize, kind: i32): void {
    regions[index] = Region {
        start: start,
        end: end,
        kind: kind,
    };
}

fn add_region(start: usize, end: usize, kind: i32): bool {
    if end <= start {
        return true;
    }
    if used_regions >= max_regions {
        return false;
    }

    write_region(used_regions, start, end, kind);
    used_regions = used_regions + 1;
    return true;
}

fn write_owned_region(index: usize, start: usize, end: usize, kind: i32): void {
    owned_regions[index] = Region {
        start: start,
        end: end,
        kind: kind,
    };
}

fn add_owned_region(start: usize, end: usize, kind: i32): bool {
    if end <= start {
        return true;
    }
    if used_owned_regions >= max_owned_regions {
        return false;
    }

    var index = used_owned_regions;
    while index > 0 and owned_regions[index - 1].start > start {
        owned_regions[index] = owned_regions[index - 1];
        index = index - 1;
    }

    write_owned_region(index, start, end, kind);
    used_owned_regions = used_owned_regions + 1;
    return true;
}

fn build_regions_from_owned(layout: Layout): bool {
    var cursor = layout.ram_start;
    var index: usize = 0;

    while index < used_owned_regions {
        const owned = owned_regions[index];
        const start = owned.start;
        const end = owned.end;
        if start < layout.ram_start or end > layout.ram_end {
            return false;
        }
        if start < cursor {
            return false;
        }

        if !add_region(cursor, start, kind_free_ram) {
            return false;
        }
        if !add_region(start, end, owned.kind) {
            return false;
        }

        cursor = end;
        index = index + 1;
    }

    return add_region(cursor, layout.ram_end, kind_free_ram);
}

pub fn rebuild(layout: Layout): bool {
    reset();

    const boot_used = boot.snapshot();
    const phys_used = phys.snapshot();
    const heap_used = heap.snapshot();
    const bitmap_end = boot.align_up(phys_used.bitmap_start + phys_used.bitmap_bytes, layout.page_size);

    // Platform MMIO is not RAM and is not owned by `phys`, but it must enter the
    // canonical map before VM activation so identity mappings keep devices like
    // the boot UART reachable.
    if layout.device_mmio_end > layout.device_mmio_start {
        if !add_region(layout.device_mmio_start, layout.device_mmio_end, kind_device_mmio) {
            return false;
        }
    }
    if layout.device_mmio2_end > layout.device_mmio2_start {
        if !add_region(layout.device_mmio2_start, layout.device_mmio2_end, kind_device_mmio) {
            return false;
        }
    }

    // Owned ranges can be discovered in subsystem order, not address order.
    // Build a sorted owned list first, then fill every gap as `free_ram`.
    if !add_owned_region(layout.kernel_load, boot_used.start, kind_kernel_image) {
        return false;
    }
    if !add_owned_region(boot_used.start, phys_used.bitmap_start, kind_boot_allocator) {
        return false;
    }
    if !add_owned_region(phys_used.bitmap_start, bitmap_end, kind_physical_page_bitmap) {
        return false;
    }
    if heap_used.committed_pages != 0 {
        if !add_owned_region(heap_used.start, heap_used.end, kind_pre_vm_heap) {
            return false;
        }
    }
    if bootstrap_page_table_end > bootstrap_page_table_start {
        if !add_owned_region(bootstrap_page_table_start, bootstrap_page_table_end, kind_bootstrap_page_tables) {
            return false;
        }
    }

    return build_regions_from_owned(layout);
}

pub fn set_bootstrap_page_tables(start: usize, end: usize): void {
    bootstrap_page_table_start = start;
    bootstrap_page_table_end = end;
}

pub fn count(): usize {
    return used_regions;
}

pub fn get(index: usize): Region {
    if index >= used_regions {
        return empty_region();
    }
    return regions[index];
}

pub fn needs_identity_mapping(kind: i32): bool {
    return kind != kind_free_ram;
}

pub fn snapshot(): MemoryMapSnapshot {
    var identity_count: usize = 0;
    var free_count: usize = 0;
    var index: usize = 0;
    while index < used_regions {
        const kind = get(index).kind;
        if needs_identity_mapping(kind) {
            identity_count = identity_count + 1;
        }
        if kind == kind_free_ram {
            free_count = free_count + 1;
        }
        index = index + 1;
    }

    return MemoryMapSnapshot {
        region_count: used_regions,
        identity_region_count: identity_count,
        free_region_count: free_count,
    };
}
