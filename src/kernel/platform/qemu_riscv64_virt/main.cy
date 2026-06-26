import .kernel.entry;
import .kernel.boot;
import .kernel.kernel;
import .kernel.platform.qemu_riscv64_virt.console;
import .kernel.platform.qemu_riscv64_virt.exception;
import .kernel.platform.qemu_riscv64_virt.memory;

export c fn cycor_kernel_entry(): void = "cycor_kernel_entry" {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    exception.init();
    boot.run(memory.layout());
}
