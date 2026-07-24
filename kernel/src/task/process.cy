import .collections.slot_map;
import { StaticSlotMap } from .collections.slot_map;
import .memory.address_space;
import .console;
import { AddressSpaceKind } from .memory.address_space;
import .object.capability;
import { CapabilityRights } from .object.capability;
import .object.kernel_object;
import { KernelObjectKind } from .object.kernel_object;
import .task.capability_space;

pub const invalid_id: usize = slot_map.invalid_key;
pub const max_processes: usize = 8;

pub enum ProcessKind: i32 {
    empty = 0,
    kernel,
    user,
}

pub enum ProcessStatus: i32 {
    ok = 0,
    table_full,
    invalid_address_space,
    invalid_capability,
    capability_object_mismatch,
    capability_right_missing,
    object_allocation_failed,
    capability_allocation_failed,
    address_space_capability_failed,
    capability_space_failed,
    invalid_id,
    active_process,
    address_space_root_missing,
    already_active,
    not_exited,
}

pub struct Process {
    pub id: usize;
    pub object_id: usize;
    pub capability_id: usize;
    pub capability_slot: usize;
    pub address_space_id: usize;
    pub address_space_capability_id: usize;
    pub address_space_capability_slot: usize;
    pub kind: ProcessKind;
    pub active: bool;
    pub exited: bool;
    pub exit_code: usize;
}

var processes: StaticSlotMap<Process, 8> = StaticSlotMap<Process, 8> {
    values: [Process {
        id: invalid_id,
        object_id: kernel_object.invalid_id,
        capability_id: capability.invalid_id,
        capability_slot: capability_space.invalid_slot,
        address_space_id: address_space.invalid_id,
        address_space_capability_id: capability.invalid_id,
        address_space_capability_slot: capability_space.invalid_slot,
        kind: ProcessKind.empty,
        active: false,
        exited: false,
        exit_code: 0,
    }] ** 8,
    live: [false] ** 8,
    generations: [0] ** 8,
    live_count: 0,
    last_status: slot_map.status_ok,
};
var current_id: usize = invalid_id;
var last_status: ProcessStatus = ProcessStatus.ok;

fn empty_process(): Process {
    return Process {
        id: invalid_id,
        object_id: kernel_object.invalid_id,
        capability_id: capability.invalid_id,
        capability_slot: capability_space.invalid_slot,
        address_space_id: address_space.invalid_id,
        address_space_capability_id: capability.invalid_id,
        address_space_capability_slot: capability_space.invalid_slot,
        kind: ProcessKind.empty,
        active: false,
        exited: false,
        exit_code: 0,
    };
}

pub fn init(): void {
    processes.clear();
    var index: usize = 0;
    while index < max_processes {
        processes.values[index] = empty_process();
        index = index + 1;
    }
    current_id = invalid_id;
    last_status = ProcessStatus.ok;
}

fn index_for_id(id: usize): usize {
    if id == invalid_id {
        return max_processes;
    }
    if !processes.contains(id) {
        return max_processes;
    }
    return processes.index(id);
}

fn address_space_capability_authorizes(address_space_id: usize, cap_id: usize, required_rights: CapabilityRights): bool {
    const address_space_object_id = address_space.object_id(address_space_id);
    if address_space_object_id == kernel_object.invalid_id {
        last_status = ProcessStatus.invalid_address_space;
        return false;
    }
    const cap = capability.get(cap_id);
    if !cap.live {
        last_status = ProcessStatus.invalid_capability;
        return false;
    }
    if cap.object_id != address_space_object_id {
        last_status = ProcessStatus.capability_object_mismatch;
        return false;
    }
    if !capability.has_rights(cap_id, required_rights | CapabilityRights.duplicate) {
        last_status = ProcessStatus.capability_right_missing;
        return false;
    }
    last_status = ProcessStatus.ok;
    return true;
}

fn address_space_rights_for_process_kind(kind: ProcessKind): CapabilityRights {
    if kind == ProcessKind.user {
        return CapabilityRights.inspect | CapabilityRights.map;
    }
    return CapabilityRights.inspect | CapabilityRights.manage;
}

