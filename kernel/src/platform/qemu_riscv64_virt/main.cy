import .entry;
import .arch.riscv64.context as riscv64_context;
import .arch.riscv64.page_table;
import .arch.riscv64.trap_context;
import .bootstrap;
import .kernel;
import .platform.qemu_riscv64_virt.console;
import .platform.qemu_riscv64_virt.exception;
import .platform.qemu_riscv64_virt.interrupt;
import .platform.qemu_riscv64_virt.memory;
import .platform.qemu_riscv64_virt.tick;
import .platform.qemu_riscv64_virt.timer;
import .platform.qemu_riscv64_virt.vm_activation;
import .memory.address_space;
import .memory.map as memory_map;
import .memory.phys;
import .memory.vm;
import .panic as panic_mod;
import .selftest;
import .task.context;
import .task.process;
import .task.scheduler;
import .task.thread;
import .task.user_entry;
import { UserEntryStatus } from .task.user_entry;

extern c("cory_riscv64_flush_kernel_tlb") fn flush_kernel_tlb(): void;
extern c("cory_normal_thread_a_entry_addr") fn normal_thread_a_entry_addr(): c_ulong;
extern c("cory_normal_thread_a_stack_top") fn normal_thread_a_stack_top(): c_ulong;
extern c("cory_normal_thread_b_entry_addr") fn normal_thread_b_entry_addr(): c_ulong;
extern c("cory_normal_thread_b_stack_top") fn normal_thread_b_stack_top(): c_ulong;
extern c("cory_normal_user_image_addr") fn normal_user_image_addr(): c_ulong;
extern c("cory_arch_yield_trap") fn yield_trap(): void;
extern c("cory_arch_block_trap") fn block_trap(): void;

const kernel_sstatus: usize = 0x0200000100;
var normal_thread_a_id: usize = thread.invalid_id;
var normal_thread_b_id: usize = thread.invalid_id;
var normal_user_thread_id: usize = thread.invalid_id;

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

export c("cory_identity_map_page") fn cory_identity_map_page(phys_addr: c_ulong): c_ulong {
    const page = phys_addr as usize;
    if page_table.lookup_bootstrap_phys(page_table.spec(), page) == page {
        return 1;
    }
    if !page_table.map_bootstrap_page(page_table.spec(), page, page, vm.rights_kernel_rw()) {
        return 0;
    }
    flush_kernel_tlb();
    return 1;
}

export c("cory_switch_thread_address_space") fn cory_switch_thread_address_space(raw_thread_id: c_ulong): void {
    const selected_thread = thread.get(raw_thread_id as usize);
    if selected_thread.id == thread.invalid_id {
        println("address_space: selected thread missing riscv64");
        panic_mod.panic();
    }
    const selected_process = process.get(selected_thread.process_id);
    if selected_process.id == process.invalid_id {
        println("address_space: selected process missing riscv64");
        panic_mod.panic();
    }
    const root = address_space.root_table(selected_process.address_space_id);
    if root == 0 {
        println("address_space: selected root missing riscv64");
        panic_mod.panic();
    }
    if selected_thread.id == normal_user_thread_id {
        interrupt.mask();
        interrupt.disable_timer_irq();
        timer.disarm();
        tick.init_disabled();
    }
    vm_activation.switch_user_root(root);
}

fn prepare_normal_thread(entry_addr: usize, stack_top: usize): usize {
    const kernel_process = process.current();
    const process_info = process.get(kernel_process);
    const thread_id = thread.create_kernel_ready(kernel_process, process_info.capability_slot);
    if thread_id == thread.invalid_id {
        println("scheduler: normal thread create failed");
        panic_mod.panic();
    }
    const arch_context = riscv64_context.allocate(thread_id);
    if arch_context == context.invalid_arch_context {
        println("scheduler: normal thread arch context failed");
        panic_mod.panic();
    }
    if !context.attach_kernel_context(thread_id, entry_addr, stack_top, page_table.arch_id, arch_context) {
        println("scheduler: normal thread attach failed");
        panic_mod.panic();
    }
    if !context.save_resume_state(thread_id, entry_addr, stack_top, kernel_sstatus) {
        println("scheduler: normal thread seed failed");
        panic_mod.panic();
    }
    if !trap_context.seed_resume_frame(arch_context, entry_addr, stack_top, kernel_sstatus) {
        println("scheduler: normal thread frame seed failed");
        panic_mod.panic();
    }
    if !scheduler.enqueue(thread_id) {
        println("scheduler: normal thread enqueue failed");
        panic_mod.panic();
    }
    return thread_id;
}

fn prepare_normal_user_thread(active_root: usize): usize {
    const image = user_entry.init_image_from_header(normal_user_image_addr() as usize);
    const plan = user_entry.prepare_image_thread(page_table.arch_id, active_root, page_table.spec(), image);
    if plan.status != UserEntryStatus.ok {
        println("userspace: normal user prepare failed riscv64");
        panic_mod.panic();
    }
    if !plan.address_space_switch_supported {
        println("userspace: normal user switch unsupported riscv64");
        panic_mod.panic();
    }
    const user_status_flags = riscv64_context.user_status_flags();
    if !context.save_resume_state(plan.thread_id, plan.entry_addr, plan.stack_pointer, user_status_flags) {
        println("userspace: normal user seed failed riscv64");
        panic_mod.panic();
    }
    if !trap_context.seed_resume_frame(plan.arch_context_id, plan.entry_addr, plan.stack_pointer, user_status_flags) {
        println("userspace: normal user frame seed failed riscv64");
        panic_mod.panic();
    }
    return plan.thread_id;
}

export c("cory_normal_thread_a") fn cory_normal_thread_a(): void {
    println("scheduler: normal thread a resumed");
    println("scheduler: normal thread a yielding");
    yield_trap();
    println("scheduler: normal thread a yield returned");
    println("scheduler: normal thread a yielding again");
    yield_trap();
    println("scheduler: normal thread a second yield returned");
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
    tick.init_disabled();
    interrupt.mask();
    interrupt.init_timer_irq();
    println("interrupt: timer irq configured");
    const map = memory.layout();
    bootstrap.prepare_memory(map, page_table.spec(), page_table.arch_id);
    const vm_plan = vm.bootstrap_plan(map, page_table.spec());
    normal_thread_a_id = prepare_normal_thread(normal_thread_a_entry_addr() as usize, normal_thread_a_stack_top() as usize);
    println("scheduler: normal thread a ready");
    normal_thread_b_id = prepare_normal_thread(normal_thread_b_entry_addr() as usize, normal_thread_b_stack_top() as usize);
    println("scheduler: normal thread b ready");
    normal_user_thread_id = prepare_normal_user_thread(vm_plan.page_table_root);
    if !scheduler.enqueue(normal_user_thread_id) {
        println("userspace: normal user enqueue failed riscv64");
        panic_mod.panic();
    }
    println("userspace: init process ready riscv64");
    vm_activation.activate_identity_vm(vm_plan.page_table_root);
    selftest.run_heap_virtual_tests(map, page_table.spec());
    kernel.print_memory_ready();
    if !thread.mark_blocked(scheduler.current()) {
        println("scheduler: bootstrap block failed");
        panic_mod.panic();
    }
    tick.set_enabled();
    if !interrupt.program_timer_after_ticks(tick.interval_ticks()) {
        println("tick: scheduler program failed");
        panic_mod.panic();
    }
    println("tick: scheduler enabled");
    interrupt.unmask();
    kernel.halt();
}
