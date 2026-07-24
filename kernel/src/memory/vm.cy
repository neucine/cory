import { Layout } from .memory.layout;
import .memory.heap;
import .memory.map as memory_map;
import { Spec } from .memory.page_table;
import .memory.phys;

// VM is the mapping policy layer. It owns virtual-to-physical translations,
// while `phys` owns frame availability and `heap` owns fine-grained kernel
// object allocation. These aliases are semantic labels for now; Cyna does not
// yet give us zero-cost distinct integer types.
pub type PhysAddr = usize;
pub type VirtAddr = usize;

pub const rights_read: u8 = 1;
pub const rights_write: u8 = 2;
pub const rights_execute: u8 = 4;
pub const rights_user: u8 = 8;

// These offsets name the kernel heap inside the architecture's upper canonical
// virtual range. The concrete base depends on the active page-table geometry.
pub const kernel_heap_virtual_offset: usize = 0x40000000;
pub const kernel_heap_virtual_size: usize = 0x04000000;
pub const user_virtual_base: usize = 0x10000000;
pub const user_virtual_size: usize = 0x10000000;

pub struct MappingRequest {
    pub virt_start: VirtAddr;
    pub phys_start: PhysAddr;
    pub size: usize;
    pub rights: u8;
    pub kind: i32;
}

pub struct VmBootstrapPlan {
    pub identity_region_count: usize;
    pub mapping_request_count: usize;
    pub kernel_heap_mapping_count: usize;
    pub page_table_root: PhysAddr;
    pub page_table_pages: usize;
    pub page_table_used_pages: usize;
    pub page_table_zeroed_pages: usize;
    pub kernel_heap_base: VirtAddr;
    pub kernel_heap_end: VirtAddr;
    pub user_base: VirtAddr;
    pub user_end: VirtAddr;
    pub kernel_base: VirtAddr;
    pub page_size: usize;
}

pub const max_mapping_requests: usize = 20;

var mapping_requests: [20]MappingRequest = [MappingRequest {
    virt_start: 0,
    phys_start: 0,
    size: 0,
    rights: 0,
    kind: memory_map.kind_free_ram,
}] ** 20;
var used_mapping_requests: usize = 0;
var kernel_heap_mapping_count: usize = 0;

var bootstrap_page_table_root: PhysAddr = 0;
var bootstrap_page_table_pages: usize = 0;
var bootstrap_page_table_used_pages: usize = 0;
var bootstrap_page_table_zeroed_pages: usize = 0;

pub fn is_page_aligned(addr: usize, page_size: usize): bool {
    if page_size == 0 {
        return false;
    }
    return (addr & (page_size - 1)) == 0;
}

pub fn is_power_of_two(value: usize): bool {
    if value == 0 {
        return false;
    }
    return (value & (value - 1)) == 0;
}

fn div_round_up(value: usize, divisor: usize): usize {
    if divisor == 0 {
        return 0;
    }
    return (value + divisor - 1) / divisor;
}

fn entry_addr(page_index: usize, entry_index: usize, spec: Spec): usize {
    return bootstrap_page_table_root + (page_index * spec.page_size) + (entry_index * spec.entry_size);
}

fn table_entry_addr(table_phys: PhysAddr, entry_index: usize, spec: Spec): usize {
    return table_phys + (entry_index * spec.entry_size);
}

fn write_entry(page_index: usize, entry_index: usize, spec: Spec, raw: usize): void {
    unchecked {
        const ptr = entry_addr(page_index, entry_index, spec) as! *usize;
        *ptr = raw;
    }
}

fn read_entry(page_index: usize, entry_index: usize, spec: Spec): usize {
    unchecked {
        const ptr = entry_addr(page_index, entry_index, spec) as! *usize;
        return *ptr;
    }
}

fn zero_page(page_index: usize, spec: Spec): void {
    var entry_index: usize = 0;
    while entry_index < spec.entries_per_table {
        write_entry(page_index, entry_index, spec, 0);
        entry_index = entry_index + 1;
    }
}

