pub const mode_disabled = 0;
pub const mode_diagnostic = 1;
pub const mode_enabled = 2;

var current: usize = mode_disabled;

pub fn init_disabled(): void {
    current = mode_disabled;
}

pub fn set_diagnostic(): void {
    current = mode_diagnostic;
}

pub fn set_enabled(): void {
    current = mode_enabled;
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
