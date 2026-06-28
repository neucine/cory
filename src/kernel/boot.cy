import .kernel.kernel;
import .kernel.arch.aarch64.page_table as aarch64_page_table;
import .kernel.arch.riscv64.page_table as riscv64_page_table;
import .kernel.memory.address_space;
import .kernel.memory.heap;
import { Layout } from .kernel.memory.layout;
import .kernel.memory.boot as boot_memory;
import .kernel.memory.map as memory_map;
import .kernel.memory.page_table;
import { Spec } from .kernel.memory.page_table;
import .kernel.memory.phys;
import .kernel.memory.vm;
import .kernel.panic as panic_mod;
import .kernel.selftest;

fn populate_bootstrap_page_tables(page_tables: Spec, page_table_arch: i32): bool {
    if page_table_arch == page_table.arch_aarch64 {
        return aarch64_page_table.populate_bootstrap_tables(page_tables);
    }
    if page_table_arch == page_table.arch_riscv64 {
        return riscv64_page_table.populate_bootstrap_tables(page_tables);
    }
    return false;
}

// Prepare memory up to a populated identity page-table root. The final MMU
// register switch is platform-owned because the assembly symbol is target
// specific and must not leak into other architecture links.
pub fn prepare_memory(map: Layout, page_tables: Spec, page_table_arch: i32): void {
    boot_memory.init(map.ram_end, map.page_size);
    selftest.run_boot_tests(map);
    if !phys.init(map) {
        panic_mod.panic();
    }
    selftest.run_phys_tests(map);
    heap.init(map);
    selftest.run_heap_tests(map);
    if !memory_map.rebuild(map) {
        panic_mod.panic();
    }
    if !vm.rebuild_bootstrap_mappings(map, page_tables) {
        panic_mod.panic();
    }
    if !vm.allocate_bootstrap_page_tables(map, page_tables) {
        panic_mod.panic();
    }
    if !vm.clear_bootstrap_page_tables(page_tables) {
        panic_mod.panic();
    }
    // Reserving page-table storage changes the owned memory map. Rebuild both
    // the canonical map and the derived identity requests before population.
    if !memory_map.rebuild(map) {
        panic_mod.panic();
    }
    if !vm.rebuild_bootstrap_mappings(map, page_tables) {
        panic_mod.panic();
    }
    if !populate_bootstrap_page_tables(page_tables, page_table_arch) {
        panic_mod.panic();
    }
    selftest.run_memory_map_tests(map);
    selftest.run_vm_contract_tests(map, page_tables);
    selftest.run_page_table_contract_tests(map, page_tables, page_table_arch);
    address_space.init();
    const plan = vm.bootstrap_plan(map, page_tables);
    const kernel_space = address_space.create_kernel_bootstrap(plan.page_table_root, plan.user_base, plan.user_end, plan.kernel_base, plan.kernel_heap_base, plan.kernel_heap_end);
    if kernel_space == address_space.invalid_id {
        panic_mod.panic();
    }
    selftest.run_address_space_tests(map, page_tables, kernel_space);
    if !heap.enable_virtual_mapping(vm.kernel_heap_virtual_base_for_spec(page_tables)) {
        panic_mod.panic();
    }
}

pub fn finish_after_memory_ready(map: Layout, page_tables: Spec): void {
    selftest.run_heap_virtual_tests(map, page_tables);
    kernel.print_memory_ready();
    kernel.halt();
}