pub fn zero_table_page(table_phys: PhysAddr, spec: Spec): bool {
    if !is_page_aligned(table_phys, spec.page_size) {
        return false;
    }
    var entry_index: usize = 0;
    while entry_index < spec.entries_per_table {
        if !write_table_entry(table_phys, entry_index, spec, 0) {
            return false;
        }
        entry_index = entry_index + 1;
    }
    return true;
}

pub fn identity_virtual_for_phys(addr: PhysAddr): VirtAddr {
    return addr;
}

pub fn phys_for_identity_virtual(addr: VirtAddr): PhysAddr {
    return addr;
}

pub fn kernel_virtual_base_for_spec(spec: Spec): VirtAddr {
    if spec.virtual_address_bits == 0 {
        return 0;
    }
    if spec.virtual_address_bits >= (8 * 8) {
        return 0;
    }
    const upper_half_size = 1 << (spec.virtual_address_bits - 1);
    return 0 - upper_half_size;
}

pub fn user_virtual_base_for_spec(spec: Spec): VirtAddr {
    if spec.virtual_address_bits == 0 {
        return 0;
    }
    if spec.virtual_address_bits >= (8 * 8) {
        return 0;
    }
    const lower_half_size = 1 << (spec.virtual_address_bits - 1);
    if user_virtual_base + user_virtual_size > lower_half_size {
        return 0;
    }
    return user_virtual_base;
}

pub fn user_virtual_end_for_spec(spec: Spec): VirtAddr {
    if spec.virtual_address_bits == 0 {
        return 0;
    }
    if spec.virtual_address_bits >= (8 * 8) {
        return 0;
    }
    const base = user_virtual_base_for_spec(spec);
    if base == 0 {
        return 0;
    }
    return base + user_virtual_size;
}

pub fn kernel_heap_virtual_base_for_spec(spec: Spec): VirtAddr {
    return kernel_virtual_base_for_spec(spec) + kernel_heap_virtual_offset;
}

pub fn kernel_heap_virtual_end_for_spec(spec: Spec): VirtAddr {
    return kernel_heap_virtual_base_for_spec(spec) + kernel_heap_virtual_size;
}

pub fn rights_kernel_rw(): u8 {
    return rights_read | rights_write;
}

pub fn rights_kernel_rx(): u8 {
    return rights_read | rights_execute;
}

pub fn rights_user_rw(): u8 {
    return rights_read | rights_write | rights_user;
}

pub fn rights_user_rx(): u8 {
    return rights_read | rights_execute | rights_user;
}

pub fn rights_for_memory_kind(kind: i32): u8 {
    if kind == memory_map.kind_kernel_image {
        // The current linker-backed kernel image region contains text, rodata,
        // data, bss, and bootstrap stack. Keep it RWX until the memory map has
        // section-level regions; otherwise MMU activation would make globals
        // and stack storage read-only.
        return rights_read | rights_write | rights_execute;
    }
    if kind == memory_map.kind_device_mmio {
        // Device-ness is carried by the memory-map kind; architectures can use
        // it to select descriptor attributes while VM keeps the portable rights
        // contract as kernel read/write.
        return rights_kernel_rw();
    }
    return rights_kernel_rw();
}

pub fn rights_has_user(rights: u8): bool {
    return (rights & rights_user) != 0;
}

pub fn rights_are_kernel(rights: u8): bool {
    return !rights_has_user(rights);
}

pub fn rights_are_valid(rights: u8): bool {
    const known = rights_read | rights_write | rights_execute | rights_user;
    if (rights | known) != known {
        return false;
    }
    if (rights & (rights_read | rights_write | rights_execute)) == 0 {
        return false;
    }
    if (rights & rights_write) != 0 {
        return (rights & rights_read) != 0;
    }
    return true;
}

pub fn validate_page_mapping(virt: VirtAddr, phys: PhysAddr, rights: u8, spec: Spec): bool {
    if !rights_are_valid(rights) {
        return false;
    }
    if !is_page_aligned(virt, spec.page_size) {
        return false;
    }
    if !is_page_aligned(phys, spec.page_size) {
        return false;
    }
    return true;
}

pub fn range_fits(virt: VirtAddr, size: usize): bool {
    if size == 0 {
        return false;
    }
    if virt > (0 - 1) - size {
        return false;
    }
    return true;
}

