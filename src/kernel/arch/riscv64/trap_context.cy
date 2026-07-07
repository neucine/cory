import .kernel.arch.riscv64.trap_frame;
import { TrapFrame } from .kernel.arch.riscv64.trap_frame;
import .kernel.task.context;
import { ResumeState } from .kernel.task.context;
import .kernel.task.scheduler;

extern c("cory_arch_trap_restore_from_frame") fn cory_arch_trap_restore_from_frame(raw_frame: *TrapFrame): void;

pub const status_ok: i32 = 0;
pub const status_schedule_failed: i32 = 1;
pub const status_resume_state_missing: i32 = 2;
pub const status_restoring: i32 = 3;

var last_status: i32 = status_ok;

pub fn save_trap_resume_state(thread_id: usize, raw_frame: *TrapFrame): bool {
    return context.save_resume_state(
        thread_id,
        trap_frame.instruction_pointer_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
}

pub fn schedule_next_from_trap_frame(raw_frame: *TrapFrame): usize {
    return scheduler.schedule_next_saving_current(
        trap_frame.instruction_pointer_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
}

pub fn resume_state_for_thread(thread_id: usize): ResumeState {
    return context.get_resume_state(thread_id);
}

pub fn write_resume_state_to_frame(thread_id: usize, raw_frame: *TrapFrame): bool {
    const state = context.get_resume_state(thread_id);
    if !state.valid {
        last_status = status_resume_state_missing;
        return false;
    }
    trap_frame.set_resume_state_in_frame(raw_frame, state.instruction_pointer, state.stack_pointer, state.status_flags);
    last_status = status_ok;
    return true;
}

pub fn schedule_and_restore(raw_frame: *TrapFrame): bool {
    const next = schedule_next_from_trap_frame(raw_frame);
    if next == scheduler.invalid_thread {
        last_status = status_schedule_failed;
        return false;
    }
    if !write_resume_state_to_frame(next, raw_frame) {
        return false;
    }
    last_status = status_restoring;
    restore_from_frame(raw_frame);
    return true;
}

pub fn block_current_and_restore(raw_frame: *TrapFrame, resume_instruction_pointer: usize): bool {
    const next = scheduler.block_current_saving_context(
        resume_instruction_pointer,
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    if next == scheduler.invalid_thread {
        last_status = status_schedule_failed;
        return false;
    }
    if !write_resume_state_to_frame(next, raw_frame) {
        return false;
    }
    last_status = status_restoring;
    restore_from_frame(raw_frame);
    return true;
}

pub fn restore_from_frame(raw_frame: *TrapFrame): void {
    cory_arch_trap_restore_from_frame(raw_frame);
}

pub fn status(): i32 {
    return last_status;
}
