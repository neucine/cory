import .platform.qemu_riscv64_virt.timer;

extern c("cory_riscv64_irq_mask") fn cory_riscv64_irq_mask(): void;
extern c("cory_riscv64_irq_unmask") fn cory_riscv64_irq_unmask(): void;
extern c("cory_riscv64_supervisor_timer_irq_enable") fn supervisor_timer_irq_enable_raw(): void;
extern c("cory_riscv64_supervisor_timer_irq_disable") fn supervisor_timer_irq_disable_raw(): void;

pub const supervisor_timer_scause: usize = 9223372036854775813;

pub fn mask(): void {
    cory_riscv64_irq_mask();
}

pub fn unmask(): void {
    cory_riscv64_irq_unmask();
}

pub fn init_timer_irq(): void {
    supervisor_timer_irq_enable_raw();
}

pub fn disable_timer_irq(): void {
    supervisor_timer_irq_disable_raw();
}

pub fn program_timer_after_ticks(delta: usize): bool {
    return timer.program_irq_after_ticks(delta);
}

pub fn complete_timer_irq(scause: usize): bool {
    if scause != supervisor_timer_scause {
        return false;
    }
    timer.disarm();
    return true;
}
