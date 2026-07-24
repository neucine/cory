extern c("cory_user_process_list") fn process_list(): c_ulong;
extern c("cory_user_exit") fn exit(code: c_ulong): void;

export c("cory_user_main") fn cory_user_main(): void {
    const listed = process_list();
    exit(0);
}

fn main(): i32 {
    return 0;
}
