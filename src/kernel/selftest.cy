import .kernel.memory.boot;
import { Layout } from .kernel.memory.layout;
import .kernel.panic as panic_mod;

fn require(value: bool): void {
    if !value {
        panic_mod.panic();
    }
}

pub fn run_boot_tests(map: Layout): void {
    require(map.ram_start < map.ram_end);
    require(map.kernel_load >= map.ram_start);
    require(map.kernel_load < map.ram_end);
    require(map.page_size != 0);

    const before = boot.snapshot();
    require(before.start >= map.kernel_load);
    require(before.start < before.end);
    require(before.next == before.start);

    const first = boot.reserve(64, 16);
    require(first != 0);
    const second = boot.reserve(map.page_size, map.page_size);
    require(second != 0);

    require(first >= before.start);
    require(second >= first + 64);
    require((second & (map.page_size - 1)) == 0);
}
