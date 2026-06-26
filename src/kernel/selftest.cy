import .kernel.memory.boot;
import { Layout } from .kernel.memory.layout;
import .kernel.memory.map as memory_map;
import .kernel.memory.phys;
import .kernel.panic as panic_mod;

fn fail(name: string): void {
    println(name);
    panic_mod.panic();
}

pub fn run_boot_tests(map: Layout): void {
    if map.ram_start >= map.ram_end {
        fail("selftest: ram range");
    }
    if map.kernel_load < map.ram_start {
        fail("selftest: kernel low bound");
    }
    if map.kernel_load >= map.ram_end {
        fail("selftest: kernel high bound");
    }
    if map.page_size == 0 {
        fail("selftest: page size");
    }

    const before = boot.snapshot();
    if before.start < map.kernel_load {
        fail("selftest: boot start low bound");
    }
    if before.start >= before.end {
        fail("selftest: boot start before end");
    }
    if before.next != before.start {
        fail("selftest: boot next starts clean");
    }

    const first = boot.reserve(64, 16);
    if first == 0 {
        fail("selftest: boot first reserve");
    }
    const second = boot.reserve(map.page_size, map.page_size);
    if second == 0 {
        fail("selftest: boot second reserve");
    }

    if first < before.start {
        fail("selftest: boot first low bound");
    }
    if second < first + 64 {
        fail("selftest: boot reserve ordering");
    }
    if (second & (map.page_size - 1)) != 0 {
        fail("selftest: boot page alignment");
    }
}

pub fn run_phys_tests(map: Layout): void {
    if !boot.is_frozen() {
        fail("selftest: boot frozen");
    }

    const before = phys.snapshot();
    if before.page_size != map.page_size {
        fail("selftest: phys page size");
    }
    if before.total_pages == 0 {
        fail("selftest: phys total pages");
    }
    if before.free_pages == 0 {
        fail("selftest: phys free pages");
    }
    if before.used_pages == 0 {
        fail("selftest: phys used pages");
    }
    if before.bitmap_start == 0 {
        fail("selftest: phys bitmap start");
    }
    if before.bitmap_bytes == 0 {
        fail("selftest: phys bitmap bytes");
    }

    const late_boot = boot.reserve(1, 1);
    if late_boot != 0 {
        fail("selftest: late boot reserve");
    }

    const first = phys.alloc_page();
    if first == 0 {
        fail("selftest: phys alloc page");
    }
    if (first & (map.page_size - 1)) != 0 {
        fail("selftest: phys alloc align");
    }
    if first < map.ram_start {
        fail("selftest: phys alloc low bound");
    }
    if first >= map.ram_end {
        fail("selftest: phys alloc high bound");
    }

    const after_alloc = phys.snapshot();
    if after_alloc.free_pages + 1 != before.free_pages {
        fail("selftest: phys free count after alloc");
    }

    if !phys.free_page(first) {
        fail("selftest: phys free page");
    }
    const after_free = phys.snapshot();
    if after_free.free_pages != before.free_pages {
        fail("selftest: phys free count after free");
    }

    const second = phys.alloc_page();
    if second != first {
        fail("selftest: phys reuse page");
    }
    if !phys.free_page(second) {
        fail("selftest: phys free reused page");
    }
}

pub fn run_memory_map_tests(map: Layout): void {
    const snapshot = memory_map.snapshot();
    if snapshot.region_count < 4 {
        fail("selftest: memory map region count");
    }
    if snapshot.identity_region_count < 3 {
        fail("selftest: memory map identity count");
    }
    if snapshot.free_region_count == 0 {
        fail("selftest: memory map free count");
    }

    var index: usize = 0;
    var saw_kernel = false;
    var saw_boot = false;
    var saw_bitmap = false;
    while index < memory_map.count() {
        const region = memory_map.get(index);
        if region.start >= region.end {
            fail("selftest: memory map ordered range");
        }
        if region.start < map.ram_start {
            fail("selftest: memory map low bound");
        }
        if region.end > map.ram_end {
            fail("selftest: memory map high bound");
        }

        if index != 0 {
            const previous = memory_map.get(index - 1);
            if previous.end > region.start {
                fail("selftest: memory map overlap");
            }
        }

        if region.kind == memory_map.kind_kernel_image {
            saw_kernel = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: kernel image identity");
            }
        }
        if region.kind == memory_map.kind_boot_allocator {
            saw_boot = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: boot allocator identity");
            }
        }
        if region.kind == memory_map.kind_physical_page_bitmap {
            saw_bitmap = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: bitmap identity");
            }
        }

        index = index + 1;
    }

    if !saw_kernel {
        fail("selftest: memory map kernel region");
    }
    if !saw_boot {
        fail("selftest: memory map boot region");
    }
    if !saw_bitmap {
        fail("selftest: memory map bitmap region");
    }
}