pub fn is_user_virtual_range(virt: VirtAddr, size: usize, spec: Spec): bool {
    if !range_fits(virt, size) {
        return false;
    }
    const end = virt + size;
    if virt < user_virtual_base_for_spec(spec) {
        return false;
    }
    return end <= user_virtual_end_for_spec(spec);
}

pub fn is_kernel_virtual_range(virt: VirtAddr, size: usize, spec: Spec): bool {
    if !range_fits(virt, size) {
        return false;
    }
    const end = virt + size;
    const kernel_base = kernel_virtual_base_for_spec(spec);
    if virt < kernel_base {
        return false;
    }
    return end > virt;
}

pub fn validate_user_page_mapping(virt: VirtAddr, phys: PhysAddr, rights: u8, spec: Spec): bool {
    if !validate_page_mapping(virt, phys, rights, spec) {
        return false;
    }
    if !rights_has_user(rights) {
        return false;
    }
    return is_user_virtual_range(virt, spec.page_size, spec);
}

pub fn validate_kernel_page_mapping(virt: VirtAddr, phys: PhysAddr, rights: u8, spec: Spec): bool {
    if !validate_page_mapping(virt, phys, rights, spec) {
        return false;
    }
    if rights_has_user(rights) {
        return false;
    }
    return is_kernel_virtual_range(virt, spec.page_size, spec);
}

fn empty_mapping_request(): MappingRequest {
    return MappingRequest {
        virt_start: 0,
        phys_start: 0,
        size: 0,
        rights: 0,
        kind: memory_map.kind_free_ram,
    };
}

fn reset_mapping_requests(): void {
    used_mapping_requests = 0;
    kernel_heap_mapping_count = 0;
}

fn write_mapping_request(index: usize, virt_start: VirtAddr, phys_start: PhysAddr, size: usize, rights: u8, kind: i32): void {
    mapping_requests[index] = MappingRequest {
        virt_start: virt_start,
        phys_start: phys_start,
        size: size,
        rights: rights,
        kind: kind,
    };
}

fn append_mapping_request(virt_start: VirtAddr, phys_start: PhysAddr, size: usize, rights: u8, kind: i32, spec: Spec): bool {
    if used_mapping_requests >= max_mapping_requests {
        return false;
    }
    if size == 0 {
        return false;
    }
    if !is_page_aligned(size, spec.page_size) {
        return false;
    }
    if !validate_page_mapping(virt_start, phys_start, rights, spec) {
        return false;
    }
    write_mapping_request(used_mapping_requests, virt_start, phys_start, size, rights, kind);
    used_mapping_requests = used_mapping_requests + 1;
    return true;
}

fn table_pages_for_page_count(mapped_pages: usize, spec: Spec): usize {
    if mapped_pages == 0 {
        return 0;
    }

    // This intentionally does not share intermediate tables between mapping
    // requests yet. It gives the VM bootstrap a deterministic upper-bound range
    // owned by `phys` while real multi-level population is still being built.
    var child_tables = div_round_up(mapped_pages, spec.entries_per_table);
    var total = child_tables;
    var level: usize = 1;
    while level < spec.level_count - 1 {
        child_tables = div_round_up(child_tables, spec.entries_per_table);
        total = total + child_tables;
        level = level + 1;
    }
    return total;
}

fn estimate_bootstrap_page_table_pages(layout: Layout, spec: Spec, extra_mapping_pages: usize): usize {
    if spec.level_count < 2 {
        return 0;
    }

    var total: usize = 1;
    var index: usize = 0;
    while index < used_mapping_requests {
        total = total + table_pages_for_page_count(div_round_up(mapping_requests[index].size, layout.page_size), spec);
        index = index + 1;
    }
    total = total + table_pages_for_page_count(extra_mapping_pages, spec);
    return total;
}

