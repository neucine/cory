import .arch.riscv64.trap_frame;
import { TrapFrame } from .arch.riscv64.trap_frame;
import .arch.riscv64.context as arch_context;
import .collections.slot_map;
import .task.context;
import .task.scheduler;

extern c("cory_arch_trap_restore_from_frame") fn cory_arch_trap_restore_from_frame(raw_frame: *TrapFrame): void;
extern c("cory_switch_thread_address_space") fn cory_switch_thread_address_space(thread_id: c_ulong): void;

pub const status_ok: i32 = 0;
pub const status_schedule_failed: i32 = 1;
pub const status_resume_state_missing: i32 = 2;
pub const status_restoring: i32 = 3;

var last_status: i32 = status_ok;
var saved_frames: [32]TrapFrame = [trap_frame.empty_frame_value] ** 32;
var saved_frame_valid: [32]bool = [false] ** 32;

fn index_for_arch_context(arch_context_id: usize): usize {
    const index = slot_map.index(arch_context.max_contexts, arch_context_id);
    if index >= arch_context.max_contexts {
        return arch_context.max_contexts;
    }
    if !arch_context.is_live(arch_context_id) {
        return arch_context.max_contexts;
    }
    return index;
}

fn save_arch_frame(arch_context_id: usize, raw_frame: *TrapFrame, instruction_pointer: usize): bool {
    const index = index_for_arch_context(arch_context_id);
    if index >= arch_context.max_contexts {
        return false;
    }
    saved_frames[index] = trap_frame.copy_frame_with_resume(raw_frame, instruction_pointer);
    saved_frame_valid[index] = true;
    return true;
}

pub fn seed_resume_frame(arch_context_id: usize, instruction_pointer: usize, stack_pointer: usize, status_flags: usize): bool {
    const index = index_for_arch_context(arch_context_id);
    if index >= arch_context.max_contexts {
        return false;
    }
    saved_frames[index] = trap_frame.frame_with_resume_state(instruction_pointer, stack_pointer, status_flags);
    saved_frame_valid[index] = true;
    return true;
}

fn write_arch_frame(arch_context_id: usize, raw_frame: *TrapFrame): bool {
    const index = index_for_arch_context(arch_context_id);
    if index >= arch_context.max_contexts {
        return false;
    }
    if !saved_frame_valid[index] {
        return false;
    }
    trap_frame.write_frame(raw_frame, saved_frames[index]);
    return true;
}

fn write_user_resume_state(thread_context: context.ThreadContext, raw_frame: *TrapFrame): bool {
    if (thread_context.status_flags & arch_context.sstatus_spp) != 0 {
        return false;
    }
    trap_frame.set_resume_state_in_frame(raw_frame, thread_context.instruction_pointer, thread_context.stack_pointer, thread_context.status_flags);
    return true;
}

fn write_kernel_resume_state(thread_context: context.ThreadContext, raw_frame: *TrapFrame): bool {
    if (thread_context.status_flags & arch_context.sstatus_spp) == 0 {
        return false;
    }
    trap_frame.set_resume_state_in_frame(raw_frame, thread_context.instruction_pointer, thread_context.stack_pointer, thread_context.status_flags);
    return true;
}

pub fn schedule_next_from_trap_frame(raw_frame: *TrapFrame): usize {
    const current_context = context.get(scheduler.current());
    if current_context.id != context.invalid_id {
        if !save_arch_frame(
            current_context.arch_context_id,
            raw_frame,
            trap_frame.instruction_pointer_from_frame(raw_frame)
        ) {
            return scheduler.invalid_thread;
        }
    }
    return scheduler.schedule_next_saving_current(
        trap_frame.instruction_pointer_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
}

fn schedule_next_from_trap_frame_to_front(raw_frame: *TrapFrame): usize {
    const current_context = context.get(scheduler.current());
    if current_context.id != context.invalid_id {
        if !save_arch_frame(
            current_context.arch_context_id,
            raw_frame,
            trap_frame.instruction_pointer_from_frame(raw_frame)
        ) {
            return scheduler.invalid_thread;
        }
    }
    return scheduler.schedule_next_saving_current_to_front(
        trap_frame.instruction_pointer_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
}

pub fn write_resume_state_to_frame(thread_id: usize, raw_frame: *TrapFrame): bool {
    const thread_context = context.get(thread_id);
    if thread_context.id != context.invalid_id {
        if write_user_resume_state(thread_context, raw_frame) {
            last_status = status_ok;
            return true;
        }
        if write_arch_frame(thread_context.arch_context_id, raw_frame) {
            last_status = status_ok;
            return true;
        }
        if write_kernel_resume_state(thread_context, raw_frame) {
            last_status = status_ok;
            return true;
        }
    }
    last_status = status_resume_state_missing;
    return false;
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
    cory_switch_thread_address_space(next as c_ulong);
    last_status = status_restoring;
    restore_from_frame(raw_frame);
    return true;
}

pub fn schedule_and_restore_current_to_front(raw_frame: *TrapFrame): bool {
    const next = schedule_next_from_trap_frame_to_front(raw_frame);
    if next == scheduler.invalid_thread {
        last_status = status_schedule_failed;
        return false;
    }
    if !write_resume_state_to_frame(next, raw_frame) {
        return false;
    }
    cory_switch_thread_address_space(next as c_ulong);
    last_status = status_restoring;
    restore_from_frame(raw_frame);
    return true;
}

pub fn block_current_and_restore(raw_frame: *TrapFrame, resume_instruction_pointer: usize): bool {
    const current_context = context.get(scheduler.current());
    if current_context.id != context.invalid_id {
        if !save_arch_frame(current_context.arch_context_id, raw_frame, resume_instruction_pointer) {
            last_status = status_schedule_failed;
            return false;
        }
    }
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
    cory_switch_thread_address_space(next as c_ulong);
    last_status = status_restoring;
    restore_from_frame(raw_frame);
    return true;
}

pub fn exit_current_and_restore(raw_frame: *TrapFrame): bool {
    const next = scheduler.exit_current();
    if next == scheduler.invalid_thread {
        last_status = status_schedule_failed;
        return false;
    }
    if !write_resume_state_to_frame(next, raw_frame) {
        return false;
    }
    cory_switch_thread_address_space(next as c_ulong);
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
