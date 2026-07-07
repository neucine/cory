import .kernel.arch.riscv64.context as riscv64_context;
import .kernel.arch.riscv64.page_table;
import .kernel.arch.riscv64.trap_context;
import .kernel.arch.riscv64.trap_frame;
import { TrapFrame } from .kernel.arch.riscv64.trap_frame;
import .kernel.bootstrap;
import .kernel.entry;
import .kernel.kernel;
import .kernel.memory.phys;
import .kernel.memory.vm;
import .kernel.panic as panic_mod;
import .kernel.platform.qemu_riscv64_virt.console;
import .kernel.platform.qemu_riscv64_virt.memory;
import .kernel.platform.qemu_riscv64_virt.vm_activation;
import .kernel.task.context;
import .kernel.task.process;
import .kernel.task.scheduler;
import .kernel.task.thread;

extern c("cory_arch_trap_init") fn cory_arch_trap_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;
extern c("cory_arch_trigger_test_trap") fn cory_arch_trigger_test_trap(): void;
extern c("cory_riscv64_flush_kernel_tlb") fn flush_kernel_tlb(): void;
extern c("cory_schedtest_current_sp") fn cory_schedtest_current_sp(): c_ulong;
extern c("cory_schedtest_thread_b_entry_addr") fn cory_schedtest_thread_b_entry_addr(): c_ulong;

var thread_b_id: usize = thread.invalid_id;
const kernel_sstatus: usize = 0x0200000100;

export c("cory_heap_map_virtual_page") fn cory_heap_map_virtual_page(virtual_addr: c_ulong): c_ulong {
    const phys_page = phys.alloc_page();
    if phys_page == 0 {
        return 0;
    }
    if !page_table.map_bootstrap_page(page_table.spec(), virtual_addr as usize, phys_page, vm.rights_kernel_rw()) {
        if !phys.free_page(phys_page) {
            return 0;
        }
        return 0;
    }
    flush_kernel_tlb();
    return phys_page as c_ulong;
}

fn init_traps(): void {
    if !trap_frame.verify_layout() {
        println("schedtest: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_trap_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("schedtest: extern c abi probe failed");
        panic_mod.panic();
    }
    println("schedtest: vectors ready");
}

fn prepare_ready_thread(): void {
    const kernel_process = process.current();
    const process_info = process.get(kernel_process);
    thread_b_id = thread.create_kernel_ready(kernel_process, process_info.capability_slot);
    if thread_b_id == thread.invalid_id {
        println("schedtest: create ready thread failed");
        panic_mod.panic();
    }
    const arch_context = riscv64_context.allocate(thread_b_id);
    if arch_context == context.invalid_arch_context {
        println("schedtest: arch context failed");
        panic_mod.panic();
    }
    const thread_b_entry = cory_schedtest_thread_b_entry_addr() as usize;
    const thread_b_stack = cory_schedtest_current_sp() as usize;
    if !context.attach_kernel_context(
        thread_b_id,
        thread_b_entry,
        thread_b_stack,
        page_table.arch_id,
        arch_context
    ) {
        println("schedtest: attach context failed");
        panic_mod.panic();
    }
    if !context.save_resume_state(thread_b_id, thread_b_entry, thread_b_stack, kernel_sstatus) {
        println("schedtest: seed context failed");
        panic_mod.panic();
    }
    if !trap_context.seed_resume_frame(arch_context, thread_b_entry, thread_b_stack, kernel_sstatus) {
        println("schedtest: seed frame failed");
        panic_mod.panic();
    }
    if !scheduler.enqueue(thread_b_id) {
        println("schedtest: enqueue failed");
        panic_mod.panic();
    }
    println("schedtest: ready thread b");
}

export c("cory_arch_trap_entry") fn cory_arch_trap_entry(raw_frame: *TrapFrame): void {
    println("schedtest: trap thread a");
    if scheduler.peek() != thread_b_id {
        println("schedtest: schedule failed");
        panic_mod.panic();
    }
    println("schedtest: selected thread b");
    if !trap_context.schedule_and_restore(raw_frame) {
        println("schedtest: schedule restore failed");
        if trap_context.status() == trap_context.status_schedule_failed {
            println("schedtest: schedule status failed");
        }
        if trap_context.status() == trap_context.status_resume_state_missing {
            println("schedtest: resume state missing");
        }
        panic_mod.panic();
    }
    println("schedtest: restore returned unexpectedly");
    panic_mod.panic();
}

export c("cory_schedtest_thread_b") fn cory_schedtest_thread_b(): void {
    println("schedtest: thread b resumed");
    panic_mod.panic();
}

export c("cory_kernel_entry") fn cory_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    init_traps();
    const map = memory.layout();
    bootstrap.prepare_memory(map, page_table.spec(), page_table.arch_id);
    vm_activation.activate_identity_vm(vm.bootstrap_plan(map, page_table.spec()).page_table_root);
    prepare_ready_thread();
    println("schedtest: trigger thread a");
    cory_arch_trigger_test_trap();
    println("schedtest: thread a returned unexpectedly");
    panic_mod.panic();
}
