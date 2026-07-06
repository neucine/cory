import .kernel.entry;
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

extern c("cory_aarch64_flush_kernel_tlb") fn flush_kernel_tlb(): void;

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
    tick.set_enabled();
    if !interrupt.program_timer_after_ticks(timer.frequency() / 100) {
        println("tick: scheduler program failed");
        panic_mod.panic();
    }
    println("tick: scheduler enabled");
    interrupt.unmask();
    const map = memory.layout();
    bootstrap.prepare_memory(map, page_table.spec(), page_table.arch_id);
    vm_activation.activate_identity_vm(vm.bootstrap_plan(map, page_table.spec()).page_table_root);
    bootstrap.finish_after_memory_ready(map, page_table.spec());
}
