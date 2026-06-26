import std.io;

extern c {
    fn platform_putc(ch: c_uchar): void = "cycor_console_putc";
}

pub fn init(): void {
    io.install_writer(write, none);
}

pub fn putc(ch: u8): void {
    platform_putc(ch as c_uchar);
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
