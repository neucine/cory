import .kernel.panic as panic_mod;

extern c {
    fn cycor_arch_exception_init(): void = "cycor_arch_exception_init";
}

pub fn init(): void {
    cycor_arch_exception_init();
    println("exception: vectors ready");
}

export c fn cycor_arch_exception_entry(): void = "cycor_arch_exception_entry" {
    println("exception: unhandled");
    panic_mod.panic();
}
