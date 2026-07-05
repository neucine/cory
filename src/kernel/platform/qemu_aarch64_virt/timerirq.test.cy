import .kernel.arch.aarch64.trap_frame;
import { TrapFrame } from .kernel.arch.aarch64.trap_frame;
import .kernel.entry;
import .kernel.kernel;
import .kernel.panic as panic_mod;
import .kernel.platform.qemu_aarch64_virt.console;
import .kernel.platform.qemu_aarch64_virt.gic;
import .kernel.platform.qemu_aarch64_virt.timer;

extern c("cory_arch_exception_init") fn cory_arch_exception_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;
extern c("cory_arch_current_el") fn cory_arch_current_el(): c_ulong;
extern c("cory_aarch64_irq_mask") fn cory_aarch64_irq_mask(): void;
extern c("cory_aarch64_irq_unmask") fn cory_aarch64_irq_unmask(): void;

pub fn init_vectors(): void {
    if cory_arch_current_el() != 1 {
        println("timerirqtest: expected EL1");
        panic_mod.panic();
    }
    if !trap_frame.verify_layout() {
        println("timerirqtest: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_exception_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("timerirqtest: extern c abi probe failed");
        panic_mod.panic();
    }
    println("timerirqtest: vectors ready");
}

export c("cory_arch_exception_entry") fn cory_arch_exception_entry(raw_frame: *TrapFrame): void {
    cory_aarch64_irq_mask();
    const intid = gic.acknowledge();
    if intid == gic.virtual_timer_intid {
        timer.disarm();
        gic.end(intid);
        println("timerirqtest: received virtual timer irq");
        panic_mod.panic();
    }
    if intid != gic.spurious_intid {
        gic.end(intid);
    }
    println("timerirqtest: unexpected interrupt");
    panic_mod.panic();
}

export c("cory_kernel_entry") fn cory_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    cory_aarch64_irq_mask();
    init_vectors();
    gic.init_timer_irq();
    const delta = timer.frequency() / 100;
    if !timer.program_irq_after_ticks(delta) {
        println("timerirqtest: program failed");
        panic_mod.panic();
    }
    println("timerirqtest: waiting for virtual timer irq");
    cory_aarch64_irq_unmask();
    while true {
    }
}
