import .hal.console;
import .panic as panic_mod;

pub fn kernel_start(): void {
    console.console_init();
    console.write_line("cycor: kernel entry".bytes());
    panic_mod.halt();
}
