import .syscall;

cstruct Buffer {
    bytes: [65]u8;
}

cstruct NewlineMessage {
    bytes: [2]u8;
}

export c("cory_user_main") fn cory_user_main(): void {
    var buffer = new Buffer {
        bytes: [0] ** 65,
    };
    const read_len = syscall.process_arg_read(buffer.ptr() as! *c_uchar, 64);
    if read_len != 0 {
        const written = syscall.console_write(buffer.ptr() as! *c_uchar, read_len);
    }
    var newline = new NewlineMessage {
        bytes: ['\n', 0],
    };
    const newline_written = syscall.console_write(newline.ptr() as! *c_uchar, 1);
    syscall.exit(0);
}

fn main(): i32 {
    return 0;
}
