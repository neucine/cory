import .kernel.kernel;
import { Layout } from .kernel.memory.layout;
import .kernel.memory.boot as boot_memory;
import .kernel.memory.phys;
import .kernel.panic as panic_mod;
import .kernel.selftest;

pub fn run(map: Layout): void {
    boot_memory.init(map.ram_end, map.page_size);
    selftest.run_boot_tests(map);
    if !phys.init(map) {
        panic_mod.panic();
    }
    selftest.run_phys_tests(map);
    kernel.print_memory_ready();
    kernel.halt();
}
