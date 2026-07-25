extern c("cory_user_yield") fn raw_yield(): c_ulong;
extern c("cory_user_debug_write") fn raw_debug_write(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_console_read") fn raw_console_read(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_console_write") fn raw_console_write(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_process_list") fn raw_process_list(): c_ulong;
extern c("cory_user_process_current") fn raw_process_current(): c_ulong;
extern c("cory_user_process_spawn_path") fn raw_process_spawn_path(path_ptr: *c_uchar, path_len: c_ulong, arg_ptr: *c_uchar, arg_len: c_ulong): c_ulong;
extern c("cory_user_process_wait") fn raw_process_wait(process_id: c_ulong, reap: c_ulong): c_ulong;
extern c("cory_user_process_arg_read") fn raw_process_arg_read(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_fs_list") fn raw_fs_list(path_ptr: *c_uchar, path_len: c_ulong, out_ptr: *c_uchar): c_ulong;
extern c("cory_user_fs_read") fn raw_fs_read(path_ptr: *c_uchar, path_len: c_ulong, out_ptr: *c_uchar): c_ulong;
extern c("cory_user_fs_open") fn raw_fs_open(path_ptr: *c_uchar, path_len: c_ulong): c_ulong;
extern c("cory_user_fs_fd_read") fn raw_fs_fd_read(fd: c_ulong, out_ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_fs_close") fn raw_fs_close(fd: c_ulong): c_ulong;
extern c("cory_user_exit") fn raw_exit(code: c_ulong): void;

pub fn yield_current(): c_ulong {
    return raw_yield();
}

pub fn debug_write(ptr: *c_uchar, len: c_ulong): c_ulong {
    return raw_debug_write(ptr, len);
}

pub fn console_read(ptr: *c_uchar, len: c_ulong): c_ulong {
    return raw_console_read(ptr, len);
}

pub fn console_write(ptr: *c_uchar, len: c_ulong): c_ulong {
    return raw_console_write(ptr, len);
}

pub fn process_list(): c_ulong {
    return raw_process_list();
}

pub fn process_current(): c_ulong {
    return raw_process_current();
}

pub fn process_spawn_path(path_ptr: *c_uchar, path_len: c_ulong, arg_ptr: *c_uchar, arg_len: c_ulong): c_ulong {
    return raw_process_spawn_path(path_ptr, path_len, arg_ptr, arg_len);
}

pub fn process_wait(process_id: c_ulong, reap: c_ulong): c_ulong {
    return raw_process_wait(process_id, reap);
}

pub fn process_arg_read(ptr: *c_uchar, len: c_ulong): c_ulong {
    return raw_process_arg_read(ptr, len);
}

pub fn fs_list(path_ptr: *c_uchar, path_len: c_ulong, out_ptr: *c_uchar): c_ulong {
    return raw_fs_list(path_ptr, path_len, out_ptr);
}

pub fn fs_read(path_ptr: *c_uchar, path_len: c_ulong, out_ptr: *c_uchar): c_ulong {
    return raw_fs_read(path_ptr, path_len, out_ptr);
}

pub fn fs_open(path_ptr: *c_uchar, path_len: c_ulong): c_ulong {
    return raw_fs_open(path_ptr, path_len);
}

pub fn fs_fd_read(fd: c_ulong, out_ptr: *c_uchar, len: c_ulong): c_ulong {
    return raw_fs_fd_read(fd, out_ptr, len);
}

pub fn fs_close(fd: c_ulong): c_ulong {
    return raw_fs_close(fd);
}

pub fn exit(code: c_ulong): void {
    raw_exit(code);
}
