extern c("__bss_start") const __bss_start: *u8;
extern c("__bss_end") const __bss_end: *u8;

fn zero_region(start: *u8, end: *u8): void {
    unchecked {
        var addr: usize = start as! usize;
        const limit: usize = end as! usize;
        const zero: u8 = 0;
        while addr < limit {
            const byte_ptr: *u8 = addr as! *u8;
            *byte_ptr = zero;
            addr = addr + 1;
        }
    }
}

pub fn zero_bss(): void {
    zero_region(__bss_start, __bss_end);
}
