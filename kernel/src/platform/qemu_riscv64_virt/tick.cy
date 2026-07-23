pub const mode_disabled = 0;
pub const mode_enabled = 1;

pub const interval = 10000;

var current: usize = mode_disabled;
var delivered: usize = 0;

pub fn init_disabled(): void {
    current = mode_disabled;
    delivered = 0;
}

pub fn set_enabled(): void {
    current = mode_enabled;
    delivered = 0;
}

pub fn enabled(): bool {
    return current == mode_enabled;
}

pub fn delivery_enabled(): bool {
    return current == mode_enabled;
}

pub fn record_delivery(): usize {
    delivered = delivered + 1;
    return delivered;
}

pub fn interval_ticks(): usize {
    return interval;
}
