extern c("cory_user_console_write") fn console_write(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_process_arg_read") fn process_arg_read(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_exit") fn exit(code: c_ulong): void;

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
    const read_len = process_arg_read(buffer.ptr() as! *c_uchar, 64);
    if read_len != 0 {
        const written = console_write(buffer.ptr() as! *c_uchar, read_len);
    }
    var newline = new NewlineMessage {
        bytes: ['\n', 0],
    };
    const newline_written = console_write(newline.ptr() as! *c_uchar, 1);
    exit(0);
}

fn main(): i32 {
    return 0;
}
