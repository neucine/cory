extern c("cory_riscv64_time_value") fn time_value_raw(): c_ulong;

// QEMU virt exposes the architectural RISC-V time CSR to S-mode in the current
// M-mode shim. Frequency discovery is platform/SBI work; for now this module
// only proves the monotonically readable counter path needed before timer
// interrupt ownership.
pub fn counter(): usize {
    return time_value_raw() as usize;
}

pub fn readable(): bool {
    const first = counter();
    const second = counter();
    return second >= first;
}