// Build deterministic mapping requests from the canonical memory map plus the
// high-half alias for committed heap pages. Identity requests keep boot-owned
// storage reachable after activation; the heap alias is the first non-identity
// kernel mapping.
pub fn rebuild_bootstrap_mappings(layout: Layout, spec: Spec): bool {
    reset_mapping_requests();

    var index: usize = 0;
    while index < memory_map.count() {
        const region = memory_map.get(index);
        if memory_map.needs_identity_mapping(region.kind) {
            if !is_page_aligned(region.start, layout.page_size) {
                return false;
            }
            if !is_page_aligned(region.end, layout.page_size) {
                return false;
            }
            if !append_mapping_request(identity_virtual_for_phys(region.start), region.start, region.end - region.start, rights_for_memory_kind(region.kind), region.kind, spec) {
                return false;
            }
        }
        index = index + 1;
    }

    const heap_used = heap.snapshot();
    if heap_used.committed_pages != 0 {
        const heap_size = heap_used.committed_pages * layout.page_size;
        if heap_size > kernel_heap_virtual_size {
            return false;
        }
        if !append_mapping_request(kernel_heap_virtual_base_for_spec(spec), heap_used.start, heap_size, rights_kernel_rw(), memory_map.kind_kernel_heap_virtual, spec) {
            return false;
        }
        kernel_heap_mapping_count = 1;
    }

    return true;
}

// Reserve the physical pages that will hold the bootstrap page tables. The
// range is registered with the memory map and then boot rebuilds mappings again,
// so the page-table storage is itself covered by the identity-map contract.
pub fn allocate_bootstrap_page_tables(layout: Layout, spec: Spec): bool {
    var pages = estimate_bootstrap_page_table_pages(layout, spec, 0);
    var previous: usize = 0;
    while pages != previous {
        previous = pages;
        pages = estimate_bootstrap_page_table_pages(layout, spec, previous);
    }

    const root = phys.alloc_contiguous_pages(pages);
    if root == 0 {
        return false;
    }

    bootstrap_page_table_root = root;
    bootstrap_page_table_pages = pages;
    bootstrap_page_table_used_pages = 1;
    bootstrap_page_table_zeroed_pages = 0;
    memory_map.set_bootstrap_page_tables(root, root + (pages * layout.page_size));
    return true;
}

// Zero page-table storage before any descriptors are written. This makes the
// not-present state explicit and keeps later table population deterministic.
pub fn clear_bootstrap_page_tables(spec: Spec): bool {
    if bootstrap_page_table_root == 0 {
        return false;
    }
    var page_index: usize = 0;
    while page_index < bootstrap_page_table_pages {
        zero_page(page_index, spec);
        page_index = page_index + 1;
    }
    bootstrap_page_table_zeroed_pages = bootstrap_page_table_pages;
    return true;
}

// Allocate one table page inside the already reserved bootstrap table range.
// The returned address is physical and currently identity-addressable.
pub fn allocate_bootstrap_table_page(): PhysAddr {
    if bootstrap_page_table_used_pages >= bootstrap_page_table_pages {
        return 0;
    }
    const page = bootstrap_page_table_root + (bootstrap_page_table_used_pages * phys.snapshot().page_size);
    bootstrap_page_table_used_pages = bootstrap_page_table_used_pages + 1;
    return page;
}

pub fn bootstrap_table_page_index(table_phys: PhysAddr): usize {
    if table_phys < bootstrap_page_table_root {
        return bootstrap_page_table_pages;
    }
    const offset = table_phys - bootstrap_page_table_root;
    const page_size = phys.snapshot().page_size;
    if page_size == 0 {
        return bootstrap_page_table_pages;
    }
    if (offset & (page_size - 1)) != 0 {
        return bootstrap_page_table_pages;
    }
    const index = offset / page_size;
    if index >= bootstrap_page_table_pages {
        return bootstrap_page_table_pages;
    }
    return index;
}

pub fn bootstrap_table_page_count(): usize {
    return bootstrap_page_table_pages;
}

pub fn page_table_level_index(virt: VirtAddr, spec: Spec, level: usize): usize {
    if level >= spec.level_count {
        return 0;
    }
    const shift = spec.page_offset_bits + ((spec.level_count - 1 - level) * spec.level_index_bits);
    return (virt >> shift) & (spec.entries_per_table - 1);
}

