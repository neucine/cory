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
    println("exception: unhandled riscv64");
    println("exception: scause");
    println(scause as usize);
    println("exception: sepc");
    println(sepc as usize);
    println("exception: stval");
    println(stval as usize);
    println("exception: sstatus");
    println(sstatus as usize);
    panic_mod.panic();
}
