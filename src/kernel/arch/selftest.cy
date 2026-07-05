import .kernel.arch.aarch64.context as aarch64_context;
import .kernel.arch.aarch64.page_table as aarch64_page_table;
import .kernel.arch.riscv64.context as riscv64_context;
import .kernel.arch.riscv64.page_table as riscv64_page_table;
import .kernel.object.capability;
import .kernel.object.kernel_object;
import .kernel.memory.address_space;
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

fn check_arch_user_leaf_entries(arch: i32, phys: usize): void {
    if arch == page_table.arch_aarch64 {
        const user_entry = aarch64_page_table.encode_leaf(phys, vm.rights_user_rw());
        const kernel_entry = aarch64_page_table.encode_leaf(phys, vm.rights_kernel_rw());
        if !aarch64_page_table.leaf_is_user_accessible(user_entry) {
            fail("selftest: aarch64 user leaf user");
        }
        if aarch64_page_table.leaf_is_user_accessible(kernel_entry) {
            fail("selftest: aarch64 kernel leaf user");
        }
        return;
    }
    if arch == page_table.arch_riscv64 {
        const user_entry = riscv64_page_table.encode_leaf(phys, vm.rights_user_rw());
        const kernel_entry = riscv64_page_table.encode_leaf(phys, vm.rights_kernel_rw());
        if !riscv64_page_table.leaf_is_user_accessible(user_entry) {
            fail("selftest: riscv64 user leaf user");
        }
        if riscv64_page_table.leaf_is_user_accessible(kernel_entry) {
            fail("selftest: riscv64 kernel leaf user");
        }
        return;
    }
    fail("selftest: page table user leaf arch");
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

fn map_arch_bootstrap_page(arch: i32, spec: Spec, kind: i32, virt: usize, phys: usize, rights: u8): bool {
    if arch == page_table.arch_aarch64 {
        return aarch64_page_table.map_bootstrap_page_for_kind(spec, kind, virt, phys, rights);
    }
    if arch == page_table.arch_riscv64 {
        return riscv64_page_table.map_bootstrap_page(spec, virt, phys, rights);
    }
    return false;
}

fn unmap_arch_bootstrap_page(arch: i32, spec: Spec, virt: usize): bool {
    if arch == page_table.arch_aarch64 {
        return aarch64_page_table.unmap_bootstrap_page(spec, virt);
    }
    if arch == page_table.arch_riscv64 {
        return riscv64_page_table.unmap_bootstrap_page(spec, virt);
    }
    return false;
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

fn check_arch_map_unmap_operations(arch: i32, spec: Spec): void {
    const request = vm.mapping_request(0);
    const virt = request.virt_start;
    const phys = request.phys_start;
    if lookup_arch_bootstrap_phys(arch, spec, virt) != phys {
        fail("selftest: page table map op fixture");
    }
    if map_arch_bootstrap_page(arch, spec, request.kind, virt, phys, request.rights) {
        fail("selftest: page table map overwrite");
    }
    if unmap_arch_bootstrap_page(arch, spec, virt + 1) {
        fail("selftest: page table unmap unaligned");
    }
    if !unmap_arch_bootstrap_page(arch, spec, virt) {
        fail("selftest: page table unmap");
    }
    if lookup_arch_bootstrap_phys(arch, spec, virt) != 0 {
        fail("selftest: page table lookup unmapped");
    }
    if unmap_arch_bootstrap_page(arch, spec, virt) {
        fail("selftest: page table unmap absent");
    }
    if map_arch_bootstrap_page(arch, spec, request.kind, virt + 1, phys, request.rights) {
        fail("selftest: page table map unaligned virt");
    }
    if map_arch_bootstrap_page(arch, spec, request.kind, virt, phys + 1, request.rights) {
        fail("selftest: page table map unaligned phys");
    }
    if map_arch_bootstrap_page(arch, spec, request.kind, virt, phys, 0) {
        fail("selftest: page table map empty rights");
    }
    if !map_arch_bootstrap_page(arch, spec, request.kind, virt, phys, request.rights) {
        fail("selftest: page table remap");
    }
    if lookup_arch_bootstrap_phys(arch, spec, virt) != phys {
        fail("selftest: page table lookup remapped");
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
    if (aarch64_page_table.activation_tcr() & aarch64_page_table.tcr_t1sz_48_bit) == 0 {
        fail("selftest: aarch64 activation tcr t1sz");
    }
    if (aarch64_page_table.activation_tcr() & aarch64_page_table.tcr_tg1_4k) == 0 {
        fail("selftest: aarch64 activation tcr tg1");
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

fn check_context_descriptor(arch_id: i32, size: usize, alignment: usize): void {
    if arch_id != page_table.arch_aarch64 and arch_id != page_table.arch_riscv64 {
        fail("selftest: arch context id");
    }
    if size == 0 {
        fail("selftest: arch context size");
    }
    if alignment == 0 {
        fail("selftest: arch context alignment");
    }
    if !vm.is_power_of_two(alignment) {
        fail("selftest: arch context alignment power");
    }
    if size < alignment {
        fail("selftest: arch context size below alignment");
    }
}

fn check_arch_context_descriptors(active_arch: i32): void {
    aarch64_context.init();
    riscv64_context.init();
    check_context_descriptor(aarch64_context.context_arch_id(), aarch64_context.context_size(), aarch64_context.context_alignment());
    check_context_descriptor(riscv64_context.context_arch_id(), riscv64_context.context_size(), riscv64_context.context_alignment());
    if aarch64_context.count() != 0 {
        fail("selftest: aarch64 context initial count");
    }
    if riscv64_context.count() != 0 {
        fail("selftest: riscv64 context initial count");
    }
    const aarch64_context_id = aarch64_context.allocate(11);
    if aarch64_context_id == aarch64_context.invalid_context {
        fail("selftest: aarch64 context allocate");
    }
    if !aarch64_context.is_live(aarch64_context_id) {
        fail("selftest: aarch64 context live");
    }
    if aarch64_context.owner_thread_id(aarch64_context_id) != 11 {
        fail("selftest: aarch64 context owner");
    }
    if aarch64_context.owner_thread_id(aarch64_context.invalid_context) != 0 {
        fail("selftest: aarch64 context invalid owner");
    }
    if aarch64_context.status() != aarch64_context.status_invalid_context {
        fail("selftest: aarch64 context invalid status");
    }
    const riscv64_context_id = riscv64_context.allocate(12);
    if riscv64_context_id == riscv64_context.invalid_context {
        fail("selftest: riscv64 context allocate");
    }
    if !riscv64_context.is_live(riscv64_context_id) {
        fail("selftest: riscv64 context live");
    }
    if riscv64_context.owner_thread_id(riscv64_context_id) != 12 {
        fail("selftest: riscv64 context owner");
    }
    if riscv64_context.owner_thread_id(riscv64_context.invalid_context) != 0 {
        fail("selftest: riscv64 context invalid owner");
    }
    if riscv64_context.status() != riscv64_context.status_invalid_context {
        fail("selftest: riscv64 context invalid status");
    }
    if active_arch == page_table.arch_aarch64 {
        if aarch64_context.context_arch_id() != active_arch {
            fail("selftest: aarch64 context active arch");
        }
        return;
    }
    if active_arch == page_table.arch_riscv64 {
        if riscv64_context.context_arch_id() != active_arch {
            fail("selftest: riscv64 context active arch");
        }
        return;
    }
    fail("selftest: arch context active arch");
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
    check_arch_user_leaf_entries(arch, map.kernel_load);
    check_arch_bootstrap_mappings(arch, spec);
    check_arch_map_unmap_operations(arch, spec);
    check_arch_activation_values(arch, vm.bootstrap_plan(map, spec).page_table_root);
    check_arch_context_descriptors(arch);
}
