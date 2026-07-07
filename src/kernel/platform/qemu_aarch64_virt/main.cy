import .kernel.entry;
import .kernel.arch.aarch64.context as aarch64_context;
import .kernel.arch.aarch64.page_table;
import .kernel.arch.aarch64.trap_context;
import .kernel.bootstrap;
import .kernel.kernel;
import .kernel.platform.qemu_aarch64_virt.console;
import .kernel.platform.qemu_aarch64_virt.exception;
import .kernel.platform.qemu_aarch64_virt.interrupt;
import .kernel.platform.qemu_aarch64_virt.memory;
import .kernel.platform.qemu_aarch64_virt.tick;
import .kernel.platform.qemu_aarch64_virt.timer;
import .kernel.platform.qemu_aarch64_virt.vm_activation;
import .kernel.memory.map as memory_map;
import .kernel.memory.phys;
import .kernel.memory.vm;
import .kernel.panic as panic_mod;
import .kernel.selftest;
import .kernel.task.context;
import .kernel.task.process;
import .kernel.task.scheduler;
import .kernel.task.thread;

extern c("cory_aarch64_flush_kernel_tlb") fn flush_kernel_tlb(): void;
extern c("cory_normal_thread_a_entry_addr") fn normal_thread_a_entry_addr(): c_ulong;
extern c("cory_normal_thread_a_stack_top") fn normal_thread_a_stack_top(): c_ulong;
extern c("cory_normal_thread_b_entry_addr") fn normal_thread_b_entry_addr(): c_ulong;
extern c("cory_normal_thread_b_stack_top") fn normal_thread_b_stack_top(): c_ulong;
extern c("cory_arch_yield_trap") fn yield_trap(): void;
extern c("cory_arch_block_trap") fn block_trap(): void;

const kernel_spsr_el1: usize = 0x600003c5;
var normal_thread_a_id: usize = thread.invalid_id;
var normal_thread_b_id: usize = thread.invalid_id;

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

fn prepare_normal_thread(entry_addr: usize, stack_top: usize): usize {
    const kernel_process = process.current();
    const process_info = process.get(kernel_process);
    const thread_id = thread.create_kernel_ready(kernel_process, process_info.capability_slot);
    if thread_id == thread.invalid_id {
        println("scheduler: normal thread create failed");
        panic_mod.panic();
    }
    const arch_context = aarch64_context.allocate(thread_id);
    if arch_context == context.invalid_arch_context {
        println("scheduler: normal thread arch context failed");
        panic_mod.panic();
    }
    if !context.attach_kernel_context(thread_id, entry_addr, stack_top, page_table.arch_id, arch_context) {
        println("scheduler: normal thread attach failed");
        panic_mod.panic();
    }
    if !context.save_resume_state(thread_id, entry_addr, stack_top, kernel_spsr_el1) {
        println("scheduler: normal thread seed failed");
        panic_mod.panic();
    }
    if !trap_context.seed_resume_frame(arch_context, entry_addr, stack_top, kernel_spsr_el1) {
        println("scheduler: normal thread frame seed failed");
        panic_mod.panic();
    }
    if !scheduler.enqueue(thread_id) {
        println("scheduler: normal thread enqueue failed");
        panic_mod.panic();
    }
    return thread_id;
}

export c("cory_normal_thread_a") fn cory_normal_thread_a(): void {
    println("scheduler: normal thread a resumed");
    println("scheduler: normal thread a yielding");
    yield_trap();
    println("scheduler: normal thread a yield returned");
    while true {
    }
}

export c("cory_normal_thread_b") fn cory_normal_thread_b(): void {
    println("scheduler: normal thread b resumed");
    println("scheduler: normal thread b blocking");
    block_trap();
    println("scheduler: normal thread b block returned unexpectedly");
    panic_mod.panic();
}

export c("cory_kernel_entry") fn cory_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    exception.init();
    if !timer.readable() {
        println("timer: counter unavailable");
        panic_mod.panic();
    }
    println("timer: counter ready");
    if !timer.deadline_programmable() {
        println("timer: deadline unavailable");
        panic_mod.panic();
    }
    println("timer: deadline ready");
    tick.init_disabled();
    interrupt.mask();
    interrupt.init_timer_irq();
    println("interrupt: timer irq configured");
    const map = memory.layout();
    bootstrap.prepare_memory(map, page_table.spec(), page_table.arch_id);
    vm_activation.activate_identity_vm(vm.bootstrap_plan(map, page_table.spec()).page_table_root);
    normal_thread_a_id = prepare_normal_thread(normal_thread_a_entry_addr() as usize, normal_thread_a_stack_top() as usize);
    println("scheduler: normal thread a ready");
    normal_thread_b_id = prepare_normal_thread(normal_thread_b_entry_addr() as usize, normal_thread_b_stack_top() as usize);
    println("scheduler: normal thread b ready");
    selftest.run_heap_virtual_tests(map, page_table.spec());
    kernel.print_memory_ready();
    if !thread.mark_blocked(scheduler.current()) {
        println("scheduler: bootstrap block failed");
        panic_mod.panic();
    }
    tick.set_enabled();
    if !interrupt.program_timer_after_ticks(tick.interval_ticks(timer.frequency())) {
        println("tick: scheduler program failed");
        panic_mod.panic();
    }
    println("tick: scheduler enabled");
    interrupt.unmask();
    kernel.halt();
}
