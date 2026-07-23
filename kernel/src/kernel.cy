import .panic as panic_mod;
import .syscall;
import .user_image_abi;

pub fn print_entry(): void {
    println("cory: kernel entry");
}

pub fn print_memory_ready(): void {
    println("memory: physical pages ready");
}

pub fn halt(): void {
    panic_mod.halt();
}
