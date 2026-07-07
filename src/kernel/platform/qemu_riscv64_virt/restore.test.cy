import .kernel.arch.riscv64.trap_context;
import .kernel.arch.riscv64.trap_frame;
import { TrapFrame } from .kernel.arch.riscv64.trap_frame;
import .kernel.entry;
import .kernel.kernel;
import .kernel.panic as panic_mod;
import .kernel.platform.qemu_riscv64_virt.console;

extern c("cory_arch_trap_init") fn cory_arch_trap_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;
extern c("cory_arch_trigger_test_trap") fn cory_arch_trigger_test_trap(): void;

pub fn init(): void {
    if !trap_frame.verify_layout() {
        println("restoretest: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_trap_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("restoretest: extern c abi probe failed");
        panic_mod.panic();
    }
    println("restoretest: vectors ready");
}

export c("cory_arch_trap_entry") fn cory_arch_trap_entry(raw_frame: *TrapFrame): void {
    println("restoretest: trap riscv64");
    trap_frame.set_resume_state_in_frame(
        raw_frame,
        trap_frame.explicit_resume_ip_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    trap_context.restore_from_frame(raw_frame);
    println("restoretest: restore returned unexpectedly");
    panic_mod.panic();
}

export c("cory_kernel_entry") fn cory_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    init();
    println("restoretest: trigger riscv64");
    cory_arch_trigger_test_trap();
    println("restoretest: resumed riscv64");
    panic_mod.panic();
}
