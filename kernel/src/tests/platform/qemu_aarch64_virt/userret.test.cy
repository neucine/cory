import .arch.aarch64.context as aarch64_context;
import .arch.aarch64.page_table;
import .arch.aarch64.trap_context;
import .arch.aarch64.trap_frame;
import { TrapFrame } from .arch.aarch64.trap_frame;
import .bootstrap;
import .entry;
import .kernel;
import .memory.map as memory_map;
import .memory.phys;
import .memory.vm;
import .panic as panic_mod;
import .platform.qemu_aarch64_virt.console;
import .platform.qemu_aarch64_virt.memory;
import .platform.qemu_aarch64_virt.vm_activation;
import .task.context;
import .task.thread;
import .task.user_entry;
import { UserEntryStatus } from .task.user_entry;

extern c("cory_arch_exception_init") fn cory_arch_exception_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;
extern c("cory_arch_current_el") fn cory_arch_current_el(): c_ulong;
extern c("cory_arch_trigger_test_trap") fn cory_arch_trigger_test_trap(): void;
extern c("cory_aarch64_flush_kernel_tlb") fn flush_kernel_tlb(): void;
extern c("cory_usermode_probe_entry_addr") fn user_probe_entry_addr(): c_ulong;

var user_thread_id: usize = thread.invalid_id;
var user_root: usize = 0;
var returning_to_user: bool = false;

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
        println("userrettest: expected EL1");
        panic_mod.panic();
    }
    if !trap_frame.verify_layout() {
        println("userrettest: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_exception_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("userrettest: extern c abi probe failed");
        panic_mod.panic();
    }
    println("userrettest: vectors ready");
}

fn prepare_user_thread(active_root: usize): void {
    const plan = user_entry.prepare_probe_thread(page_table.arch_id, active_root, page_table.spec(), user_probe_entry_addr() as usize);
    if plan.status != UserEntryStatus.ok {
        println("userrettest: user entry plan failed aarch64");
        panic_mod.panic();
    }
    if !plan.address_space_switch_supported {
        println("userrettest: user root switch unsupported aarch64");
        panic_mod.panic();
    }
    user_thread_id = plan.thread_id;
    user_root = plan.user_root;
    println("userrettest: user thread ready aarch64");
}

export c("cory_arch_sync_exception_entry") fn cory_arch_sync_exception_entry(raw_frame: *TrapFrame): void {
    if !returning_to_user {
        println("userrettest: return to user aarch64");
        returning_to_user = true;
        const user_context = context.get(user_thread_id);
        trap_frame.set_resume_state_in_frame(raw_frame, user_context.instruction_pointer, user_context.stack_pointer, user_context.status_flags);
        trap_context.restore_from_frame(raw_frame);
        println("userrettest: restore returned unexpectedly");
        panic_mod.panic();
    }
    if (trap_frame.status_flags_from_frame(raw_frame) & 15) != aarch64_context.user_status_flags() {
        println("userrettest: user status mismatch aarch64");
        panic_mod.panic();
    }
    println("userrettest: user trap aarch64");
    panic_mod.panic();
}

export c("cory_arch_irq_exception_entry") fn cory_arch_irq_exception_entry(raw_frame: *TrapFrame): void {
    println("userrettest: unexpected irq");
    panic_mod.panic();
}

export c("cory_kernel_entry") fn cory_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    init_traps();
    const map = memory.layout();
    bootstrap.prepare_memory(map, page_table.spec(), page_table.arch_id);
    const plan = vm.bootstrap_plan(map, page_table.spec());
    prepare_user_thread(plan.page_table_root);
    vm_activation.activate_identity_vm(plan.page_table_root);
    vm_activation.switch_user_root(user_root);
    println("userrettest: switched user root aarch64");
    println("userrettest: trigger kernel trap aarch64");
    cory_arch_trigger_test_trap();
    println("userrettest: kernel trap returned unexpectedly");
    panic_mod.panic();
}
