import .kernel.entry;
import .kernel.kernel;
import .kernel.platform.qemu_aarch64_virt.console;
import .kernel.platform.qemu_aarch64_virt.exception;

extern c("cycor_arch_trigger_test_trap") fn cycor_arch_trigger_test_trap(): void;

export c("cycor_kernel_entry") fn cycor_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    exception.init();
    println("traptest: trigger aarch64");
    cycor_arch_trigger_test_trap();
    println("traptest: returned unexpectedly");
}
