import .kernel.arch.aarch64.trap_frame;
import { TrapFrame } from .kernel.arch.aarch64.trap_frame;
import .kernel.console;
import .kernel.panic as panic_mod;

extern c("cory_arch_exception_init") fn cory_arch_exception_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;
extern c("cory_arch_current_el") fn cory_arch_current_el(): c_ulong;

pub fn init(): void {
    if cory_arch_current_el() != 1 {
        println("exception: expected EL1");
        panic_mod.panic();
    }
    if !trap_frame.verify_layout() {
        println("exception: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_exception_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("exception: extern c abi probe failed");
        panic_mod.panic();
    }
    println("exception: vectors ready");
}

export c("cory_arch_exception_entry") fn cory_arch_exception_entry(raw_frame: *TrapFrame): void {
    trap_frame.set_resume_state_in_frame(
        raw_frame,
        trap_frame.instruction_pointer_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    const frame = trap_frame.diagnostic_from_frame(raw_frame);
    if trap_frame.instruction_pointer_from_frame(raw_frame) != frame.elr_el1 {
        println("exception: aarch64 resume ip mismatch");
        panic_mod.panic();
    }
    if trap_frame.status_flags_from_frame(raw_frame) != frame.spsr_el1 {
        println("exception: aarch64 resume flags mismatch");
        panic_mod.panic();
    }
    println("exception: unhandled aarch64");
    println("exception: esr_el1");
    console.println_hex(frame.esr_el1);
    println("exception: elr_el1");
    console.println_hex(frame.elr_el1);
    println("exception: far_el1");
    console.println_hex(frame.far_el1);
    println("exception: spsr_el1");
    console.println_hex(frame.spsr_el1);
    panic_mod.panic();
}
