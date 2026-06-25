import .hal.qemu_aarch64_virt.uart;
import std.io;

pub fn init(): void {
    io.install_writer(cycor_console_writer_write, none);
}

pub fn putc(ch: u8): void {
    uart.tx(ch);
}

export c fn cycor_console_writer_write(ptr: *c_char, len: c_llong, ctx: ?*c_void): void = "cycor_console_writer_write" {
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
