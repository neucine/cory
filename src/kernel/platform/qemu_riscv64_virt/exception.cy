import .kernel.arch.riscv64.trap_frame;
import .kernel.arch.riscv64.trap_context;
import { TrapFrame } from .kernel.arch.riscv64.trap_frame;
import .kernel.console;
import .kernel.panic as panic_mod;
import .kernel.platform.qemu_riscv64_virt.interrupt;
import .kernel.platform.qemu_riscv64_virt.tick;
import .kernel.task.scheduler;

extern c("cory_arch_trap_init") fn cory_arch_trap_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;

const breakpoint_scause: usize = 3;

pub fn init(): void {
    if !trap_frame.verify_layout() {
        println("exception: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_trap_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("exception: extern c abi probe failed");
        panic_mod.panic();
    }
    println("exception: vectors ready");
}

fn schedule_yield(raw_frame: *TrapFrame): void {
    const resume_ip = trap_frame.instruction_pointer_from_frame(raw_frame) + 4;
    trap_frame.set_resume_state_in_frame(
        raw_frame,
        resume_ip,
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    println("scheduler: yield trap");
    if !trap_context.schedule_and_restore(raw_frame) {
        println("exception: yield schedule failed");
        if trap_context.status() == trap_context.status_schedule_failed {
            println("exception: schedule status failed");
        }
        if trap_context.status() == trap_context.status_resume_state_missing {
            println("exception: resume state missing");
        }
        panic_mod.panic();
    }
    println("exception: yield restore returned unexpectedly");
    panic_mod.panic();
}

export c("cory_arch_trap_entry") fn cory_arch_trap_entry(raw_frame: *TrapFrame): void {
    const frame = trap_frame.diagnostic_from_frame(raw_frame);
    if tick.enabled() and frame.scause == breakpoint_scause {
        schedule_yield(raw_frame);
    }
    if tick.enabled() {
        if interrupt.complete_timer_irq(frame.scause) {
            const count = tick.record_delivery();
            if !interrupt.program_timer_after_ticks(tick.interval_ticks()) {
                println("exception: scheduler tick rearm failed");
                panic_mod.panic();
            }
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
    }
    trap_frame.set_resume_state_in_frame(
        raw_frame,
        trap_frame.instruction_pointer_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    if trap_frame.instruction_pointer_from_frame(raw_frame) != frame.sepc {
        println("exception: riscv64 resume ip mismatch");
        panic_mod.panic();
    }
    if trap_frame.status_flags_from_frame(raw_frame) != frame.sstatus {
        println("exception: riscv64 resume flags mismatch");
        panic_mod.panic();
    }
    println("exception: unhandled riscv64");
    println("exception: scause");
    console.println_hex(frame.scause);
    println("exception: sepc");
    console.println_hex(frame.sepc);
    println("exception: stval");
    console.println_hex(frame.stval);
    println("exception: sstatus");
    console.println_hex(frame.sstatus);
    if tick.delivery_enabled() {
        println("exception: tick delivery enabled");
    }
    panic_mod.panic();
}
