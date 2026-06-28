import std.io;

extern c("cycor_console_putc") fn platform_putc(ch: c_uchar): void;

pub fn init(): void {
    io.install_writer(write, none);
}

pub fn putc(ch: u8): void {
    platform_putc(ch as c_uchar);
}

fn hex_digit(nibble: usize): u8 {
    if nibble < 10 {
        return (48 + nibble) as u8;
    }
    return (87 + nibble) as u8;
}

pub fn print_hex(value: usize): void {
    putc(48);
    putc(120);

    // Keep this freestanding helper on simple arithmetic. It is used by trap
    // diagnostics before the kernel has a richer formatting layer.
    var place: usize = 1152921504606846976;
    while place > 0 {
        putc(hex_digit((value / place) & 15));
        place = place / 16;
    }
}

pub fn println_hex(value: usize): void {
    print_hex(value);
    putc(10);
}

export c fn write(ptr: *c_char, len: c_llong, ctx: ?*c_void): void {
    unchecked {
        var addr: usize = ptr as! usize;
        const end: usize = addr + (len as usize);
        while addr < end {
            const ch: u8 = *(addr as! *u8);
            putc(ch);
            addr = addr + 1;
        }
    }
}
