import .syscall;

c struct DebugMessage {
    bytes: [34]u8;
}

c struct CurrentMessage {
    bytes: [33]u8;
}

c struct SelftestWaitMessage {
    bytes: [39]u8;
}

c struct ShellWaitMessage {
    bytes: [36]u8;
}

c struct SelftestPath {
    bytes: [14]u8;
}

c struct ShellPath {
    bytes: [11]u8;
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
    const written = syscall.debug_write(message.ptr() as! *c_uchar, 33);
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
    const written = syscall.debug_write(message.ptr() as! *c_uchar, 32);
}

fn write_selftest_wait_message(): void {
    var message = new SelftestWaitMessage {
        bytes: [
            'u', 's', 'e', 'r', 's', 'p', 'a', 'c',
            'e', ':', ' ', 's', 'e', 'l', 'f', 't',
            'e', 's', 't', ' ', 'w', 'a', 'i', 't',
            ' ', 'o', 'k', ' ', 'f', 'r', 'o', 'm',
            ' ', 'i', 'n', 'i', 't', '\n', 0,
        ],
    };
    const written = syscall.debug_write(message.ptr() as! *c_uchar, 38);
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
    const written = syscall.debug_write(message.ptr() as! *c_uchar, 35);
}

fn run_path(path_ptr: *c_uchar, path_len: c_ulong): c_ulong {
    const process_id = syscall.process_spawn_path(path_ptr, path_len, 0 as! *c_uchar, 0);
    const exit_code = syscall.process_wait(process_id, 1);
    return exit_code;
}

fn run_selftest(): c_ulong {
    var path = new SelftestPath {
        bytes: ['/', 'b', 'i', 'n', '/', 's', 'e', 'l', 'f', 't', 'e', 's', 't', 0],
    };
    return run_path(path.ptr() as! *c_uchar, 13);
}

fn run_shell(): c_ulong {
    var path = new ShellPath {
        bytes: ['/', 'b', 'i', 'n', '/', 's', 'h', 'e', 'l', 'l', 0],
    };
    return run_path(path.ptr() as! *c_uchar, 10);
}

export c("cory_user_main") fn cory_user_main(): void {
    const yield_status = syscall.yield_current();
    write_debug_message();
    const process_id = syscall.process_current();
    write_current_message();

    const selftest_status = run_selftest();
    write_selftest_wait_message();

    const shell_status = run_shell();
    write_shell_wait_message();
    syscall.exit(0);
}

fn main(): i32 {
    return 0;
}
