extern c("cory_riscv64_time_value") fn time_value_raw(): c_ulong;
extern c("cory_riscv64_machine_timer_program") fn machine_timer_program_raw(delta: c_ulong): void;
extern c("cory_riscv64_machine_timer_clear") fn machine_timer_clear_raw(): void;

// QEMU virt exposes the architectural RISC-V time CSR to S-mode in the current
// M-mode shim. Frequency discovery is platform/SBI work; timer IRQ delivery is
// currently a Cory-owned M-mode shim that converts MTIP into S-mode STIP.
pub fn counter(): usize {
    return time_value_raw() as usize;
}

pub fn disarm(): void {
    machine_timer_clear_raw();
}

pub fn program_irq_after_ticks(delta: usize): bool {
    if delta == 0 {
        return false;
    }
    machine_timer_program_raw(delta as c_ulong);
    return true;
}

pub fn readable(): bool {
    const first = counter();
    const second = counter();
    return second >= first;
}
