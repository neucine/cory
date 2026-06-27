import .kernel.arch.aarch64.trap_frame;
import .kernel.panic as panic_mod;

extern c {
    fn cycor_arch_exception_init(): void = "cycor_arch_exception_init";
    fn cycor_arch_abi_probe_value(): c_ulong = "cycor_arch_abi_probe_value";
    fn cycor_arch_current_el(): c_ulong = "cycor_arch_current_el";
}

pub fn init(): void {
    if cycor_arch_current_el() != 1 {
        println("exception: expected EL1");
        panic_mod.panic();
    }
    cycor_arch_exception_init();
    if cycor_arch_abi_probe_value() != 12648430 {
        println("exception: extern c abi probe failed");
        panic_mod.panic();
    }
    println("exception: vectors ready");
}

export c fn cycor_arch_exception_entry(esr: c_ulong, elr: c_ulong, far: c_ulong, spsr: c_ulong): void = "cycor_arch_exception_entry" {
    const frame = trap_frame.diagnostic(esr, elr, far, spsr);
    println("exception: unhandled aarch64");
    println("exception: esr_el1");
    println(frame.esr_el1);
    println("exception: elr_el1");
    println(frame.elr_el1);
    println("exception: far_el1");
    println(frame.far_el1);
    println("exception: spsr_el1");
    println(frame.spsr_el1);
    panic_mod.panic();
}
