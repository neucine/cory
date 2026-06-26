import { Layout } from .kernel.memory.layout;

pub const ram_start: usize = 0x80000000;
pub const ram_size: usize = 0x08000000;
pub const ram_end: usize = ram_start + ram_size;

pub const kernel_load: usize = 0x80000000;
pub const page_size: usize = 4096;

pub fn layout(): Layout {
    return Layout {
        ram_start: ram_start,
        ram_end: ram_end,
        kernel_load: kernel_load,
        page_size: page_size,
    };
}
