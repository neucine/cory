import .tests.arch_tests;
import .tests.collections_tests;
import { Layout } from .memory.layout;
import .tests.memory_tests;
import { Spec } from .memory.page_table;
import .tests.object_tests;
import .tests.task_tests;

pub fn run_boot_tests(map: Layout): void {
    collections_tests.run_slot_map_tests();
    memory_tests.run_boot_tests(map);
}

pub fn run_phys_tests(map: Layout): void {
    memory_tests.run_phys_tests(map);
}

pub fn run_heap_tests(map: Layout): void {
    memory_tests.run_heap_tests(map);
}

pub fn run_heap_virtual_tests(map: Layout, spec: Spec): void {
    memory_tests.run_heap_virtual_tests(map, spec);
}

pub fn run_memory_map_tests(map: Layout): void {
    memory_tests.run_memory_map_tests(map);
}

pub fn run_vm_contract_tests(map: Layout, spec: Spec): void {
    memory_tests.run_vm_contract_tests(map, spec);
}

pub fn run_address_space_tests(map: Layout, spec: Spec, kernel_space_id: usize): void {
    memory_tests.run_address_space_tests(map, spec, kernel_space_id);
}

pub fn run_kernel_object_tests(): void {
    object_tests.run_kernel_object_tests();
}

pub fn run_capability_tests(): void {
    object_tests.run_capability_tests();
}

pub fn run_page_table_contract_tests(map: Layout, spec: Spec, arch: i32): void {
    arch_tests.run_page_table_contract_tests(map, spec, arch);
}

pub fn run_process_tests(kernel_space_id: usize, kernel_process_id: usize): void {
    task_tests.run_process_tests(kernel_space_id, kernel_process_id);
}

pub fn run_thread_tests(kernel_process_id: usize, kernel_thread_id: usize, arch: i32, spec: Spec): void {
    task_tests.run_thread_tests(kernel_process_id, kernel_thread_id, arch, spec);
}

pub fn run_scheduler_tests(kernel_process_id: usize, kernel_thread_id: usize): void {
    task_tests.run_scheduler_tests(kernel_process_id, kernel_thread_id);
}