pub fn write_bootstrap_table_entry(page_index: usize, entry_index: usize, spec: Spec, entry_raw: usize): bool {
    if page_index >= bootstrap_page_table_pages {
        return false;
    }
    if entry_index >= spec.entries_per_table {
        return false;
    }
    write_entry(page_index, entry_index, spec, entry_raw);
    return true;
}

pub fn read_bootstrap_table_entry(page_index: usize, entry_index: usize, spec: Spec): usize {
    if page_index >= bootstrap_page_table_pages {
        return 0;
    }
    if entry_index >= spec.entries_per_table {
        return 0;
    }
    return read_entry(page_index, entry_index, spec);
}

pub fn write_table_entry(table_phys: PhysAddr, entry_index: usize, spec: Spec, entry_raw: usize): bool {
    if !is_page_aligned(table_phys, spec.page_size) {
        return false;
    }
    if entry_index >= spec.entries_per_table {
        return false;
    }
    unchecked {
        const ptr = table_entry_addr(table_phys, entry_index, spec) as! *usize;
        *ptr = entry_raw;
    }
    return true;
}

pub fn read_table_entry(table_phys: PhysAddr, entry_index: usize, spec: Spec): usize {
    if !is_page_aligned(table_phys, spec.page_size) {
        return 0;
    }
    if entry_index >= spec.entries_per_table {
        return 0;
    }
    unchecked {
        const ptr = table_entry_addr(table_phys, entry_index, spec) as! *usize;
        return *ptr;
    }
}

pub fn mapping_request_count(): usize {
    return used_mapping_requests;
}

pub fn mapping_request(index: usize): MappingRequest {
    if index >= used_mapping_requests {
        return empty_mapping_request();
    }
    return mapping_requests[index];
}

pub fn mapping_request_virt_start(index: usize): VirtAddr {
    if index >= used_mapping_requests {
        return 0;
    }
    return mapping_requests[index].virt_start;
}

pub fn mapping_request_phys_start(index: usize): PhysAddr {
    if index >= used_mapping_requests {
        return 0;
    }
    return mapping_requests[index].phys_start;
}

pub fn mapping_request_size(index: usize): usize {
    if index >= used_mapping_requests {
        return 0;
    }
    return mapping_requests[index].size;
}

pub fn mapping_request_rights(index: usize): u8 {
    if index >= used_mapping_requests {
        return 0;
    }
    return mapping_requests[index].rights;
}

pub fn mapping_request_kind(index: usize): i32 {
    if index >= used_mapping_requests {
        return memory_map.kind_free_ram;
    }
    return mapping_requests[index].kind;
}

pub fn validate_kernel_heap_range(spec: Spec): bool {
    if kernel_heap_virtual_size == 0 {
        return false;
    }
    const kernel_base = kernel_virtual_base_for_spec(spec);
    if kernel_base == 0 {
        return false;
    }
    const heap_base = kernel_heap_virtual_base_for_spec(spec);
    const heap_end = kernel_heap_virtual_end_for_spec(spec);
    if heap_base < kernel_base {
        return false;
    }
    if heap_end <= heap_base {
        return false;
    }
    if heap_end < heap_base {
        return false;
    }
    if heap_base - kernel_base > ((1 << (spec.virtual_address_bits - 1)) - kernel_heap_virtual_size) {
        return false;
    }
    return true;
}

pub fn bootstrap_plan(layout: Layout, spec: Spec): VmBootstrapPlan {
    const snapshot = memory_map.snapshot();
    return VmBootstrapPlan {
        identity_region_count: snapshot.identity_region_count,
        mapping_request_count: used_mapping_requests,
        kernel_heap_mapping_count: kernel_heap_mapping_count,
        page_table_root: bootstrap_page_table_root,
        page_table_pages: bootstrap_page_table_pages,
        page_table_used_pages: bootstrap_page_table_used_pages,
        page_table_zeroed_pages: bootstrap_page_table_zeroed_pages,
        kernel_heap_base: kernel_heap_virtual_base_for_spec(spec),
        kernel_heap_end: kernel_heap_virtual_end_for_spec(spec),
        user_base: user_virtual_base_for_spec(spec),
        user_end: user_virtual_end_for_spec(spec),
        kernel_base: kernel_virtual_base_for_spec(spec),
        page_size: layout.page_size,
    };
}
