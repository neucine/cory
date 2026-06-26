import .kernel.panic as panic_mod;

extern c {
    fn cycor_arch_trap_init(): void = "cycor_arch_trap_init";
}

pub fn init(): void {
    cycor_arch_trap_init();
    println("exception: vectors ready");
}

export c fn cycor_arch_trap_entry(): void = "cycor_arch_trap_entry" {
    println("exception: unhandled");
    panic_mod.panic();
}
