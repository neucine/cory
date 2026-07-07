import .kernel.arch.riscv64.trap_frame;
import { TrapFrame } from .kernel.arch.riscv64.trap_frame;
import .kernel.entry;
import .kernel.kernel;
import .kernel.console as common_console;
import .kernel.panic as panic_mod;
import .kernel.platform.qemu_riscv64_virt.console;
import .kernel.platform.qemu_riscv64_virt.interrupt;
import .kernel.platform.qemu_riscv64_virt.timer;

extern c("cory_arch_trap_init") fn cory_arch_trap_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;

fn init_vectors(): void {
    if !trap_frame.verify_layout() {
        println("timerirqtest: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_trap_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("timerirqtest: extern c abi probe failed");
        panic_mod.panic();
    }
    println("timerirqtest: vectors ready");
}

export c("cory_arch_trap_entry") fn cory_arch_trap_entry(raw_frame: *TrapFrame): void {
    const frame = trap_frame.diagnostic_from_frame(raw_frame);
    if interrupt.complete_timer_irq(frame.scause) {
        println("timerirqtest: received supervisor timer irq");
        panic_mod.panic();
    }
    println("timerirqtest: unexpected trap");
    println("timerirqtest: scause");
    common_console.println_hex(frame.scause);
    println("timerirqtest: sepc");
    common_console.println_hex(frame.sepc);
    panic_mod.panic();
}

export c("cory_kernel_entry") fn cory_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    interrupt.mask();
    init_vectors();
    if !timer.readable() {
        println("timerirqtest: counter unavailable");
        panic_mod.panic();
    }
    interrupt.init_timer_irq();
    if !interrupt.program_timer_after_ticks(10000) {
        println("timerirqtest: program failed");
        panic_mod.panic();
    }
    println("timerirqtest: waiting for supervisor timer irq");
    interrupt.unmask();
    while true {
    }
}
