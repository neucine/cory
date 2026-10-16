import .syscall;

c struct PathBuffer {
    bytes: [64]u8;
}

c struct FileBuffer {
    bytes: [128]u8;
}

c struct MissingPathMessage {
    bytes: [24]u8;
}

c struct NotFoundMessage {
    bytes: [16]u8;
}

fn write_missing_path(): void {
    var message = new MissingPathMessage {
        bytes: [
            'c', 'a', 't', ':', ' ', 'm', 'i', 's',
            's', 'i', 'n', 'g', ' ', 'p', 'a', 't',
            'h', '\n', 0, 0, 0, 0, 0, 0,
        ],
    };
    const written = syscall.console_write(message.ptr() as! *c_uchar, 18);
}

fn write_not_found(): void {
    var message = new NotFoundMessage {
        bytes: [
            'c', 'a', 't', ':', ' ', 'n', 'o', 't',
            ' ', 'f', 'o', 'u', 'n', 'd', '\n', 0,
        ],
    };
    const written = syscall.console_write(message.ptr() as! *c_uchar, 15);
}

export c("cory_user_main") fn cory_user_main(): void {
    var path = new PathBuffer {
        bytes: [0] ** 64,
    };
    const path_len = syscall.process_arg_read(path.ptr() as! *c_uchar, 64);
    if path_len == 0 {
        write_missing_path();
        syscall.exit(1);
    }
    const fd = syscall.fs_open(path.ptr() as! *c_uchar, path_len);
    if fd == 0 {
        write_not_found();
        syscall.exit(1);
    }
    var file = new FileBuffer {
        bytes: [0] ** 128,
    };
    const read_len = syscall.fs_fd_read(fd, file.ptr() as! *c_uchar, 128);
    const close_status = syscall.fs_close(fd);
    if read_len == 0 {
        write_not_found();
        syscall.exit(1);
    }
    const written = syscall.console_write(file.ptr() as! *c_uchar, read_len);
    syscall.exit(0);
}

fn main(): i32 {
    return 0;
}
