extern c("cory_user_yield") fn yield_current(): c_ulong;
extern c("cory_user_debug_write") fn debug_write(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_process_current") fn process_current(): c_ulong;
extern c("cory_user_program_inspect") fn program_inspect(program_id: c_ulong): c_ulong;
extern c("cory_user_process_spawn") fn process_spawn(program_id: c_ulong, arg_ptr: *c_uchar, arg_len: c_ulong): c_ulong;
extern c("cory_user_process_wait") fn process_wait(process_id: c_ulong, reap: c_ulong): c_ulong;
extern c("cory_user_exit") fn exit(code: c_ulong): void;

cstruct DebugMessage {
    bytes: [34]u8;
}

cstruct CurrentMessage {
    bytes: [33]u8;
}

cstruct ChildWaitMessage {
    bytes: [36]u8;
}

cstruct ShellWaitMessage {
    bytes: [36]u8;
}

fn write_debug_message(): void {
    var message = new DebugMessage {
        bytes: [
            'u', 's', 'e', 'r', 's', 'p', 'a', 'c',
            'e', ':', ' ', 'd', 'e', 'b', 'u', 'g',
            ' ', 'w', 'r', 'i', 't', 'e', ' ', 'f',
            'r', 'o', 'm', ' ', 'i', 'n', 'i', 't',
            '\n', 0,
        ],
    };
    const written = debug_write(message.ptr() as! *c_uchar, 33);
}

fn write_current_message(): void {
    var message = new CurrentMessage {
        bytes: [
            'u', 's', 'e', 'r', 's', 'p', 'a', 'c',
            'e', ':', ' ', 'c', 'u', 'r', 'r', 'e',
            'n', 't', ' ', 'o', 'k', ' ', 'f', 'r',
            'o', 'm', ' ', 'i', 'n', 'i', 't', '\n',
            0,
        ],
    };
    const written = debug_write(message.ptr() as! *c_uchar, 32);
}

fn write_child_wait_message(): void {
    var message = new ChildWaitMessage {
        bytes: [
            'u', 's', 'e', 'r', 's', 'p', 'a', 'c',
            'e', ':', ' ', 'c', 'h', 'i', 'l', 'd',
            ' ', 'w', 'a', 'i', 't', ' ', 'o', 'k',
            ' ', 'f', 'r', 'o', 'm', ' ', 'i', 'n',
            'i', 't', '\n', 0,
        ],
    };
    const written = debug_write(message.ptr() as! *c_uchar, 35);
}

fn write_shell_wait_message(): void {
    var message = new ShellWaitMessage {
        bytes: [
            'u', 's', 'e', 'r', 's', 'p', 'a', 'c',
            'e', ':', ' ', 's', 'h', 'e', 'l', 'l',
            ' ', 'w', 'a', 'i', 't', ' ', 'o', 'k',
            ' ', 'f', 'r', 'o', 'm', ' ', 'i', 'n',
            'i', 't', '\n', 0,
        ],
    };
    const written = debug_write(message.ptr() as! *c_uchar, 35);
}

fn run_program(program_id: c_ulong): c_ulong {
    const inspected = program_inspect(program_id);
    const process_id = process_spawn(program_id, 0 as! *c_uchar, 0);
    const exit_code = process_wait(process_id, 1);
    return exit_code;
}

export c("cory_user_main") fn cory_user_main(): void {
    const yield_status = yield_current();
    write_debug_message();
    const process_id = process_current();
    write_current_message();

    const child_status = run_program(1);
    write_child_wait_message();

    const shell_status = run_program(2);
    write_shell_wait_message();
    exit(0);
}

fn main(): i32 {
    return 0;
}
