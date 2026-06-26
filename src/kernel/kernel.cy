import .kernel.panic as panic_mod;

pub fn print_entry(): void {
    println("cycor: kernel entry");
}

pub fn print_memory_ready(): void {
    println("memory: physical pages ready");
}

pub fn halt(): void {
    panic_mod.halt();
}
