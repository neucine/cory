packed struct Register {
    value: u32;
}

const distributor_base = 0x08000000;
const cpu_base = 0x08010000;

const dist_ctlr = distributor_base + 0x000;
const dist_isenabler0 = distributor_base + 0x100;

const cpu_ctlr = cpu_base + 0x000;
const cpu_pmr = cpu_base + 0x004;
const cpu_iar = cpu_base + 0x00c;
const cpu_eoir = cpu_base + 0x010;

pub const virtual_timer_intid = 27;
pub const spurious_intid = 1023;

fn register(address: usize): *volatile Register {
    unchecked {
        return address as! *volatile Register;
    }
}

fn read32(address: usize): usize {
    unchecked {
        return (*register(address)).value as usize;
    }
}

fn write32(address: usize, value: usize): void {
    unchecked {
        (*register(address)).value = value as u32;
    }
}

pub fn init_timer_irq(): void {
    write32(dist_ctlr, 0);
    write32(dist_isenabler0, 1 << virtual_timer_intid);
    write32(cpu_pmr, 0xff);
    write32(cpu_ctlr, 1);
    write32(dist_ctlr, 1);
}

pub fn acknowledge(): usize {
    return read32(cpu_iar) & 0x3ff;
}

pub fn end(intid: usize): void {
    write32(cpu_eoir, intid);
}
