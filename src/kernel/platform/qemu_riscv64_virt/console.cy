import .kernel.console;
import .kernel.platform.qemu_riscv64_virt.uart;

pub fn init(): void {
    console.init();
}

export c("cory_console_putc") fn cory_console_putc(ch: c_uchar): void {
    uart.tx(ch as u8);
}
