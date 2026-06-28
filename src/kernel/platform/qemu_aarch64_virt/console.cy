import .kernel.console;
import .kernel.platform.qemu_aarch64_virt.uart;

pub fn init(): void {
    console.init();
}

export c("cycor_console_putc") fn cycor_console_putc(ch: c_uchar): void {
    uart.tx(ch as u8);
}
