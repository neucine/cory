import .kernel.arch.riscv64.trap_frame;
import { TrapFrame } from .kernel.arch.riscv64.trap_frame;
import .kernel.console;
import .kernel.panic as panic_mod;

extern c("cory_arch_trap_init") fn cory_arch_trap_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;

pub fn init(): void {
    if !trap_frame.verify_layout() {
        println("exception: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_trap_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("exception: extern c abi probe failed");
        panic_mod.panic();
    }
    println("exception: vectors ready");
}

export c("cory_arch_trap_entry") fn cory_arch_trap_entry(raw_frame: *TrapFrame): void {
    const frame = trap_frame.diagnostic_from_frame(raw_frame);
    println("exception: unhandled riscv64");
    println("exception: scause");
    console.println_hex(frame.scause);
    println("exception: sepc");
    console.println_hex(frame.sepc);
    println("exception: stval");
    console.println_hex(frame.stval);
    println("exception: sstatus");
    console.println_hex(frame.sstatus);
    panic_mod.panic();
}
