import .kernel.console;
import .kernel.platform.qemu_riscv64_virt.uart;

pub fn init(): void {
    console.init();
}

export c fn cycor_console_putc(ch: c_uchar): void = "cycor_console_putc" {
    uart.tx(ch as u8);
}
