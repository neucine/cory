import .collections.slot_map;
import { StaticSlotMap } from .collections.slot_map;
import .memory.page_table;

pub const arch_id: i32 = page_table.arch_aarch64;
pub const invalid_context: usize = slot_map.invalid_key;
pub const max_contexts: usize = 32;

pub const status_ok: i32 = 0;
pub const status_table_full: i32 = 1;
pub const status_invalid_context: i32 = 2;
pub const user_spsr_el1: usize = 0;

pub struct ArchContext {
    pub id: usize;
    pub owner_thread_id: usize;
    pub instruction_pointer: usize;
    pub stack_pointer: usize;
    pub status_flags: usize;
}

var contexts: StaticSlotMap<ArchContext, 32> = StaticSlotMap<ArchContext, 32> {
    values: [ArchContext {
        id: invalid_context,
        owner_thread_id: 0,
        instruction_pointer: 0,
        stack_pointer: 0,
        status_flags: 0,
    }] ** 32,
    live: [false] ** 32,
    generations: [0] ** 32,
    live_count: 0,
    last_status: slot_map.status_ok,
};
var last_status: i32 = status_ok;

fn empty_context(): ArchContext {
    return ArchContext {
        id: invalid_context,
        owner_thread_id: 0,
        instruction_pointer: 0,
        stack_pointer: 0,
        status_flags: 0,
    };
}

pub fn context_arch_id(): i32 {
    return arch_id;
}

pub fn context_size(): usize {
    // Matches the current AArch64 TrapFrame payload: 36 saved 8-byte values.
    return 288;
}

pub fn context_alignment(): usize {
    return 8;
}

pub fn user_status_flags(): usize {
    return user_spsr_el1;
}

pub fn init(): void {
    contexts.clear();
    var index: usize = 0;
    while index < max_contexts {
        contexts.values[index] = empty_context();
        index = index + 1;
    }
    last_status = status_ok;
}

pub fn allocate(owner_thread_id: usize): usize {
    const id = contexts.reserve();
    if id == invalid_context {
        last_status = status_table_full;
        return invalid_context;
    }
    contexts.values[contexts.index(id)] = ArchContext {
        id: id,
        owner_thread_id: owner_thread_id,
        instruction_pointer: 0,
        stack_pointer: 0,
        status_flags: 0,
    };
    last_status = status_ok;
    return id;
}

pub fn is_live(id: usize): bool {
    const live = contexts.contains(id);
    if !live {
        last_status = status_invalid_context;
    } else {
        last_status = status_ok;
    }
    return live;
}

pub fn release(id: usize): bool {
    if !is_live(id) {
        return false;
    }
    const index = contexts.index(id);
    contexts.values[index] = empty_context();
    if contexts.remove(id) is none {
        last_status = status_invalid_context;
        return false;
    }
    last_status = status_ok;
    return true;
}

pub fn owner_thread_id(id: usize): usize {
    if !is_live(id) {
        return 0;
    }
    last_status = status_ok;
    return contexts.values[contexts.index(id)].owner_thread_id;
}

pub fn set_resume_state(id: usize, instruction_pointer: usize, stack_pointer: usize, status_flags: usize): bool {
    if !is_live(id) {
        return false;
    }
    const index = contexts.index(id);
    var entry = contexts.values[index];
    entry.instruction_pointer = instruction_pointer;
    entry.stack_pointer = stack_pointer;
    entry.status_flags = status_flags;
    contexts.values[index] = entry;
    last_status = status_ok;
    return true;
}

pub fn instruction_pointer(id: usize): usize {
    if !is_live(id) {
        return 0;
    }
    last_status = status_ok;
    return contexts.values[contexts.index(id)].instruction_pointer;
}

pub fn stack_pointer(id: usize): usize {
    if !is_live(id) {
        return 0;
    }
    last_status = status_ok;
    return contexts.values[contexts.index(id)].stack_pointer;
}

pub fn status_flags(id: usize): usize {
    if !is_live(id) {
        return 0;
    }
    last_status = status_ok;
    return contexts.values[contexts.index(id)].status_flags;
}

pub fn count(): usize {
    return contexts.count();
}

pub fn status(): i32 {
    return last_status;
}
