import .kernel.collections.slot_map;
import { StaticSlotMap } from .kernel.collections.slot_map;
import .kernel.memory.address_space;
import { AddressSpaceKind } from .kernel.memory.address_space;
import .kernel.object.capability;
import { CapabilityRights } from .kernel.object.capability;
import .kernel.object.kernel_object;
import { KernelObjectKind } from .kernel.object.kernel_object;
import .kernel.task.capability_space;

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
}

var processes: StaticSlotMap<[8]Process> = StaticSlotMap<[8]Process> {
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

fn address_space_capability_authorizes(address_space_id: usize, cap_id: usize): bool {
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
    if !capability.has_rights(cap_id, CapabilityRights.inspect | CapabilityRights.manage | CapabilityRights.duplicate) {
        last_status = ProcessStatus.capability_right_missing;
        return false;
    }
    last_status = ProcessStatus.ok;
    return true;
}

fn allocate_slot(kind: ProcessKind, address_space_id: usize, source_address_space_capability_id: usize, active: bool): usize {
    if processes.count() >= max_processes {
        last_status = ProcessStatus.table_full;
        return invalid_id;
    }
    if !address_space_capability_authorizes(address_space_id, source_address_space_capability_id) {
        return invalid_id;
    }
    const address_space_capability_id = capability.duplicate(source_address_space_capability_id, CapabilityRights.inspect | CapabilityRights.manage);
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

pub fn current(): usize {
    return current_id;
}

pub fn status(): ProcessStatus {
    return last_status;
}
