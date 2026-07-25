import .syscall;

cstruct Buffer {
    bytes: [128]u8;
}

cstruct PathBuffer {
    bytes: [64]u8;
}

cstruct NotFoundMessage {
    bytes: [15]u8;
}

fn write_not_found(): void {
    var message = new NotFoundMessage {
        bytes: [
            'l', 's', ':', ' ', 'n', 'o', 't', ' ',
            'f', 'o', 'u', 'n', 'd', '\n', 0,
        ],
    };
    const written = syscall.console_write(message.ptr() as! *c_uchar, 14);
}

export c("cory_user_main") fn cory_user_main(): void {
    var path = new PathBuffer {
        bytes: [0] ** 64,
    };
    var path_len = syscall.process_arg_read(path.ptr() as! *c_uchar, 64);
    if path_len == 0 {
        path.bytes[0] = '/';
        path_len = 1;
    }
    const fd = syscall.fs_open(path.ptr() as! *c_uchar, path_len);
    if fd == 0 {
        write_not_found();
        syscall.exit(1);
    }
    var buffer = new Buffer {
        bytes: [0] ** 128,
    };
    const read_len = syscall.fs_fd_read(fd, buffer.ptr() as! *c_uchar, 128);
    const close_status = syscall.fs_close(fd);
    if read_len != 0 {
        const written = syscall.console_write(buffer.ptr() as! *c_uchar, read_len);
    } else {
        write_not_found();
        syscall.exit(1);
    }
    syscall.exit(0);
}

fn main(): i32 {
    return 0;
}
