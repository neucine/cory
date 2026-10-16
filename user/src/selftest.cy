import .syscall;

c struct Message {
    bytes: [31]u8;
}

export c("cory_user_main") fn cory_user_main(): void {
    var message = new Message {
        bytes: [
            'u', 's', 'e', 'r', 's', 'p', 'a', 'c',
            'e', ':', ' ', 'c', 'y', ' ', 's', 'e',
            'l', 'f', 't', 'e', 's', 't', ' ', 'r',
            'a', 'n', ' ', 'o', 'k', '\n', 0,
        ],
    };
    const written = syscall.debug_write(message.ptr() as! *c_uchar, 30);
    syscall.exit(7);
}

fn main(): i32 {
    return 0;
}
