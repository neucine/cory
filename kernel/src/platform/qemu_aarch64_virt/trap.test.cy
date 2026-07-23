import .entry;
import .kernel;
import .platform.qemu_aarch64_virt.console;
import .platform.qemu_aarch64_virt.exception;

extern c("cory_arch_trigger_test_trap") fn cory_arch_trigger_test_trap(): void;

export c("cory_kernel_entry") fn cory_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    exception.init();
    println("traptest: trigger aarch64");
    cory_arch_trigger_test_trap();
    println("traptest: returned unexpectedly");
}
