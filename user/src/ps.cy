import .syscall;

export c("cory_user_main") fn cory_user_main(): void {
    const listed = syscall.process_list();
    syscall.exit(0);
}

fn main(): i32 {
    return 0;
}
