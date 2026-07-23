import { Layout } from .memory.layout;

pub const ram_start: usize = 0x40000000;
pub const ram_size: usize = 0x08000000;
pub const ram_end: usize = ram_start + ram_size;

pub const kernel_load: usize = 0x40080000;
pub const page_size: usize = 4096;
pub const gic_mmio_start: usize = 0x08000000;
pub const gic_mmio_end: usize = 0x08020000;
pub const uart_mmio_start: usize = 0x09000000;
pub const uart_mmio_end: usize = uart_mmio_start + page_size;

pub fn layout(): Layout {
    return Layout {
        ram_start: ram_start,
        ram_end: ram_end,
        kernel_load: kernel_load,
        page_size: page_size,
        device_mmio_start: gic_mmio_start,
        device_mmio_end: gic_mmio_end,
        device_mmio2_start: uart_mmio_start,
        device_mmio2_end: uart_mmio_end,
    };
}
