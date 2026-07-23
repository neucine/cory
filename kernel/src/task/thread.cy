import .collections.slot_map;
import { StaticSlotMap } from .collections.slot_map;
import .object.capability;
import { CapabilityRights } from .object.capability;
import .object.kernel_object;
import { KernelObjectKind } from .object.kernel_object;
import .task.capability_space;
import .task.process;
import { ProcessKind } from .task.process;

pub const invalid_id: usize = slot_map.invalid_key;
pub const max_threads: usize = 32;

pub enum ThreadState: i32 {
    empty = 0,
    created,
    ready,
    running,
    blocked,
    dead,
}

pub enum ThreadStatus: i32 {
    ok = 0,
    table_full,
    invalid_process,
    invalid_capability_slot,
    capability_object_mismatch,
    capability_right_missing,
    object_allocation_failed,
    capability_allocation_failed,
    invalid_id,
    capability_space_failed,
    invalid_entry,
    invalid_stack,
}

pub struct Thread {
    pub id: usize;
    pub object_id: usize;
    pub capability_id: usize;
    pub capability_slot: usize;
    pub process_id: usize;
    pub state: ThreadState;
    pub entry_addr: usize;
    pub stack_base: usize;
}

var threads: StaticSlotMap<Thread, 32> = StaticSlotMap<Thread, 32> {
    values: [Thread {
        id: invalid_id,
        object_id: kernel_object.invalid_id,
        capability_id: capability.invalid_id,
        capability_slot: capability_space.invalid_slot,
        process_id: process.invalid_id,
        state: ThreadState.empty,
        entry_addr: 0,
        stack_base: 0,
    }] ** 32,
    live: [false] ** 32,
    generations: [0] ** 32,
    live_count: 0,
    last_status: slot_map.status_ok,
};
var current_id: usize = invalid_id;
var last_status: ThreadStatus = ThreadStatus.ok;

fn empty_thread(): Thread {
    return Thread {
        id: invalid_id,
        object_id: kernel_object.invalid_id,
        capability_id: capability.invalid_id,
        capability_slot: capability_space.invalid_slot,
        process_id: process.invalid_id,
        state: ThreadState.empty,
        entry_addr: 0,
        stack_base: 0,
    };
}

pub fn init(): void {
    threads.clear();
    var index: usize = 0;
    while index < max_threads {
        threads.values[index] = empty_thread();
        index = index + 1;
    }
    current_id = invalid_id;
    last_status = ThreadStatus.ok;
}

fn index_for_id(id: usize): usize {
    if id == invalid_id {
        return max_threads;
    }
    if !threads.contains(id) {
        return max_threads;
    }
    return threads.index(id);
}

fn process_capability_authorizes(process_id: usize, process_capability_slot: usize): bool {
    const process_object_id = process.get(process_id).object_id;
    if process_object_id == kernel_object.invalid_id {
        last_status = ThreadStatus.invalid_process;
        return false;
    }
    const cap_id = capability_space.get(process_id, process_capability_slot);
    if cap_id == capability.invalid_id {
        last_status = ThreadStatus.invalid_capability_slot;
        return false;
    }
    const cap = capability.get(cap_id);
    if cap.object_id != process_object_id {
        last_status = ThreadStatus.capability_object_mismatch;
        return false;
    }
    if !capability.has_rights(cap_id, CapabilityRights.manage) {
        last_status = ThreadStatus.capability_right_missing;
        return false;
    }
    last_status = ThreadStatus.ok;
    return true;
}

fn allocate_slot(process_id: usize, process_capability_slot: usize, state: ThreadState, entry_addr: usize, stack_base: usize): usize {
    if threads.count() >= max_threads {
        last_status = ThreadStatus.table_full;
        return invalid_id;
    }
    if !process_capability_authorizes(process_id, process_capability_slot) {
        return invalid_id;
    }
    const object_id = kernel_object.allocate(KernelObjectKind.thread);
    if object_id == kernel_object.invalid_id {
        last_status = ThreadStatus.object_allocation_failed;
        return invalid_id;
    }
    const capability_id = capability.mint(object_id, CapabilityRights.inspect | CapabilityRights.manage | CapabilityRights.duplicate);
    if capability_id == capability.invalid_id {
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
        last_status = ThreadStatus.capability_allocation_failed;
        return invalid_id;
    }
    const capability_slot = capability_space.install(process_id, capability_id);
    if capability_slot == capability_space.invalid_slot {
        if !capability.release(capability_id) {
            return invalid_id;
        }
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
        last_status = ThreadStatus.capability_space_failed;
        return invalid_id;
    }
    const id = threads.reserve();
    if id == invalid_id {
        if !capability_space.remove(process_id, capability_slot) {
            return invalid_id;
        }
        if !capability.release(capability_id) {
            return invalid_id;
        }
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
        last_status = ThreadStatus.table_full;
        return invalid_id;
    }
    threads.values[threads.index(id)] = Thread {
        id: id,
        object_id: object_id,
        capability_id: capability_id,
        capability_slot: capability_slot,
        process_id: process_id,
        state: state,
        entry_addr: entry_addr,
        stack_base: stack_base,
    };
    last_status = ThreadStatus.ok;
    return id;
}

pub fn create_kernel_bootstrap(process_id: usize, process_capability_slot: usize): usize {
    const id = allocate_slot(process_id, process_capability_slot, ThreadState.running, 0, 0);
    if id != invalid_id {
        current_id = id;
    }
    return id;
}

pub fn create_kernel_ready(process_id: usize, process_capability_slot: usize): usize {
    return allocate_slot(process_id, process_capability_slot, ThreadState.ready, 0, 0);
}

pub fn create_user_ready(process_id: usize, process_capability_slot: usize, entry_addr: usize, stack_base: usize): usize {
    if process.get(process_id).kind != ProcessKind.user {
        last_status = ThreadStatus.invalid_process;
        return invalid_id;
    }
    if entry_addr == 0 {
        last_status = ThreadStatus.invalid_entry;
        return invalid_id;
    }
    if stack_base == 0 {
        last_status = ThreadStatus.invalid_stack;
        return invalid_id;
    }
    return allocate_slot(process_id, process_capability_slot, ThreadState.ready, entry_addr, stack_base);
}

fn set_state(id: usize, state: ThreadState): bool {
    const index = index_for_id(id);
    if index >= max_threads {
        last_status = ThreadStatus.invalid_id;
        return false;
    }
    var entry = threads.values[index];
    entry.state = state;
    threads.values[index] = entry;
    last_status = ThreadStatus.ok;
    return true;
}

pub fn mark_ready(id: usize): bool {
    return set_state(id, ThreadState.ready);
}

pub fn mark_running(id: usize): bool {
    if !set_state(id, ThreadState.running) {
        return false;
    }
    current_id = id;
    return true;
}

pub fn mark_blocked(id: usize): bool {
    return set_state(id, ThreadState.blocked);
}

pub fn mark_dead(id: usize): bool {
    return set_state(id, ThreadState.dead);
}

pub fn get(id: usize): Thread {
    const index = index_for_id(id);
    if index >= max_threads {
        return empty_thread();
    }
    return threads.values[index];
}

pub fn count(): usize {
    return threads.count();
}

pub fn current(): usize {
    return current_id;
}

pub fn status(): ThreadStatus {
    return last_status;
}
