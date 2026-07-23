import .arch.selftest as arch_selftest;
import .collections.selftest as collections_selftest;
import { Layout } from .memory.layout;
import .memory.selftest as memory_selftest;
import { Spec } from .memory.page_table;
import .object.selftest as object_selftest;
import .task.selftest as task_selftest;

pub fn run_boot_tests(map: Layout): void {
    collections_selftest.run_slot_map_tests();
    memory_selftest.run_boot_tests(map);
}

pub fn run_phys_tests(map: Layout): void {
    memory_selftest.run_phys_tests(map);
}

pub fn run_heap_tests(map: Layout): void {
    memory_selftest.run_heap_tests(map);
}

pub fn run_heap_virtual_tests(map: Layout, spec: Spec): void {
    memory_selftest.run_heap_virtual_tests(map, spec);
}

pub fn run_memory_map_tests(map: Layout): void {
    memory_selftest.run_memory_map_tests(map);
}

pub fn run_vm_contract_tests(map: Layout, spec: Spec): void {
    memory_selftest.run_vm_contract_tests(map, spec);
}

pub fn run_address_space_tests(map: Layout, spec: Spec, kernel_space_id: usize): void {
    memory_selftest.run_address_space_tests(map, spec, kernel_space_id);
}

pub fn run_kernel_object_tests(): void {
    object_selftest.run_kernel_object_tests();
}

pub fn run_capability_tests(): void {
    object_selftest.run_capability_tests();
}

pub fn run_page_table_contract_tests(map: Layout, spec: Spec, arch: i32): void {
    arch_selftest.run_page_table_contract_tests(map, spec, arch);
}

pub fn run_process_tests(kernel_space_id: usize, kernel_process_id: usize): void {
    task_selftest.run_process_tests(kernel_space_id, kernel_process_id);
}

pub fn run_thread_tests(kernel_process_id: usize, kernel_thread_id: usize, arch: i32, spec: Spec): void {
    task_selftest.run_thread_tests(kernel_process_id, kernel_thread_id, arch, spec);
}

pub fn run_scheduler_tests(kernel_process_id: usize, kernel_thread_id: usize): void {
    task_selftest.run_scheduler_tests(kernel_process_id, kernel_thread_id);
}
