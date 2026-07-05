extern c("cory_aarch64_counter_frequency") fn counter_frequency_raw(): c_ulong;
extern c("cory_aarch64_counter_value") fn counter_value_raw(): c_ulong;
extern c("cory_aarch64_timer_tval_write") fn timer_tval_write_raw(ticks: c_ulong): void;
extern c("cory_aarch64_timer_ctl_read") fn timer_ctl_read_raw(): c_ulong;
extern c("cory_aarch64_timer_ctl_write") fn timer_ctl_write_raw(value: c_ulong): void;

pub const ctl_enable = 1;
pub const ctl_imask = 2;
pub const ctl_istatus = 4;

pub fn frequency(): usize {
    return counter_frequency_raw() as usize;
}

pub fn counter(): usize {
    return counter_value_raw() as usize;
}

pub fn control(): usize {
    return timer_ctl_read_raw() as usize;
}

pub fn disarm(): void {
    timer_ctl_write_raw(ctl_imask as c_ulong);
}

pub fn program_masked_after_ticks(delta: usize): bool {
    if delta == 0 {
        return false;
    }
    timer_tval_write_raw(delta as c_ulong);
    timer_ctl_write_raw((ctl_enable | ctl_imask) as c_ulong);
    const ctl = control();
    if (ctl & ctl_enable) == 0 {
        return false;
    }
    if (ctl & ctl_imask) == 0 {
        return false;
    }
    return true;
}

pub fn program_irq_after_ticks(delta: usize): bool {
    if delta == 0 {
        return false;
    }
    timer_tval_write_raw(delta as c_ulong);
    timer_ctl_write_raw(ctl_enable as c_ulong);
    const ctl = control();
    if (ctl & ctl_enable) == 0 {
        return false;
    }
    if (ctl & ctl_imask) != 0 {
        return false;
    }
    return true;
}

pub fn readable(): bool {
    if frequency() == 0 {
        return false;
    }
    const first = counter();
    const second = counter();
    return second >= first;
}

pub fn deadline_programmable(): bool {
    const freq = frequency();
    if freq == 0 {
        return false;
    }

    var delta = freq / 1000;
    if delta == 0 {
        delta = 1;
    }

    const ok = program_masked_after_ticks(delta);
    disarm();
    return ok;
}
