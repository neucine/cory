import .kernel.kernel;
import { Layout } from .kernel.memory.layout;
import .kernel.memory.boot as boot_memory;
import .kernel.selftest;

pub fn run(map: Layout): void {
    boot_memory.init(map.ram_end, map.page_size);
    selftest.run_boot_tests(map);
    kernel.print_memory_ready();
    kernel.halt();
}
