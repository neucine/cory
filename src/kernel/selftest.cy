import .kernel.arch.aarch64.page_table as aarch64_page_table;
import .kernel.arch.riscv64.page_table as riscv64_page_table;
import .kernel.memory.boot;
import .kernel.memory.heap;
import { Layout } from .kernel.memory.layout;
import .kernel.memory.map as memory_map;
import .kernel.memory.page_table;
import { Spec } from .kernel.memory.page_table;
import .kernel.memory.phys;
import .kernel.memory.vm;
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

pub fn run_heap_tests(map: Layout): void {
    const before = phys.snapshot();
    const first = heap.allocate(64, 16);
    if first == 0 {
        fail("selftest: heap first alloc");
    }
    if (first & 15) != 0 {
        fail("selftest: heap first align");
    }
    if first < map.ram_start {
        fail("selftest: heap first low bound");
    }
    if first >= map.ram_end {
        fail("selftest: heap first high bound");
    }

    const second = heap.allocate(map.page_size + 32, map.page_size);
    if second == 0 {
        fail("selftest: heap second alloc");
    }
    if (second & (map.page_size - 1)) != 0 {
        fail("selftest: heap page align");
    }
    if second <= first {
        fail("selftest: heap ordering");
    }

    const heap_used = heap.snapshot();
    if heap_used.page_size != map.page_size {
        fail("selftest: heap page size");
    }
    if heap_used.committed_pages < 2 {
        fail("selftest: heap committed pages");
    }
    if heap_used.start == 0 {
        fail("selftest: heap start");
    }
    if heap_used.end <= heap_used.start {
        fail("selftest: heap range");
    }
    if heap_used.next <= heap_used.start {
        fail("selftest: heap next");
    }
    if heap_used.used_bytes != heap_used.next - heap_used.start {
        fail("selftest: heap used bytes");
    }
    if heap_used.used_bytes < heap_used.requested_bytes {
        fail("selftest: heap used below requested");
    }
    if heap_used.requested_bytes != map.page_size + 96 {
        fail("selftest: heap requested bytes");
    }
    if heap.allocate(1, 0) != 0 {
        fail("selftest: heap zero align");
    }
    if heap.status() != heap.status_invalid_alignment {
        fail("selftest: heap zero align status");
    }
    if heap.allocate(1, 24) != 0 {
        fail("selftest: heap non-power align");
    }
    if heap.status() != heap.status_invalid_alignment {
        fail("selftest: heap non-power align status");
    }
    if heap.allocate(0 - 1, map.page_size) != 0 {
        fail("selftest: heap overflow");
    }
    if heap.status() != heap.status_address_overflow {
        fail("selftest: heap overflow status");
    }
    if heap.deallocate(first) {
        fail("selftest: heap free unsupported");
    }
    if heap.status() != heap.status_deallocate_unsupported {
        fail("selftest: heap free unsupported status");
    }

    const after = phys.snapshot();
    if after.free_pages + heap_used.committed_pages != before.free_pages {
        fail("selftest: heap phys page count");
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
    var saw_heap = false;
    var saw_page_tables = false;
    var saw_device_mmio = false;
    while index < memory_map.count() {
        const region = memory_map.get(index);
        if region.start >= region.end {
            fail("selftest: memory map ordered range");
        }
        if region.kind == memory_map.kind_device_mmio {
            if region.start != map.device_mmio_start {
                fail("selftest: memory map mmio start");
            }
            if region.end != map.device_mmio_end {
                fail("selftest: memory map mmio end");
            }
        } else {
            if region.start < map.ram_start {
                fail("selftest: memory map low bound");
            }
            if region.end > map.ram_end {
                fail("selftest: memory map high bound");
            }
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
        if region.kind == memory_map.kind_pre_vm_heap {
            saw_heap = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: heap identity");
            }
        }
        if region.kind == memory_map.kind_bootstrap_page_tables {
            saw_page_tables = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: page tables identity");
            }
        }
        if region.kind == memory_map.kind_device_mmio {
            saw_device_mmio = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: device mmio identity");
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
    if !saw_heap {
        fail("selftest: memory map heap region");
    }
    if !saw_page_tables {
        fail("selftest: memory map page table region");
    }
    if !saw_device_mmio {
        fail("selftest: memory map device mmio region");
    }
}

pub fn run_vm_contract_tests(map: Layout): void {
    if !vm.is_power_of_two(map.page_size) {
        fail("selftest: vm page size power");
    }
    if !vm.is_page_aligned(map.ram_start, map.page_size) {
        fail("selftest: vm ram start align");
    }
    if !vm.is_page_aligned(map.ram_end, map.page_size) {
        fail("selftest: vm ram end align");
    }
    if !vm.validate_kernel_heap_range() {
        fail("selftest: vm heap range");
    }

    const phys = map.kernel_load;
    const virt = vm.identity_virtual_for_phys(phys);
    if virt != map.kernel_load {
        fail("selftest: vm identity virt");
    }
    if vm.phys_for_identity_virtual(virt) != phys {
        fail("selftest: vm identity phys");
    }

    if vm.rights_has_user(vm.rights_kernel_rw()) {
        fail("selftest: vm kernel user bit");
    }
    if !vm.rights_has_user(vm.rights_user_rw()) {
        fail("selftest: vm user bit");
    }
    if (vm.rights_kernel_rx() & vm.rights_write) != 0 {
        fail("selftest: vm rx write");
    }

    const plan = vm.bootstrap_plan(map);
    const snapshot = memory_map.snapshot();
    if plan.identity_region_count != snapshot.identity_region_count {
        fail("selftest: vm identity count");
    }
    if plan.mapping_request_count != snapshot.identity_region_count {
        fail("selftest: vm mapping count");
    }
    if plan.page_table_root == 0 {
        fail("selftest: vm page table root");
    }
    if !vm.is_page_aligned(plan.page_table_root, map.page_size) {
        fail("selftest: vm page table root align");
    }
    if plan.page_table_pages == 0 {
        fail("selftest: vm page table pages");
    }
    if plan.page_table_used_pages <= 1 {
        fail("selftest: vm page table used pages");
    }
    if plan.page_table_used_pages > plan.page_table_pages {
        fail("selftest: vm page table used above reserved");
    }
    if plan.page_table_zeroed_pages != plan.page_table_pages {
        fail("selftest: vm page table zeroed pages");
    }
    if plan.identity_region_count == 0 {
        fail("selftest: vm identity empty");
    }
    if plan.kernel_heap_base != vm.kernel_heap_virtual_base {
        fail("selftest: vm heap base");
    }
    if plan.kernel_heap_end != vm.kernel_heap_virtual_end {
        fail("selftest: vm heap end");
    }
    if plan.page_size != map.page_size {
        fail("selftest: vm page size");
    }

    if vm.mapping_request_count() != plan.mapping_request_count {
        fail("selftest: vm mapping request count");
    }

    var index: usize = 0;
    var saw_page_tables = false;
    while index < vm.mapping_request_count() {
        const request = vm.mapping_request(index);
        if request.size == 0 {
            fail("selftest: vm mapping size");
        }
        if !vm.is_page_aligned(request.virt_start, map.page_size) {
            fail("selftest: vm mapping virt align");
        }
        if !vm.is_page_aligned(request.phys_start, map.page_size) {
            fail("selftest: vm mapping phys align");
        }
        if !vm.is_page_aligned(request.phys_start + request.size, map.page_size) {
            fail("selftest: vm mapping end align");
        }
        if request.virt_start != vm.identity_virtual_for_phys(request.phys_start) {
            fail("selftest: vm mapping identity");
        }
        if vm.rights_has_user(request.rights) {
            fail("selftest: vm mapping user");
        }
        if request.kind == memory_map.kind_kernel_image {
            if (request.rights & vm.rights_execute) == 0 {
                fail("selftest: vm kernel image execute");
            }
            if (request.rights & vm.rights_write) == 0 {
                fail("selftest: vm kernel image write");
            }
        } else {
            if (request.rights & vm.rights_write) == 0 {
                fail("selftest: vm mapping write");
            }
        }
        if request.kind == memory_map.kind_bootstrap_page_tables {
            saw_page_tables = true;
            if request.phys_start != plan.page_table_root {
                fail("selftest: vm page table mapping root");
            }
            if request.size != plan.page_table_pages * map.page_size {
                fail("selftest: vm page table mapping size");
            }
        }
        index = index + 1;
    }
    if !saw_page_tables {
        fail("selftest: vm page table mapping");
    }
}

fn check_aarch64_leaf_entry(phys: usize, rights: u8, should_write: bool, should_execute: bool): void {
    const entry = aarch64_page_table.encode_leaf(phys, rights);
    if !page_table.entry_is_present(entry) {
        fail("selftest: aarch64 leaf present");
    }
    if aarch64_page_table.leaf_phys(entry) != phys {
        fail("selftest: aarch64 leaf phys");
    }
    if aarch64_page_table.leaf_is_writable(entry) != should_write {
        fail("selftest: aarch64 leaf write");
    }
    if aarch64_page_table.leaf_is_executable(entry) != should_execute {
        fail("selftest: aarch64 leaf execute");
    }
}

fn check_riscv64_leaf_entry(phys: usize, rights: u8, should_write: bool, should_execute: bool): void {
    const entry = riscv64_page_table.encode_leaf(phys, rights);
    if !page_table.entry_is_present(entry) {
        fail("selftest: riscv64 leaf present");
    }
    if riscv64_page_table.leaf_phys(entry) != phys {
        fail("selftest: riscv64 leaf phys");
    }
    if riscv64_page_table.leaf_is_writable(entry) != should_write {
        fail("selftest: riscv64 leaf write");
    }
    if riscv64_page_table.leaf_is_executable(entry) != should_execute {
        fail("selftest: riscv64 leaf execute");
    }
}

fn check_arch_leaf_entries(arch: i32, phys: usize): void {
    if !vm.is_page_aligned(phys, 4096) {
        fail("selftest: page table leaf phys align");
    }
    if arch == page_table.arch_aarch64 {
        check_aarch64_leaf_entry(phys, vm.rights_kernel_rx(), false, true);
        check_aarch64_leaf_entry(phys, vm.rights_kernel_rw(), true, false);
        return;
    }
    if arch == page_table.arch_riscv64 {
        check_riscv64_leaf_entry(phys, vm.rights_kernel_rx(), false, true);
        check_riscv64_leaf_entry(phys, vm.rights_kernel_rw(), true, false);
        return;
    }
    fail("selftest: page table arch");
}

fn lookup_arch_bootstrap_phys(arch: i32, spec: Spec, virt: usize): usize {
    if arch == page_table.arch_aarch64 {
        return aarch64_page_table.lookup_bootstrap_phys(spec, virt);
    }
    if arch == page_table.arch_riscv64 {
        return riscv64_page_table.lookup_bootstrap_phys(spec, virt);
    }
    return 0;
}

fn check_arch_bootstrap_mappings(arch: i32, spec: Spec): void {
    var index: usize = 0;
    while index < vm.mapping_request_count() {
        const request = vm.mapping_request(index);
        if lookup_arch_bootstrap_phys(arch, spec, request.virt_start) != request.phys_start {
            fail("selftest: page table lookup start");
        }
        if request.size > spec.page_size {
            const last_offset = request.size - spec.page_size;
            if lookup_arch_bootstrap_phys(arch, spec, request.virt_start + last_offset) != request.phys_start + last_offset {
                fail("selftest: page table lookup end");
            }
        }
        index = index + 1;
    }
}

fn check_aarch64_activation_values(root: usize): void {
    if aarch64_page_table.activation_ttbr0(root) != root {
        fail("selftest: aarch64 activation ttbr0");
    }
    if (aarch64_page_table.activation_mair() & aarch64_page_table.mair_attr_normal_wbwa) == 0 {
        fail("selftest: aarch64 activation mair normal");
    }
    if (aarch64_page_table.activation_mair() & aarch64_page_table.mair_attr_device_ngnre) == 0 {
        fail("selftest: aarch64 activation mair device");
    }
    if (aarch64_page_table.activation_tcr() & aarch64_page_table.tcr_ips_40_bit) == 0 {
        fail("selftest: aarch64 activation tcr ips");
    }
    if (aarch64_page_table.activation_sctlr_set_bits() & aarch64_page_table.sctlr_mmu_enable) == 0 {
        fail("selftest: aarch64 activation sctlr mmu");
    }
}

fn check_riscv64_activation_values(root: usize): void {
    const satp = riscv64_page_table.activation_satp(root);
    if (satp & riscv64_page_table.satp_mode_sv39) != riscv64_page_table.satp_mode_sv39 {
        fail("selftest: riscv64 activation satp mode");
    }
    if riscv64_page_table.activation_root_phys(satp) != root {
        fail("selftest: riscv64 activation satp root");
    }
}

fn check_arch_activation_values(arch: i32, root: usize): void {
    if arch == page_table.arch_aarch64 {
        check_aarch64_activation_values(root);
        return;
    }
    if arch == page_table.arch_riscv64 {
        check_riscv64_activation_values(root);
        return;
    }
    fail("selftest: page table activation arch");
}

pub fn run_page_table_contract_tests(map: Layout, spec: Spec, arch: i32): void {
    if !page_table.validate(spec) {
        fail("selftest: page table spec");
    }
    if spec.page_size != map.page_size {
        fail("selftest: page table page size");
    }
    if !vm.is_power_of_two(spec.entries_per_table) {
        fail("selftest: page table entries power");
    }
    if !vm.is_power_of_two(spec.entry_size) {
        fail("selftest: page table entry size power");
    }
    if page_table.page_offset_mask(spec) != spec.page_size - 1 {
        fail("selftest: page table offset mask");
    }
    if page_table.table_bytes(spec) != map.page_size {
        fail("selftest: page table bytes");
    }
    if page_table.mapped_bits(spec) < spec.page_offset_bits {
        fail("selftest: page table mapped bits");
    }
    if spec.physical_address_bits < spec.page_offset_bits {
        fail("selftest: page table phys bits");
    }
    check_arch_leaf_entries(arch, map.kernel_load);
    check_arch_bootstrap_mappings(arch, spec);
    check_arch_activation_values(arch, vm.bootstrap_plan(map).page_table_root);
}