fn allocate_slot(kind: ProcessKind, address_space_id: usize, source_address_space_capability_id: usize, active: bool): usize {
    if processes.count() >= max_processes {
        last_status = ProcessStatus.table_full;
        return invalid_id;
    }
    const address_space_rights = address_space_rights_for_process_kind(kind);
    if !address_space_capability_authorizes(address_space_id, source_address_space_capability_id, address_space_rights) {
        return invalid_id;
    }
    const address_space_capability_id = capability.duplicate(source_address_space_capability_id, address_space_rights);
    if address_space_capability_id == capability.invalid_id {
        last_status = ProcessStatus.address_space_capability_failed;
        return invalid_id;
    }
    const object_id = kernel_object.allocate(KernelObjectKind.process);
    if object_id == kernel_object.invalid_id {
        if !capability.release(address_space_capability_id) {
            return invalid_id;
        }
        last_status = ProcessStatus.object_allocation_failed;
        return invalid_id;
    }
    const capability_id = capability.mint(object_id, CapabilityRights.inspect | CapabilityRights.manage | CapabilityRights.duplicate);
    if capability_id == capability.invalid_id {
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
        if !capability.release(address_space_capability_id) {
            return invalid_id;
        }
        last_status = ProcessStatus.capability_allocation_failed;
        return invalid_id;
    }

    const id = processes.reserve();
    if id == invalid_id {
        if !capability.release(capability_id) {
            return invalid_id;
        }
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
        if !capability.release(address_space_capability_id) {
            return invalid_id;
        }
        last_status = ProcessStatus.table_full;
        return invalid_id;
    }
    const process_capability_slot = capability_space.install(id, capability_id);
    if process_capability_slot == capability_space.invalid_slot {
        if processes.remove(id) is _ {
        } else {
            return invalid_id;
        }
        if !capability.release(capability_id) {
            return invalid_id;
        }
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
        if !capability.release(address_space_capability_id) {
            return invalid_id;
        }
        last_status = ProcessStatus.capability_space_failed;
        return invalid_id;
    }
    const address_space_capability_slot = capability_space.install(id, address_space_capability_id);
    if address_space_capability_slot == capability_space.invalid_slot {
        if !capability_space.remove(id, process_capability_slot) {
            return invalid_id;
        }
        if processes.remove(id) is _ {
        } else {
            return invalid_id;
        }
        if !capability.release(capability_id) {
            return invalid_id;
        }
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
        if !capability.release(address_space_capability_id) {
            return invalid_id;
        }
        last_status = ProcessStatus.capability_space_failed;
        return invalid_id;
    }
    processes.values[processes.index(id)] = Process {
        id: id,
        object_id: object_id,
        capability_id: capability_id,
        capability_slot: process_capability_slot,
        address_space_id: address_space_id,
        address_space_capability_id: address_space_capability_id,
        address_space_capability_slot: address_space_capability_slot,
        kind: kind,
        active: active,
        exited: false,
        exit_code: 0,
    };
    last_status = ProcessStatus.ok;
    return id;
}

pub fn create_kernel_bootstrap(address_space_id: usize, address_space_capability_id: usize): usize {
    if address_space.kind(address_space_id) != AddressSpaceKind.kernel {
        last_status = ProcessStatus.invalid_address_space;
        return invalid_id;
    }
    const id = allocate_slot(ProcessKind.kernel, address_space_id, address_space_capability_id, true);
    if id != invalid_id {
        current_id = id;
    }
    return id;
}

pub fn create_kernel_inactive(address_space_id: usize, address_space_capability_id: usize): usize {
    if address_space.kind(address_space_id) != AddressSpaceKind.kernel {
        last_status = ProcessStatus.invalid_address_space;
        return invalid_id;
    }
    return allocate_slot(ProcessKind.kernel, address_space_id, address_space_capability_id, false);
}

pub fn create_user_inactive(address_space_id: usize, address_space_capability_id: usize): usize {
    if address_space.kind(address_space_id) != AddressSpaceKind.user {
        last_status = ProcessStatus.invalid_address_space;
        return invalid_id;
    }
    if !address_space.has_root(address_space_id) {
        last_status = ProcessStatus.address_space_root_missing;
        return invalid_id;
    }
    return allocate_slot(ProcessKind.user, address_space_id, address_space_capability_id, false);
}

