import .arch.aarch64.context as aarch64_context;
import .arch.aarch64.page_table;
import .arch.aarch64.trap_context;
import .bootstrap;
import .entry;
import .kernel;
import .memory.map as memory_map;
import .memory.phys;
import .memory.vm;
import .panic as panic_mod;
import .platform.qemu_aarch64_virt.console;
import .platform.qemu_aarch64_virt.exception;
import .platform.qemu_aarch64_virt.interrupt;
import .platform.qemu_aarch64_virt.memory;
import .platform.qemu_aarch64_virt.tick;
import .platform.qemu_aarch64_virt.timer;
import .platform.qemu_aarch64_virt.vm_activation;
import .task.context;
import .task.process;
import .task.scheduler;
import .task.thread;

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

fn prepare_ready_thread(): void {
    const kernel_process = process.current();
    const process_info = process.get(kernel_process);
    thread_b_id = thread.create_kernel_ready(kernel_process, process_info.capability_slot);
    if thread_b_id == thread.invalid_id {
        println("normalschedtest: create ready thread failed");
        panic_mod.panic();
    }
    const arch_context = aarch64_context.allocate(thread_b_id);
    if arch_context == context.invalid_arch_context {
        println("normalschedtest: arch context failed");
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
        println("normalschedtest: attach context failed");
        panic_mod.panic();
    }
    if !context.save_resume_state(thread_b_id, thread_b_entry, thread_b_stack, kernel_spsr_el1) {
        println("normalschedtest: seed context failed");
        panic_mod.panic();
    }
    if !trap_context.seed_resume_frame(arch_context, thread_b_entry, thread_b_stack, kernel_spsr_el1) {
        println("normalschedtest: seed frame failed");
        panic_mod.panic();
    }
    if !scheduler.enqueue(thread_b_id) {
        println("normalschedtest: enqueue failed");
        panic_mod.panic();
    }
    println("normalschedtest: ready thread b");
}

export c("cory_schedtest_thread_b") fn cory_schedtest_thread_b(): void {
    println("normalschedtest: thread b resumed");
    panic_mod.panic();
}

export c("cory_kernel_entry") fn cory_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    interrupt.mask();
    exception.init();
    const map = memory.layout();
    bootstrap.prepare_memory(map, page_table.spec(), page_table.arch_id);
    vm_activation.activate_identity_vm(vm.bootstrap_plan(map, page_table.spec()).page_table_root);
    prepare_ready_thread();
    tick.set_enabled();
    interrupt.init_timer_irq();
    const delta = timer.frequency() / 100;
    if !interrupt.program_timer_after_ticks(delta) {
        println("normalschedtest: program failed");
        panic_mod.panic();
    }
    println("normalschedtest: waiting for scheduler tick");
    interrupt.unmask();
    while true {
    }
}
