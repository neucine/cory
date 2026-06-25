import .hal.qemu_aarch64_virt.uart;

pub fn console_init(): void {
}

pub fn putc(ch: u8): void {
    uart.tx(ch);
}

pub fn puts(text: []const u8): void {
    for ch in text {
        putc(ch);
    }
}

pub fn write_line(text: []const u8): void {
    puts(text);
    putc(10);
}
