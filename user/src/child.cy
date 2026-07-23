extern c("cory_user_debug_write") fn debug_write(ptr: *c_uchar, len: c_ulong): c_ulong;
extern c("cory_user_exit") fn exit(code: c_ulong): void;

cstruct Message {
    bytes: [28]u8;
}

export c("cory_user_main") fn cory_user_main(): void {
    var message = new Message {
        bytes: [
            117, 115, 101, 114, 115, 112, 97, 99,
            101, 58, 32, 99, 121, 32, 99, 104,
            105, 108, 100, 32, 114, 97, 110, 32,
            111, 107, 10, 0,
        ],
    };
    const written = debug_write(message.ptr() as! *c_uchar, 27);
    exit(7);
}

fn main(): i32 {
    return 0;
}
