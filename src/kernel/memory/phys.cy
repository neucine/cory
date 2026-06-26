import .kernel.memory.boot;
import { Layout } from .kernel.memory.layout;

pub struct PhysSnapshot {
    pub page_size: usize;
    pub total_pages: usize;
    pub free_pages: usize;
    pub used_pages: usize;
    pub bitmap_start: usize;
    pub bitmap_bytes: usize;
}

var ram_start: usize = 0;
var ram_end: usize = 0;
var page_size: usize = 0;
var page_count: usize = 0;
var free_count: usize = 0;
var bitmap_addr: usize = 0;
var bitmap_len: usize = 0;

fn align_down(value: usize, alignment: usize): usize {
    if alignment == 0 {
        return value;
    }
    return value & (0 - alignment);
}

fn div_round_up(value: usize, divisor: usize): usize {
    if divisor == 0 {
        return 0;
    }
    return (value + divisor - 1) / divisor;
}

fn bitmap_read(byte_index: usize): u8 {
    unchecked {
        const ptr = (bitmap_addr + byte_index) as! *u8;
        return *ptr;
    }
}

fn bitmap_write(byte_index: usize, value: u8): void {
    unchecked {
        const ptr = (bitmap_addr + byte_index) as! *u8;
        *ptr = value;
    }
}

fn bitmap_zero(): void {
    var index: usize = 0;
    while index < bitmap_len {
        bitmap_write(index, 0);
        index = index + 1;
    }
}

fn bit_mask(bit: usize): u8 {
    var value: u8 = 1;
    var index: usize = 0;
    while index < bit {
        value = value * 2;
        index = index + 1;
    }
    return value;
}

fn is_used(index: usize): bool {
    const byte_index = index / 8;
    const bit = index - (byte_index * 8);
    return (bitmap_read(byte_index) & bit_mask(bit)) != 0;
}

fn set_used(index: usize, used: bool): void {
    const byte_index = index / 8;
    const bit = index - (byte_index * 8);
    const mask = bit_mask(bit);
    const current = bitmap_read(byte_index);

    if used {
        if (current & mask) == 0 {
            free_count = free_count - 1;
        }
        bitmap_write(byte_index, current | mask);
    } else {
        if (current & mask) != 0 {
            free_count = free_count + 1;
        }
        bitmap_write(byte_index, current & ((255 as u8) - mask));
    }
}

fn page_addr(index: usize): usize {
    return ram_start + (index * page_size);
}

fn page_index(addr: usize): usize {
    return (addr - ram_start) / page_size;
}

fn mark_range(start: usize, end: usize, used: bool): void {
    if end <= start {
        return;
    }

    var aligned_start = align_down(start, page_size);
    var aligned_end = boot.align_up(end, page_size);

    if aligned_start < ram_start {
        aligned_start = ram_start;
    }
    if aligned_end > ram_end {
        aligned_end = ram_end;
    }
    if aligned_end <= aligned_start {
        return;
    }

    var index = page_index(aligned_start);
    const limit = page_index(aligned_end);
    while index < limit {
        set_used(index, used);
        index = index + 1;
    }
}

pub fn init(map: Layout): bool {
    ram_start = map.ram_start;
    ram_end = map.ram_end;
    page_size = map.page_size;
    page_count = (ram_end - ram_start) / page_size;
    bitmap_len = div_round_up(page_count, 8);

    bitmap_addr = boot.reserve(bitmap_len, page_size);
    if bitmap_addr == 0 {
        return false;
    }

    bitmap_zero();
    free_count = page_count;

    // Boot allocation is byte-granular; physical allocation is page-granular.
    // Any page touched by the kernel image, early boot data, or this bitmap is
    // reserved. There is no hidden safety padding beyond page alignment.
    const boot_used = boot.snapshot();
    mark_range(map.kernel_load, boot_used.next, true);

    boot.freeze();
    return true;
}

pub fn alloc_page(): usize {
    var index: usize = 0;
    while index < page_count {
        if !is_used(index) {
            set_used(index, true);
            return page_addr(index);
        }
        index = index + 1;
    }
    return 0;
}

pub fn free_page(addr: usize): bool {
    if addr < ram_start or addr >= ram_end {
        return false;
    }
    if (addr & (page_size - 1)) != 0 {
        return false;
    }

    const index = page_index(addr);
    if !is_used(index) {
        return false;
    }

    set_used(index, false);
    return true;
}

pub fn snapshot(): PhysSnapshot {
    return PhysSnapshot {
        page_size: page_size,
        total_pages: page_count,
        free_pages: free_count,
        used_pages: page_count - free_count,
        bitmap_start: bitmap_addr,
        bitmap_bytes: bitmap_len,
    };
}
