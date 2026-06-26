import .kernel.memory.boot;
import { Layout } from .kernel.memory.layout;
import .kernel.memory.phys;

pub const kind_free_ram: i32 = 0;
pub const kind_kernel_image: i32 = 1;
pub const kind_boot_allocator: i32 = 2;
pub const kind_physical_page_bitmap: i32 = 3;
pub const kind_early_kheap: i32 = 4;
pub const kind_device_mmio: i32 = 5;
pub const kind_kernel_stack: i32 = 6;

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

pub const max_regions: usize = 8;

// The early map is a small fixed table so kernel boot has deterministic
// storage and does not depend on heap allocation. The parallel arrays keep the
// representation simple until Cyna has enum arrays and richer aggregate tools.
var region_starts: [8]usize = [0, 0, 0, 0, 0, 0, 0, 0];
var region_ends: [8]usize = [0, 0, 0, 0, 0, 0, 0, 0];
var region_kinds: [8]i32 = [kind_free_ram, kind_free_ram, kind_free_ram, kind_free_ram, kind_free_ram, kind_free_ram, kind_free_ram, kind_free_ram];
var used_regions: usize = 0;

fn empty_region(): Region {
    return Region {
        start: 0,
        end: 0,
        kind: kind_free_ram,
    };
}

fn reset(): void {
    used_regions = 0;
}

fn write_region(index: usize, start: usize, end: usize, kind: i32): void {
    region_starts[index] = start;
    region_ends[index] = end;
    region_kinds[index] = kind;
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

pub fn rebuild(layout: Layout): bool {
    reset();

    const boot_used = boot.snapshot();
    const phys_used = phys.snapshot();
    const bitmap_end = boot.align_up(phys_used.bitmap_start + phys_used.bitmap_bytes, layout.page_size);

    // Keep the table non-overlapping. The boot allocator owns the broad early
    // range, but the physical page bitmap gets a separate row because VM setup
    // and diagnostics need to understand why that live metadata exists.
    if !add_region(layout.ram_start, layout.kernel_load, kind_free_ram) {
        return false;
    }
    if !add_region(layout.kernel_load, boot_used.start, kind_kernel_image) {
        return false;
    }
    if !add_region(boot_used.start, phys_used.bitmap_start, kind_boot_allocator) {
        return false;
    }
    if !add_region(phys_used.bitmap_start, bitmap_end, kind_physical_page_bitmap) {
        return false;
    }
    if !add_region(bitmap_end, layout.ram_end, kind_free_ram) {
        return false;
    }

    return true;
}

pub fn count(): usize {
    return used_regions;
}

pub fn get(index: usize): Region {
    if index >= used_regions {
        return empty_region();
    }
    return Region {
        start: region_starts[index],
        end: region_ends[index],
        kind: region_kinds[index],
    };
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
