extern c("__kernel_end") const __kernel_end: *u8;

pub struct Snapshot {
    pub start: usize;
    pub next: usize;
    pub end: usize;
}

var heap_start: usize = 0;
var heap_next: usize = 0;
var heap_end: usize = 0;
var frozen: bool = false;

const max_usize: usize = 0 - 1;

fn is_power_of_two(value: usize): bool {
    if value == 0 {
        return false;
    }
    return (value & (value - 1)) == 0;
}

pub fn align_up(value: usize, alignment: usize): usize {
    if !is_power_of_two(alignment) {
        return 0;
    }

    const mask = alignment - 1;
    if value > max_usize - mask {
        return 0;
    }
    return (value + mask) & (0 - alignment);
}

pub fn init(memory_end: usize, page_size: usize): void {
    unchecked {
        heap_start = align_up(__kernel_end as! usize, page_size);
    }
    heap_next = heap_start;
    heap_end = memory_end;
    frozen = false;
}

pub fn reserve(size: usize, alignment: usize): usize {
    if frozen {
        return 0;
    }

    const aligned = align_up(heap_next, alignment);
    if aligned == 0 {
        return 0;
    }
    if aligned > max_usize - size {
        return 0;
    }
    const next = aligned + size;
    if next > heap_end {
        return 0;
    }

    heap_next = next;
    return aligned;
}

pub fn snapshot(): Snapshot {
    return Snapshot {
        start: heap_start,
        next: heap_next,
        end: heap_end,
    };
}

pub fn used(): usize {
    return heap_next - heap_start;
}

pub fn freeze(): void {
    frozen = true;
}

pub fn is_frozen(): bool {
    return frozen;
}
