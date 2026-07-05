import .kernel.platform.qemu_aarch64_virt.gic;
import .kernel.platform.qemu_aarch64_virt.timer;

extern c("cory_aarch64_irq_mask") fn cory_aarch64_irq_mask(): void;
extern c("cory_aarch64_irq_unmask") fn cory_aarch64_irq_unmask(): void;

pub const virtual_timer_intid = gic.virtual_timer_intid;
pub const spurious_intid = gic.spurious_intid;

pub fn mask(): void {
    cory_aarch64_irq_mask();
}

pub fn unmask(): void {
    cory_aarch64_irq_unmask();
}

pub fn init_timer_irq(): void {
    gic.init_timer_irq();
}

pub fn program_timer_after_ticks(delta: usize): bool {
    return timer.program_irq_after_ticks(delta);
}

pub fn acknowledge(): usize {
    return gic.acknowledge();
}

pub fn end(intid: usize): void {
    gic.end(intid);
}

pub fn complete_timer_irq(intid: usize): bool {
    if intid != virtual_timer_intid {
        if intid != spurious_intid {
            end(intid);
        }
        return false;
    }
    timer.disarm();
    end(intid);
    return true;
}
