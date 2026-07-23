pub const mode_disabled = 0;
pub const mode_diagnostic = 1;
pub const mode_enabled = 2;

pub const ticks_per_second = 100;

var current: usize = mode_disabled;
var delivered: usize = 0;

pub fn init_disabled(): void {
    current = mode_disabled;
    delivered = 0;
}

pub fn set_diagnostic(): void {
    current = mode_diagnostic;
    delivered = 0;
}

pub fn set_enabled(): void {
    current = mode_enabled;
    delivered = 0;
}

pub fn mode(): usize {
    return current;
}

pub fn diagnostic_enabled(): bool {
    return current == mode_diagnostic;
}

pub fn delivery_enabled(): bool {
    return current == mode_diagnostic or current == mode_enabled;
}

pub fn enabled(): bool {
    return current == mode_enabled;
}

pub fn record_delivery(): usize {
    delivered = delivered + 1;
    return delivered;
}

pub fn delivered_count(): usize {
    return delivered;
}

pub fn interval_ticks(timer_frequency: usize): usize {
    var interval = timer_frequency / ticks_per_second;
    if interval == 0 {
        interval = 1;
    }
    return interval;
}
