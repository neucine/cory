import .kernel;
import .fs;
import .arch.aarch64.context as aarch64_context;
import .arch.aarch64.page_table as aarch64_page_table;
import .arch.riscv64.context as riscv64_context;
import .arch.riscv64.page_table as riscv64_page_table;
import .memory.address_space;
import .memory.heap;
import { Layout } from .memory.layout;
import .memory.boot as boot_memory;
import .memory.map as memory_map;
import .memory.page_table;
import .memory.page_table_pages;
import { Spec } from .memory.page_table;
import .memory.phys;
import .memory.vm;
import .object.capability;
import .object.kernel_object;
import .panic as panic_mod;
import .selftest;
import .task.capability_space;
import .task.context;
import .task.process;
import .task.process_arg;
import .task.process_resources;
import .task.scheduler;
import .task.thread;
import .task.user_program;

fn populate_bootstrap_page_tables(page_tables: Spec, page_table_arch: i32): bool {
    if page_table_arch == page_table.arch_aarch64 {
        return aarch64_page_table.populate_bootstrap_tables(page_tables);
    }
    if page_table_arch == page_table.arch_riscv64 {
        return riscv64_page_table.populate_bootstrap_tables(page_tables);
    }
    return false;
}

fn init_arch_contexts(): void {
    aarch64_context.init();
    riscv64_context.init();
}

fn init_object_spaces(): void {
    kernel_object.init();
    capability.init();
    capability_space.init();
    address_space.init();
    process.init();
    thread.init();
    context.init();
    scheduler.init();
    user_program.init();
    process_arg.init();
    fs.init();
    process_resources.init();
    page_table_pages.init();
    init_arch_contexts();
}

fn allocate_arch_context(page_table_arch: i32, thread_id: usize): usize {
    if page_table_arch == page_table.arch_aarch64 {
        return aarch64_context.allocate(thread_id);
    }
    if page_table_arch == page_table.arch_riscv64 {
        return riscv64_context.allocate(thread_id);
    }
    return context.invalid_arch_context;
}

// Common bootstrap orchestration. Architecture/platform entry code reaches this
// point after privilege-mode normalization and UART setup; this module then
// brings up platform-neutral kernel mechanisms in dependency order.
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
    selftest.run_kernel_object_tests();
    selftest.run_capability_tests();
    init_object_spaces();
    const plan = vm.bootstrap_plan(map, page_tables);
    const kernel_space = address_space.create_kernel_bootstrap(plan.page_table_root, plan.user_base, plan.user_end, plan.kernel_base, plan.kernel_heap_base, plan.kernel_heap_end);
    if kernel_space == address_space.invalid_id {
        panic_mod.panic();
    }
    selftest.run_address_space_tests(map, page_tables, kernel_space);
    const kernel_process = process.create_kernel_bootstrap(kernel_space, address_space.capability_id(kernel_space));
    if kernel_process == process.invalid_id {
        panic_mod.panic();
    }
    selftest.run_process_tests(kernel_space, kernel_process);
    const kernel_process_info = process.get(kernel_process);
    const kernel_thread = thread.create_kernel_bootstrap(kernel_process, kernel_process_info.capability_slot);
    if kernel_thread == thread.invalid_id {
        panic_mod.panic();
    }
    const kernel_arch_context = allocate_arch_context(page_table_arch, kernel_thread);
    if kernel_arch_context == context.invalid_arch_context {
        panic_mod.panic();
    }
    if !context.attach_kernel_context(kernel_thread, 0, 0, page_table_arch, kernel_arch_context) {
        panic_mod.panic();
    }
    if !scheduler.set_current(kernel_thread) {
        panic_mod.panic();
    }
    selftest.run_thread_tests(kernel_process, kernel_thread, page_table_arch, page_tables);
    selftest.run_scheduler_tests(kernel_process, kernel_thread);
    init_object_spaces();
    const final_kernel_space = address_space.create_kernel_bootstrap(plan.page_table_root, plan.user_base, plan.user_end, plan.kernel_base, plan.kernel_heap_base, plan.kernel_heap_end);
    if final_kernel_space == address_space.invalid_id {
        panic_mod.panic();
    }
    const final_kernel_process = process.create_kernel_bootstrap(final_kernel_space, address_space.capability_id(final_kernel_space));
    if final_kernel_process == process.invalid_id {
        panic_mod.panic();
    }
    const final_kernel_process_info = process.get(final_kernel_process);
    const final_kernel_thread = thread.create_kernel_bootstrap(final_kernel_process, final_kernel_process_info.capability_slot);
    if final_kernel_thread == thread.invalid_id {
        panic_mod.panic();
    }
    const final_kernel_arch_context = allocate_arch_context(page_table_arch, final_kernel_thread);
    if final_kernel_arch_context == context.invalid_arch_context {
        panic_mod.panic();
    }
    if !context.attach_kernel_context(final_kernel_thread, 0, 0, page_table_arch, final_kernel_arch_context) {
        panic_mod.panic();
    }
    if !scheduler.set_current(final_kernel_thread) {
        panic_mod.panic();
    }
    if !heap.enable_virtual_mapping(vm.kernel_heap_virtual_base_for_spec(page_tables)) {
        panic_mod.panic();
    }
}

pub fn finish_after_memory_ready(map: Layout, page_tables: Spec): void {
    selftest.run_heap_virtual_tests(map, page_tables);
    kernel.print_memory_ready();
    kernel.halt();
}
