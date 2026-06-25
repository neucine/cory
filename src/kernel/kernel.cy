import .hal.console;
import .panic as panic_mod;

pub fn kernel_start(): void {
    console.console_init();
    println("cycor: kernel entry");
    panic_mod.halt();
}
