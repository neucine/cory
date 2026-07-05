import .kernel.arch.aarch64.context as aarch64_context;
import .kernel.arch.aarch64.page_table;
import .kernel.arch.aarch64.trap_context;
import .kernel.arch.aarch64.trap_frame;
import { TrapFrame } from .kernel.arch.aarch64.trap_frame;
import .kernel.bootstrap;
import .kernel.entry;
import .kernel.kernel;
import .kernel.memory.map as memory_map;
import .kernel.memory.phys;
import .kernel.memory.vm;
import .kernel.panic as panic_mod;
import .kernel.platform.qemu_aarch64_virt.console;
import .kernel.platform.qemu_aarch64_virt.interrupt;
import .kernel.platform.qemu_aarch64_virt.memory;
import .kernel.platform.qemu_aarch64_virt.tick;
import .kernel.platform.qemu_aarch64_virt.timer;
import .kernel.platform.qemu_aarch64_virt.vm_activation;
import .kernel.task.context;
import .kernel.task.process;
import .kernel.task.scheduler;
import .kernel.task.thread;

extern c("cory_arch_exception_init") fn cory_arch_exception_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;
extern c("cory_arch_current_el") fn cory_arch_current_el(): c_ulong;
extern c("cory_aarch64_flush_kernel_tlb") fn flush_kernel_tlb(): void;
extern c("cory_schedtest_current_sp") fn cory_schedtest_current_sp(): c_ulong;
extern c("cory_schedtest_thread_b_entry_addr") fn cory_schedtest_thread_b_entry_addr(): c_ulong;

var thread_b_id: usize = thread.invalid_id;
const kernel_spsr_el1: usize = 0x600003c5;

export c("cory_heap_map_virtual_page") fn cory_heap_map_virtual_page(virtual_addr: c_ulong): c_ulong {
    const phys_page = phys.alloc_page();
    if phys_page == 0 {
        return 0;
    }
    if !page_table.map_bootstrap_page_for_kind(page_table.spec(), memory_map.kind_kernel_heap_virtual, virtual_addr as usize, phys_page, vm.rights_kernel_rw()) {
        if !phys.free_page(phys_page) {
            return 0;
        }
        return 0;
    }
    flush_kernel_tlb();
    return phys_page as c_ulong;
}

fn init_traps(): void {
    if cory_arch_current_el() != 1 {
        println("timerschedtest: expected EL1");
        panic_mod.panic();
    }
    if !trap_frame.verify_layout() {
        println("timerschedtest: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_exception_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("timerschedtest: extern c abi probe failed");
        panic_mod.panic();
    }
    println("timerschedtest: vectors ready");
}

fn prepare_ready_thread(): void {
    const kernel_process = process.current();
    const process_info = process.get(kernel_process);
    thread_b_id = thread.create_kernel_ready(kernel_process, process_info.capability_slot);
    if thread_b_id == thread.invalid_id {
        println("timerschedtest: create ready thread failed");
        panic_mod.panic();
    }
    const arch_context = aarch64_context.allocate(thread_b_id);
    if arch_context == context.invalid_arch_context {
        println("timerschedtest: arch context failed");
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
        println("timerschedtest: attach context failed");
        panic_mod.panic();
    }
    if !context.save_resume_state(thread_b_id, thread_b_entry, thread_b_stack, kernel_spsr_el1) {
        println("timerschedtest: seed context failed");
        panic_mod.panic();
    }
    if !scheduler.enqueue(thread_b_id) {
        println("timerschedtest: enqueue failed");
        panic_mod.panic();
    }
    println("timerschedtest: ready thread b");
}

export c("cory_arch_sync_exception_entry") fn cory_arch_sync_exception_entry(raw_frame: *TrapFrame): void {
    println("timerschedtest: unexpected sync exception");
    panic_mod.panic();
}

export c("cory_arch_irq_exception_entry") fn cory_arch_irq_exception_entry(raw_frame: *TrapFrame): void {
    interrupt.mask();
    const intid = interrupt.acknowledge();
    if !interrupt.complete_timer_irq(intid) {
        println("timerschedtest: unexpected interrupt");
        panic_mod.panic();
    }
    if !tick.enabled() {
        println("timerschedtest: tick delivery disabled");
        panic_mod.panic();
    }

    if scheduler.peek() != thread_b_id {
        println("timerschedtest: schedule failed");
        panic_mod.panic();
    }
    println("timerschedtest: selected thread b");
    if !trap_context.schedule_and_restore(raw_frame) {
        println("timerschedtest: schedule restore failed");
        if trap_context.status() == trap_context.status_schedule_failed {
            println("timerschedtest: schedule status failed");
        }
        if trap_context.status() == trap_context.status_resume_state_missing {
            println("timerschedtest: resume state missing");
        }
        panic_mod.panic();
    }
    println("timerschedtest: restore returned unexpectedly");
    panic_mod.panic();
}

export c("cory_schedtest_thread_b") fn cory_schedtest_thread_b(): void {
    println("timerschedtest: thread b resumed");
    panic_mod.panic();
}

export c("cory_kernel_entry") fn cory_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    interrupt.mask();
    init_traps();
    const map = memory.layout();
    bootstrap.prepare_memory(map, page_table.spec(), page_table.arch_id);
    vm_activation.activate_identity_vm(vm.bootstrap_plan(map, page_table.spec()).page_table_root);
    prepare_ready_thread();
    tick.set_enabled();
    interrupt.init_timer_irq();
    const delta = timer.frequency() / 100;
    if !interrupt.program_timer_after_ticks(delta) {
        println("timerschedtest: program failed");
        panic_mod.panic();
    }
    println("timerschedtest: waiting for timer irq");
    interrupt.unmask();
    while true {
    }
}
