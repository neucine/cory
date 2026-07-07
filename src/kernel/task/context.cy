import .kernel.arch.aarch64.context as aarch64_context;
import .kernel.arch.riscv64.context as riscv64_context;
import .kernel.collections.slot_map;
import { StaticSlotMap } from .kernel.collections.slot_map;
import .kernel.task.thread;
import { ThreadState } from .kernel.task.thread;
import .kernel.memory.page_table;

pub const max_contexts: usize = 32;
pub const invalid_id: usize = slot_map.invalid_key;
pub const invalid_arch_context: usize = slot_map.invalid_key;

pub enum ContextStatus: i32 {
    ok = 0,
    table_full,
    invalid_thread,
    duplicate_context,
    dead_thread,
    invalid_arch,
    invalid_arch_context,
    missing_context,
}

pub struct ThreadContext {
    pub id: usize;
    pub thread_id: usize;
    pub instruction_pointer: usize;
    pub stack_pointer: usize;
    pub status_flags: usize;
    pub arch_id: i32;
    pub arch_context_id: usize;
    pub initialized: bool;
}

pub struct ResumeState {
    pub instruction_pointer: usize;
    pub stack_pointer: usize;
    pub status_flags: usize;
    pub valid: bool;
}

var context_ids_by_thread_index: [32]usize = [0] ** 32;
var contexts: StaticSlotMap<[32]ThreadContext> = StaticSlotMap<[32]ThreadContext> {
    values: [ThreadContext {
        id: invalid_id,
        thread_id: thread.invalid_id,
        instruction_pointer: 0,
        stack_pointer: 0,
        status_flags: 0,
        arch_id: 0,
        arch_context_id: invalid_arch_context,
        initialized: false,
    }] ** 32,
    live: [false] ** 32,
    generations: [0] ** 32,
    live_count: 0,
    last_status: slot_map.status_ok,
};
var last_status: ContextStatus = ContextStatus.ok;

fn empty_context(): ThreadContext {
    return ThreadContext {
        id: invalid_id,
        thread_id: thread.invalid_id,
        instruction_pointer: 0,
        stack_pointer: 0,
        status_flags: 0,
        arch_id: 0,
        arch_context_id: invalid_arch_context,
        initialized: false,
    };
}

fn empty_resume_state(): ResumeState {
    return ResumeState {
        instruction_pointer: 0,
        stack_pointer: 0,
        status_flags: 0,
        valid: false,
    };
}

pub fn init(): void {
    contexts.clear();
    var index: usize = 0;
    while index < max_contexts {
        contexts.values[index] = empty_context();
        context_ids_by_thread_index[index] = invalid_id;
        index = index + 1;
    }
    last_status = ContextStatus.ok;
}

fn index_for_thread(thread_id: usize): usize {
    if thread_id == thread.invalid_id {
        return max_contexts;
    }
    const thread_index = slot_map.index(thread.max_threads, thread_id);
    if thread_index >= max_contexts {
        return max_contexts;
    }
    const context_id = context_ids_by_thread_index[thread_index];
    if !contexts.contains(context_id) {
        return max_contexts;
    }
    const context_index = contexts.index(context_id);
    if contexts.values[context_index].thread_id != thread_id {
        return max_contexts;
    }
    return context_index;
}

fn arch_is_valid(arch_id: i32): bool {
    return arch_id == page_table.arch_aarch64 or arch_id == page_table.arch_riscv64;
}

fn arch_context_is_valid(arch_id: i32, arch_context_id: usize): bool {
    if arch_id == page_table.arch_aarch64 {
        return aarch64_context.is_live(arch_context_id);
    }
    if arch_id == page_table.arch_riscv64 {
        return riscv64_context.is_live(arch_context_id);
    }
    return false;
}

fn set_arch_resume_state(arch_id: i32, arch_context_id: usize, instruction_pointer: usize, stack_pointer: usize, status_flags: usize): bool {
    if arch_id == page_table.arch_aarch64 {
        return aarch64_context.set_resume_state(arch_context_id, instruction_pointer, stack_pointer, status_flags);
    }
    if arch_id == page_table.arch_riscv64 {
        return riscv64_context.set_resume_state(arch_context_id, instruction_pointer, stack_pointer, status_flags);
    }
    return false;
}

