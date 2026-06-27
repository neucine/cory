import .kernel.panic as panic_mod;

extern c {
    fn cycor_arch_exception_init(): void = "cycor_arch_exception_init";
    fn cycor_arch_abi_probe_value(): c_ulong = "cycor_arch_abi_probe_value";
}

pub fn init(): void {
    cycor_arch_exception_init();
    if cycor_arch_abi_probe_value() != 12648430 {
        println("exception: extern c abi probe failed");
        panic_mod.panic();
    }
    println("exception: vectors ready");
}

export c fn cycor_arch_exception_entry(): void = "cycor_arch_exception_entry" {
    println("exception: unhandled");
    panic_mod.panic();
}
