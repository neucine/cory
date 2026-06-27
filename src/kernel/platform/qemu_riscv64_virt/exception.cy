import .kernel.arch.riscv64.trap_frame;
import .kernel.panic as panic_mod;

extern c {
    fn cycor_arch_trap_init(): void = "cycor_arch_trap_init";
    fn cycor_arch_abi_probe_value(): c_ulong = "cycor_arch_abi_probe_value";
}

pub fn init(): void {
    cycor_arch_trap_init();
    if cycor_arch_abi_probe_value() != 12648430 {
        println("exception: extern c abi probe failed");
        panic_mod.panic();
    }
    println("exception: vectors ready");
}

export c fn cycor_arch_trap_entry(scause: c_ulong, sepc: c_ulong, stval: c_ulong, sstatus: c_ulong): void = "cycor_arch_trap_entry" {
    const frame = trap_frame.diagnostic(scause, sepc, stval, sstatus);
    println("exception: unhandled riscv64");
    println("exception: scause");
    println(frame.scause);
    println("exception: sepc");
    println(frame.sepc);
    println("exception: stval");
    println(frame.stval);
    println("exception: sstatus");
    println(frame.sstatus);
    panic_mod.panic();
}
