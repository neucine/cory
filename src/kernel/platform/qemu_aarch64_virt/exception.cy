import .kernel.arch.aarch64.trap_frame;
import .kernel.arch.aarch64.trap_context;
import { TrapFrame } from .kernel.arch.aarch64.trap_frame;
import .kernel.console;
import .kernel.panic as panic_mod;
import .kernel.platform.qemu_aarch64_virt.interrupt;
import .kernel.platform.qemu_aarch64_virt.tick;
import .kernel.task.scheduler;

extern c("cory_arch_exception_init") fn cory_arch_exception_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;
extern c("cory_arch_current_el") fn cory_arch_current_el(): c_ulong;

pub fn init(): void {
    if cory_arch_current_el() != 1 {
        println("exception: expected EL1");
        panic_mod.panic();
    }
    if !trap_frame.verify_layout() {
        println("exception: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_exception_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("exception: extern c abi probe failed");
        panic_mod.panic();
    }
    println("exception: vectors ready");
}

fn report_unhandled(raw_frame: *TrapFrame): void {
    trap_frame.set_resume_state_in_frame(
        raw_frame,
        trap_frame.instruction_pointer_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    const frame = trap_frame.diagnostic_from_frame(raw_frame);
    if trap_frame.instruction_pointer_from_frame(raw_frame) != frame.elr_el1 {
        println("exception: aarch64 resume ip mismatch");
        panic_mod.panic();
    }
    if trap_frame.status_flags_from_frame(raw_frame) != frame.spsr_el1 {
        println("exception: aarch64 resume flags mismatch");
        panic_mod.panic();
    }
    println("exception: unhandled aarch64");
    println("exception: esr_el1");
    console.println_hex(frame.esr_el1);
    println("exception: elr_el1");
    console.println_hex(frame.elr_el1);
    println("exception: far_el1");
    console.println_hex(frame.far_el1);
    println("exception: spsr_el1");
    console.println_hex(frame.spsr_el1);
    panic_mod.panic();
}

export c("cory_arch_sync_exception_entry") fn cory_arch_sync_exception_entry(raw_frame: *TrapFrame): void {
    report_unhandled(raw_frame);
}

export c("cory_arch_irq_exception_entry") fn cory_arch_irq_exception_entry(raw_frame: *TrapFrame): void {
    interrupt.mask();
    const intid = interrupt.acknowledge();
    if tick.diagnostic_enabled() {
        if interrupt.complete_timer_irq(intid) {
            const count = tick.record_delivery();
            if count == 1 {
                println("tick: diagnostic tick");
            }
            trap_context.restore_from_frame(raw_frame);
        }
    } else if tick.enabled() {
        if interrupt.complete_timer_irq(intid) {
            const count = tick.record_delivery();
            if scheduler.count() == 0 {
                if count == 1 {
                    println("tick: scheduler idle");
                }
                trap_context.restore_from_frame(raw_frame);
            }
            if count == 1 {
                println("tick: scheduler tick");
            }
            if !trap_context.schedule_and_restore(raw_frame) {
                println("exception: scheduler tick failed");
                if trap_context.status() == trap_context.status_schedule_failed {
                    println("exception: schedule status failed");
                }
                if trap_context.status() == trap_context.status_resume_state_missing {
                    println("exception: resume state missing");
                }
                panic_mod.panic();
            }
            println("exception: scheduler restore returned unexpectedly");
            panic_mod.panic();
        }
    } else if intid != interrupt.spurious_intid {
        interrupt.end(intid);
    }
    println("exception: unhandled aarch64 irq");
    if !tick.delivery_enabled() {
        println("exception: tick delivery disabled");
    }
    report_unhandled(raw_frame);
}