pub fn attach_kernel_context(thread_id: usize, instruction_pointer: usize, stack_pointer: usize, arch_id: i32, arch_context_id: usize): bool {
    const entry = thread.get(thread_id);
    if entry.id == thread.invalid_id {
        last_status = ContextStatus.invalid_thread;
        return false;
    }
    if !arch_is_valid(arch_id) {
        last_status = ContextStatus.invalid_arch;
        return false;
    }
    if entry.state == ThreadState.dead {
        last_status = ContextStatus.dead_thread;
        return false;
    }
    if index_for_thread(thread_id) < max_contexts {
        last_status = ContextStatus.duplicate_context;
        return false;
    }
    if !arch_context_is_valid(arch_id, arch_context_id) {
        last_status = ContextStatus.invalid_arch_context;
        return false;
    }
    if !set_arch_resume_state(arch_id, arch_context_id, instruction_pointer, stack_pointer, 0) {
        last_status = ContextStatus.invalid_arch_context;
        return false;
    }
    const slot_id = contexts.reserve();
    if slot_id == slot_map.invalid_key {
        last_status = ContextStatus.table_full;
        return false;
    }
    const index = contexts.index(slot_id);
    const thread_index = slot_map.index(thread.max_threads, thread_id);
    context_ids_by_thread_index[thread_index] = slot_id;
    contexts.values[index] = ThreadContext {
        id: slot_id,
        thread_id: thread_id,
        instruction_pointer: instruction_pointer,
        stack_pointer: stack_pointer,
        status_flags: 0,
        arch_id: arch_id,
        arch_context_id: arch_context_id,
        initialized: true,
    };
    last_status = ContextStatus.ok;
    return true;
}

pub fn save_resume_state(thread_id: usize, instruction_pointer: usize, stack_pointer: usize, status_flags: usize): bool {
    const entry = thread.get(thread_id);
    if entry.id == thread.invalid_id {
        last_status = ContextStatus.invalid_thread;
        return false;
    }
    if entry.state == ThreadState.dead {
        last_status = ContextStatus.dead_thread;
        return false;
    }
    const index = index_for_thread(thread_id);
    if index >= max_contexts {
        last_status = ContextStatus.missing_context;
        return false;
    }
    var saved = contexts.values[index];
    if !set_arch_resume_state(saved.arch_id, saved.arch_context_id, instruction_pointer, stack_pointer, status_flags) {
        last_status = ContextStatus.invalid_arch_context;
        return false;
    }
    saved.instruction_pointer = instruction_pointer;
    saved.stack_pointer = stack_pointer;
    saved.status_flags = status_flags;
    contexts.values[index] = saved;
    last_status = ContextStatus.ok;
    return true;
}

pub fn has_context(thread_id: usize): bool {
    return index_for_thread(thread_id) < max_contexts;
}

pub fn get(thread_id: usize): ThreadContext {
    const index = index_for_thread(thread_id);
    if index >= max_contexts {
        return empty_context();
    }
    return contexts.values[index];
}

pub fn get_resume_state(thread_id: usize): ResumeState {
    const entry = thread.get(thread_id);
    if entry.id == thread.invalid_id {
        last_status = ContextStatus.invalid_thread;
        return empty_resume_state();
    }
    const index = index_for_thread(thread_id);
    if index >= max_contexts {
        last_status = ContextStatus.missing_context;
        return empty_resume_state();
    }
    const saved = contexts.values[index];
    last_status = ContextStatus.ok;
    return ResumeState {
        instruction_pointer: saved.instruction_pointer,
        stack_pointer: saved.stack_pointer,
        status_flags: saved.status_flags,
        valid: true,
    };
}

pub fn count(): usize {
    return contexts.count();
}

pub fn status(): ContextStatus {
    return last_status;
}
