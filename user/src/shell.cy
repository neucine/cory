extern c("cory_user_console_read") fn console_read(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_console_write") fn console_write(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_program_inspect") fn program_inspect(program_id: c_ulong): c_ulong;
extern c("cory_user_process_spawn") fn process_spawn(program_id: c_ulong, arg_ptr: *c_uchar, arg_len: c_ulong): c_ulong;
extern c("cory_user_process_wait") fn process_wait(process_id: c_ulong, reap: c_ulong): c_ulong;
extern c("cory_user_exit") fn exit(code: c_ulong): void;

cstruct Buffer {
    bytes: [64]u8;
}

cstruct NewlineMessage {
    bytes: [2]u8;
}

cstruct HelpMessage {
    bytes: [39]u8;
}

cstruct ExitMessage {
    bytes: [13]u8;
}

cstruct UnknownMessage {
    bytes: [24]u8;
}

fn write_prompt(buffer: *Buffer): void {
    unchecked {
        (*buffer).bytes[0] = 99;
        (*buffer).bytes[1] = 111;
        (*buffer).bytes[2] = 114;
        (*buffer).bytes[3] = 121;
        (*buffer).bytes[4] = 62;
        (*buffer).bytes[5] = 32;
    }
    const written = console_write(buffer as! *c_uchar, 6);
}

fn write_newline(): void {
    var message = new NewlineMessage {
        bytes: [10, 0],
    };
    const written = console_write(message.ptr() as! *c_uchar, 1);
}

fn write_help(): void {
    var message = new HelpMessage {
        bytes: [
            's', 'h', 'e', 'l', 'l', ':', ' ', 'c',
            'o', 'm', 'm', 'a', 'n', 'd', 's', ':',
            ' ', 'h', 'e', 'l', 'p', ',', ' ', 'e',
            'c', 'h', 'o', ',', ' ', 'p', 's', ',',
            ' ', 'e', 'x', 'i', 't', '\n', 0,
        ],
    };
    const written = console_write(message.ptr() as! *c_uchar, 38);
}

fn write_exit(): void {
    var message = new ExitMessage {
        bytes: ['s', 'h', 'e', 'l', 'l', ':', ' ', 'e', 'x', 'i', 't', '\n', 0],
    };
    const written = console_write(message.ptr() as! *c_uchar, 12);
}

fn write_unknown(): void {
    var message = new UnknownMessage {
        bytes: [
            's', 'h', 'e', 'l', 'l', ':', ' ', 'u',
            'n', 'k', 'n', 'o', 'w', 'n', ' ', 'c',
            'o', 'm', 'm', 'a', 'n', 'd', '\n', 0,
        ],
    };
    const written = console_write(message.ptr() as! *c_uchar, 23);
}

fn trimmed_len(buffer: &Buffer, len: usize): usize {
    var index: usize = 0;
    while index < len {
        if buffer.bytes[index] == 10 {
            return index;
        }
        index = index + 1;
    }
    return len;
}

fn is_help(buffer: &Buffer, len: usize): bool {
    if len != 4 {
        return false;
    }
    return buffer.bytes[0] == 104 and buffer.bytes[1] == 101 and buffer.bytes[2] == 108 and buffer.bytes[3] == 112;
}

fn is_exit(buffer: &Buffer, len: usize): bool {
    if len != 4 {
        return false;
    }
    return buffer.bytes[0] == 101 and buffer.bytes[1] == 120 and buffer.bytes[2] == 105 and buffer.bytes[3] == 116;
}

fn is_ps(buffer: &Buffer, len: usize): bool {
    if len != 2 {
        return false;
    }
    return buffer.bytes[0] == 112 and buffer.bytes[1] == 115;
}

fn is_echo(buffer: &Buffer, len: usize): bool {
    if len < 5 {
        return false;
    }
    return buffer.bytes[0] == 101 and buffer.bytes[1] == 99 and buffer.bytes[2] == 104 and buffer.bytes[3] == 111 and buffer.bytes[4] == 32;
}

fn run_program(program_id: c_ulong, arg_ptr: *c_uchar, arg_len: usize): void {
    const inspected = program_inspect(program_id);
    const process_id = process_spawn(program_id, arg_ptr, arg_len as c_ulong);
    const status = process_wait(process_id, 1);
}

fn run_echo(buffer_ptr: *c_uchar, len: usize): void {
    unchecked {
        const arg_ptr = ((buffer_ptr as! usize) + 5) as! *c_uchar;
        run_program(3, arg_ptr, len - 5);
    }
}

fn run_ps(): void {
    run_program(4, 0 as! *c_uchar, 0);
}

export c("cory_user_main") fn cory_user_main(): void {
    var buffer = new Buffer {
        bytes: [0] ** 64,
    };
    var read_len: usize = 0;
    var command_len: usize = 0;
    var echoed: c_ulong = 0;
    while true {
        write_prompt(buffer.ptr() as! *Buffer);
        read_len = console_read(buffer.ptr() as! *c_uchar, 64) as usize;
        command_len = trimmed_len(buffer, read_len);
        echoed = console_write(buffer.ptr() as! *c_uchar, command_len as c_ulong);
        write_newline();
        if is_help(buffer, command_len) {
            write_help();
        } else if is_exit(buffer, command_len) {
            write_exit();
            exit(0);
        } else if is_ps(buffer, command_len) {
            run_ps();
        } else if is_echo(buffer, command_len) {
            run_echo(buffer.ptr() as! *c_uchar, command_len);
        } else {
            write_unknown();
        }
    }
}

fn main(): i32 {
    return 0;
}
