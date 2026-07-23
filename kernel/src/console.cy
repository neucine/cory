import std.io;

extern c("cory_console_putc") fn platform_putc(ch: c_uchar): void;
extern c("cory_console_try_getc") fn platform_try_getc(): c_ulong;

pub const no_input: usize = 256;
pub const newline: usize = 10;
pub const help_exit_script_len: usize = 10;
const input_capacity: usize = 64;

const ascii_h: usize = 104;
const ascii_e: usize = 101;
const ascii_l: usize = 108;
const ascii_p: usize = 112;
const ascii_x: usize = 120;
const ascii_i: usize = 105;
const ascii_t: usize = 116;

var scripted_cursor: usize = 0;
var scripted_input_enabled: bool = false;
var input_buffer: [64]usize = [0] ** 64;
var input_head: usize = 0;
var input_tail: usize = 0;
var input_count: usize = 0;

pub fn init(): void {
    io.install_writer(write, none);
    input_head = 0;
    input_tail = 0;
    input_count = 0;
    scripted_cursor = 0;
    scripted_input_enabled = false;
}

pub fn putc(ch: u8): void {
    platform_putc(ch as c_uchar);
}

pub fn push_input_byte(ch: u8): bool {
    if input_count >= input_capacity {
        return false;
    }
    input_buffer[input_tail] = ch as usize;
    input_tail = (input_tail + 1) % input_capacity;
    input_count = input_count + 1;
    return true;
}

pub fn seed_help_exit_input(): void {
    scripted_cursor = 0;
    scripted_input_enabled = true;
}

fn scripted_help_exit_byte(index: usize): usize {
    if index == 0 {
        return ascii_h;
    }
    if index == 1 {
        return ascii_e;
    }
    if index == 2 {
        return ascii_l;
    }
    if index == 3 {
        return ascii_p;
    }
    if index == 4 {
        return newline;
    }
    if index == 5 {
        return ascii_e;
    }
    if index == 6 {
        return ascii_x;
    }
    if index == 7 {
        return ascii_i;
    }
    if index == 8 {
        return ascii_t;
    }
    if index == 9 {
        return newline;
    }
    return no_input;
}

pub fn read_byte(): usize {
    if scripted_input_enabled and scripted_cursor < help_exit_script_len {
        const ch = scripted_help_exit_byte(scripted_cursor);
        scripted_cursor = scripted_cursor + 1;
        if scripted_cursor >= help_exit_script_len {
            scripted_input_enabled = false;
        }
        return ch;
    }
    if input_count == 0 {
        const platform_ch = platform_try_getc();
        if (platform_ch as usize) == no_input {
            return no_input;
        }
        return platform_ch as usize;
    }
    const ch = input_buffer[input_head];
    input_head = (input_head + 1) % input_capacity;
    input_count = input_count - 1;
    return ch;
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
