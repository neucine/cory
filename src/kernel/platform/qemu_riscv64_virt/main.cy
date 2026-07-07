import .kernel.entry;
import .kernel.arch.riscv64.context as riscv64_context;
import .kernel.arch.riscv64.page_table;
import .kernel.bootstrap;
import .kernel.kernel;
import .kernel.platform.qemu_riscv64_virt.console;
import .kernel.platform.qemu_riscv64_virt.exception;
import .kernel.platform.qemu_riscv64_virt.interrupt;
import .kernel.platform.qemu_riscv64_virt.memory;
import .kernel.platform.qemu_riscv64_virt.tick;
import .kernel.platform.qemu_riscv64_virt.timer;
import .kernel.platform.qemu_riscv64_virt.vm_activation;
import .kernel.memory.phys;
import .kernel.memory.vm;
import .kernel.panic as panic_mod;
import .kernel.selftest;
import .kernel.task.context;
import .kernel.task.process;
import .kernel.task.scheduler;
import .kernel.task.thread;

extern c("cory_riscv64_flush_kernel_tlb") fn flush_kernel_tlb(): void;
extern c("cory_normal_thread_entry_addr") fn normal_thread_entry_addr(): c_ulong;
extern c("cory_normal_thread_stack_top") fn normal_thread_stack_top(): c_ulong;
extern c("cory_arch_yield_trap") fn yield_trap(): void;
extern c("cory_arch_block_trap") fn block_trap(): void;

const kernel_sstatus: usize = 0x0200000100;
var normal_thread_id: usize = thread.invalid_id;

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

fn prepare_normal_thread(): void {
    const kernel_process = process.current();
    const process_info = process.get(kernel_process);
    normal_thread_id = thread.create_kernel_ready(kernel_process, process_info.capability_slot);
    if normal_thread_id == thread.invalid_id {
        println("scheduler: normal thread create failed");
        panic_mod.panic();
    }
    const arch_context = riscv64_context.allocate(normal_thread_id);
    if arch_context == context.invalid_arch_context {
        println("scheduler: normal thread arch context failed");
        panic_mod.panic();
    }
    const entry_addr = normal_thread_entry_addr() as usize;
    const stack_top = normal_thread_stack_top() as usize;
    if !context.attach_kernel_context(normal_thread_id, entry_addr, stack_top, page_table.arch_id, arch_context) {
        println("scheduler: normal thread attach failed");
        panic_mod.panic();
    }
    if !context.save_resume_state(normal_thread_id, entry_addr, stack_top, kernel_sstatus) {
        println("scheduler: normal thread seed failed");
        panic_mod.panic();
    }
    if !scheduler.enqueue(normal_thread_id) {
        println("scheduler: normal thread enqueue failed");
        panic_mod.panic();
    }
    println("scheduler: normal thread ready");
}

export c("cory_normal_thread") fn cory_normal_thread(): void {
    println("scheduler: normal thread resumed");
    println("scheduler: normal thread yielding");
    yield_trap();
    println("scheduler: normal thread yield returned");
    println("scheduler: normal thread blocking");
    block_trap();
    println("scheduler: normal thread block returned unexpectedly");
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
    tick.init_disabled();
    interrupt.mask();
    interrupt.init_timer_irq();
    println("interrupt: timer irq configured");
    const map = memory.layout();
    bootstrap.prepare_memory(map, page_table.spec(), page_table.arch_id);
    vm_activation.activate_identity_vm(vm.bootstrap_plan(map, page_table.spec()).page_table_root);
    prepare_normal_thread();
    selftest.run_heap_virtual_tests(map, page_table.spec());
    kernel.print_memory_ready();
    tick.set_enabled();
    if !interrupt.program_timer_after_ticks(tick.interval_ticks()) {
        println("tick: scheduler program failed");
        panic_mod.panic();
    }
    println("tick: scheduler enabled");
    interrupt.unmask();
    kernel.halt();
}