pub fn release(id: usize): bool {
    const index = index_for_id(id);
    if index >= max_processes {
        last_status = ProcessStatus.invalid_id;
        return false;
    }
    const entry = processes.values[index];
    if entry.active {
        last_status = ProcessStatus.active_process;
        return false;
    }
    const object_id = entry.object_id;
    const capability_id = entry.capability_id;
    const address_space_capability_id = entry.address_space_capability_id;
    if !capability_space.clear_owner(id) {
        last_status = ProcessStatus.capability_space_failed;
        return false;
    }
    if !capability.release(capability_id) {
        last_status = ProcessStatus.invalid_capability;
        return false;
    }
    if !capability.release(address_space_capability_id) {
        last_status = ProcessStatus.invalid_capability;
        return false;
    }
    if !kernel_object.release(object_id) {
        last_status = ProcessStatus.invalid_id;
        return false;
    }
    processes.values[index] = empty_process();
    if processes.remove(id) is _ {
    } else {
        last_status = ProcessStatus.invalid_id;
        return false;
    }
    if current_id == id {
        current_id = invalid_id;
    }
    last_status = ProcessStatus.ok;
    return true;
}

pub fn mark_active(id: usize): bool {
    const index = index_for_id(id);
    if index >= max_processes {
        last_status = ProcessStatus.invalid_id;
        return false;
    }
    if processes.values[index].active {
        last_status = ProcessStatus.already_active;
        return false;
    }
    var entry = processes.values[index];
    entry.active = true;
    entry.exited = false;
    entry.exit_code = 0;
    processes.values[index] = entry;
    last_status = ProcessStatus.ok;
    return true;
}

pub fn mark_inactive(id: usize): bool {
    const index = index_for_id(id);
    if index >= max_processes {
        last_status = ProcessStatus.invalid_id;
        return false;
    }
    var entry = processes.values[index];
    entry.active = false;
    processes.values[index] = entry;
    last_status = ProcessStatus.ok;
    return true;
}

pub fn mark_exited(id: usize, exit_code: usize): bool {
    const index = index_for_id(id);
    if index >= max_processes {
        last_status = ProcessStatus.invalid_id;
        return false;
    }
    var entry = processes.values[index];
    entry.active = false;
    entry.exited = true;
    entry.exit_code = exit_code;
    processes.values[index] = entry;
    last_status = ProcessStatus.ok;
    return true;
}

pub fn wait_exit_code(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_processes {
        last_status = ProcessStatus.invalid_id;
        return 0;
    }
    const entry = processes.values[index];
    if !entry.exited {
        last_status = ProcessStatus.not_exited;
        return 0;
    }
    last_status = ProcessStatus.ok;
    return entry.exit_code;
}

pub fn reap_exited(id: usize): usize {
    const code = wait_exit_code(id);
    if last_status != ProcessStatus.ok {
        return 0;
    }
    if !release(id) {
        return 0;
    }
    last_status = ProcessStatus.ok;
    return code;
}

pub fn get(id: usize): Process {
    const index = index_for_id(id);
    if index >= max_processes {
        return empty_process();
    }
    return processes.values[index];
}

pub fn count(): usize {
    return processes.count();
}

fn print_kind(kind: ProcessKind): void {
    if kind == ProcessKind.kernel {
        println("ps: kind kernel");
        return;
    }
    if kind == ProcessKind.user {
        println("ps: kind user");
        return;
    }
    println("ps: kind empty");
}

fn print_state(entry: Process): void {
    if entry.exited {
        println("ps: state exited");
        return;
    }
    if entry.active {
        println("ps: state active");
        return;
    }
    println("ps: state inactive");
}

pub fn print_table(): usize {
    println("ps: process table");
    var printed: usize = 0;
    var index: usize = 0;
    while index < max_processes {
        if processes.live[index] {
            const entry = processes.values[index];
            println("ps: pid");
            console.print_hex(entry.id);
            console.putc(10);
            print_kind(entry.kind);
            print_state(entry);
            printed = printed + 1;
        }
        index = index + 1;
    }
    last_status = ProcessStatus.ok;
    return printed;
}

pub fn current(): usize {
    return current_id;
}

pub fn status(): ProcessStatus {
    return last_status;
}
