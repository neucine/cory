import .syscall;

cstruct Buffer {
    bytes: [64]u8;
}

cstruct ProgramPath {
    bytes: [21]u8;
}

cstruct ArgumentBuffer {
    bytes: [64]u8;
}

cstruct NewlineMessage {
    bytes: [2]u8;
}

cstruct HelpMessage {
    bytes: [58]u8;
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
    const written = syscall.console_write(buffer as! *c_uchar, 6);
}

fn write_newline(): void {
    var message = new NewlineMessage {
        bytes: [10, 0],
    };
    const written = syscall.console_write(message.ptr() as! *c_uchar, 1);
}

fn write_help(): void {
    var message = new HelpMessage {
        bytes: [
            's', 'h', 'e', 'l', 'l', ':', ' ', 'c',
            'o', 'm', 'm', 'a', 'n', 'd', 's', ':',
            ' ', 'h', 'e', 'l', 'p', ',', ' ', 'c',
            'a', 't', ',', ' ', 'e', 'c', 'h', 'o',
            ',', ' ', 'l', 's', ',', ' ', 'p', 's',
            ',', ' ', 's', 'e', 'l', 'f', 't', 'e',
            's', 't', ',', ' ', 'e', 'x', 'i', 't',
            '\n', 0,
        ],
    };
    const written = syscall.console_write(message.ptr() as! *c_uchar, 57);
}

fn write_exit(): void {
    var message = new ExitMessage {
        bytes: ['s', 'h', 'e', 'l', 'l', ':', ' ', 'e', 'x', 'i', 't', '\n', 0],
    };
    const written = syscall.console_write(message.ptr() as! *c_uchar, 12);
}

fn write_unknown(): void {
    var message = new UnknownMessage {
        bytes: [
            's', 'h', 'e', 'l', 'l', ':', ' ', 'u',
            'n', 'k', 'n', 'o', 'w', 'n', ' ', 'c',
            'o', 'm', 'm', 'a', 'n', 'd', '\n', 0,
        ],
    };
    const written = syscall.console_write(message.ptr() as! *c_uchar, 23);
}

fn trimmed_len(buffer: &Buffer, len: usize): usize {
    var index: usize = 0;
    while index < len {
        if buffer.bytes[index] == 10 or buffer.bytes[index] == 13 {
            return index;
        }
        index = index + 1;
    }
    return len;
}

fn first_token_start(buffer: &Buffer, len: usize): usize {
    var index: usize = 0;
    while index < len {
        if buffer.bytes[index] != 32 {
            return index;
        }
        index = index + 1;
    }
    return len;
}

fn first_token_end(buffer: &Buffer, start: usize, len: usize): usize {
    var index = start;
    while index < len {
        if buffer.bytes[index] == 32 {
            return index;
        }
        index = index + 1;
    }
    return len;
}

fn next_token_start(buffer: &Buffer, start: usize, len: usize): usize {
    var index = start;
    while index < len {
        if buffer.bytes[index] != 32 {
            return index;
        }
        index = index + 1;
    }
    return len;
}

fn token_is_help(buffer: &Buffer, start: usize, len: usize): bool {
    if len != 4 {
        return false;
    }
    return buffer.bytes[start] == 104 and buffer.bytes[start + 1] == 101 and buffer.bytes[start + 2] == 108 and buffer.bytes[start + 3] == 112;
}

fn token_is_exit(buffer: &Buffer, start: usize, len: usize): bool {
    if len != 4 {
        return false;
    }
    return buffer.bytes[start] == 101 and buffer.bytes[start + 1] == 120 and buffer.bytes[start + 2] == 105 and buffer.bytes[start + 3] == 116;
}

fn copy_command_path(buffer: &Buffer, start: usize, len: usize, path: *ProgramPath): void {
    var index: usize = 0;
    while index < 21 {
        unchecked {
            (*path).bytes[index] = 0;
        }
        index = index + 1;
    }
    unchecked {
        (*path).bytes[0] = '/';
        (*path).bytes[1] = 'b';
        (*path).bytes[2] = 'i';
        (*path).bytes[3] = 'n';
        (*path).bytes[4] = '/';
    }
    index = 0;
    while index < len {
        unchecked {
            (*path).bytes[index + 5] = buffer.bytes[start + index];
        }
        index = index + 1;
    }
}

fn copy_argument(buffer: &Buffer, start: usize, len: usize, arg: *ArgumentBuffer): void {
    var index: usize = 0;
    while index < 64 {
        unchecked {
            (*arg).bytes[index] = 0;
        }
        index = index + 1;
    }
    index = 0;
    while index < len {
        unchecked {
            (*arg).bytes[index] = buffer.bytes[start + index];
        }
        index = index + 1;
    }
}

fn run_path(path: *ProgramPath, path_len: usize, arg_ptr: *c_uchar, arg_len: usize): bool {
    const process_id = syscall.process_spawn_path(path as! *c_uchar, path_len as c_ulong, arg_ptr, arg_len as c_ulong);
    if process_id == 0 {
        return false;
    }
    const status = syscall.process_wait(process_id, 1);
    return true;
}

fn run_command(buffer: &Buffer, len: usize): bool {
    const name_start = first_token_start(buffer, len);
    if name_start >= len {
        return false;
    }
    const name_end = first_token_end(buffer, name_start, len);
    const name_len = name_end - name_start;
    if name_len > 16 {
        return false;
    }
    var path = new ProgramPath {
        bytes: [0] ** 21,
    };
    copy_command_path(buffer, name_start, name_len, path.ptr() as! *ProgramPath);
    const path_len = name_len + 5;
    const arg_start = next_token_start(buffer, name_end, len);
    if arg_start < len {
        const arg_len = len - arg_start;
        var arg = new ArgumentBuffer {
            bytes: [0] ** 64,
        };
        copy_argument(buffer, arg_start, arg_len, arg.ptr() as! *ArgumentBuffer);
        return run_path(path.ptr() as! *ProgramPath, path_len, arg.ptr() as! *c_uchar, arg_len);
    }
    return run_path(path.ptr() as! *ProgramPath, path_len, 0 as! *c_uchar, 0);
}

export c("cory_user_main") fn cory_user_main(): void {
    var buffer = new Buffer {
        bytes: [0] ** 64,
    };
    var read_len: usize = 0;
    var command_len: usize = 0;
    var name_start: usize = 0;
    var name_end: usize = 0;
    var name_len: usize = 0;
    while true {
        write_prompt(buffer.ptr() as! *Buffer);
        read_len = syscall.console_read(buffer.ptr() as! *c_uchar, 64) as usize;
        command_len = trimmed_len(buffer, read_len);
        name_start = first_token_start(buffer, command_len);
        name_end = first_token_end(buffer, name_start, command_len);
        name_len = name_end - name_start;
        if token_is_help(buffer, name_start, name_len) {
            write_help();
        } else if token_is_exit(buffer, name_start, name_len) {
            write_exit();
            syscall.exit(0);
        } else if run_command(buffer, command_len) {
        } else {
            write_unknown();
        }
    }
}

fn main(): i32 {
    return 0;
}
