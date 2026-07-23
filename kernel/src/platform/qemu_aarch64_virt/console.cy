import .console;
import .platform.qemu_aarch64_virt.uart;

pub fn init(): void {
    console.init();
}

pub fn push_input_byte(ch: u8): bool {
    return console.push_input_byte(ch);
}

pub fn seed_help_exit_input(): void {
    console.seed_help_exit_input();
}

export c("cory_console_putc") fn cory_console_putc(ch: c_uchar): void {
    uart.tx(ch as u8);
}

export c("cory_console_try_getc") fn cory_console_try_getc(): c_ulong {
    return uart.try_rx() as c_ulong;
}
