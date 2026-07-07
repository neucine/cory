import .kernel.collections.slot_map;
import .kernel.object.capability;
import { CapabilityRights } from .kernel.object.capability;

pub const invalid_slot: usize = 0 - 1;
pub const max_owners: usize = 8;
pub const slots_per_owner: usize = 16;
pub const max_slots: usize = 128;

pub enum CapabilitySpaceStatus: i32 {
    ok = 0,
    invalid_owner,
    invalid_slot,
    table_full,
    invalid_capability,
}

pub struct CapabilityOwner {
    pub owner_id: usize;
    pub count: usize;
    pub slots: [16]usize;
}

var owners: [8]CapabilityOwner = [CapabilityOwner {
    owner_id: slot_map.invalid_key,
    count: 0,
    slots: [capability.invalid_id] ** 16,
}] ** 8;
var last_status: CapabilitySpaceStatus = CapabilitySpaceStatus.ok;

fn empty_owner(): CapabilityOwner {
    return CapabilityOwner {
        owner_id: slot_map.invalid_key,
        count: 0,
        slots: [capability.invalid_id] ** 16,
    };
}

pub fn init(): void {
    var index: usize = 0;
    while index < max_owners {
        owners[index] = empty_owner();
        index = index + 1;
    }
    last_status = CapabilitySpaceStatus.ok;
}

fn owner_index(owner_id: usize): usize {
    const index = slot_map.index(max_owners, owner_id);
    if index >= max_owners {
        return max_owners;
    }
    return index;
}

fn owner_is_valid(owner: usize, owner_id: usize): bool {
    if owner >= max_owners {
        return false;
    }
    return owners[owner].owner_id == owner_id;
}

fn clear_slot(owner: usize, slot: usize): void {
    var entry = owners[owner];
    entry.slots[slot] = capability.invalid_id;
    entry.count = entry.count - 1;
    if entry.count == 0 {
        entry.owner_id = slot_map.invalid_key;
    }
    owners[owner] = entry;
}

pub fn install(owner_id: usize, capability_id: usize): usize {
    const owner = owner_index(owner_id);
    if owner >= max_owners {
        last_status = CapabilitySpaceStatus.invalid_owner;
        return invalid_slot;
    }
    var entry = owners[owner];
    if entry.owner_id == slot_map.invalid_key {
        entry.owner_id = owner_id;
    } else if entry.owner_id != owner_id {
        last_status = CapabilitySpaceStatus.invalid_owner;
        return invalid_slot;
    }
    if !capability.get(capability_id).live {
        last_status = CapabilitySpaceStatus.invalid_capability;
        return invalid_slot;
    }
    var slot: usize = 0;
    while slot < slots_per_owner {
        if entry.slots[slot] == capability.invalid_id {
            entry.slots[slot] = capability_id;
            entry.count = entry.count + 1;
            owners[owner] = entry;
            last_status = CapabilitySpaceStatus.ok;
            return slot;
        }
        slot = slot + 1;
    }
    last_status = CapabilitySpaceStatus.table_full;
    return invalid_slot;
}

pub fn get(owner_id: usize, slot: usize): usize {
    if slot >= slots_per_owner {
        last_status = CapabilitySpaceStatus.invalid_slot;
        return capability.invalid_id;
    }
    const owner = owner_index(owner_id);
    if !owner_is_valid(owner, owner_id) {
        last_status = CapabilitySpaceStatus.invalid_owner;
        return capability.invalid_id;
    }
    const capability_id = owners[owner].slots[slot];
    if capability_id == capability.invalid_id {
        last_status = CapabilitySpaceStatus.invalid_slot;
        return capability.invalid_id;
    }
    if !capability.get(capability_id).live {
        clear_slot(owner, slot);
        last_status = CapabilitySpaceStatus.invalid_capability;
        return capability.invalid_id;
    }
    last_status = CapabilitySpaceStatus.ok;
    return capability_id;
}

pub fn remove(owner_id: usize, slot: usize): bool {
    if slot >= slots_per_owner {
        last_status = CapabilitySpaceStatus.invalid_slot;
        return false;
    }
    const owner = owner_index(owner_id);
    if !owner_is_valid(owner, owner_id) {
        last_status = CapabilitySpaceStatus.invalid_owner;
        return false;
    }
    if owners[owner].slots[slot] == capability.invalid_id {
        last_status = CapabilitySpaceStatus.invalid_slot;
        return false;
    }
    clear_slot(owner, slot);
    last_status = CapabilitySpaceStatus.ok;
    return true;
}

pub fn clear_owner(owner_id: usize): bool {
    const owner = owner_index(owner_id);
    if !owner_is_valid(owner, owner_id) {
        last_status = CapabilitySpaceStatus.invalid_owner;
        return false;
    }
    var slot: usize = 0;
    var entry = owners[owner];
    while slot < slots_per_owner {
        entry.slots[slot] = capability.invalid_id;
        slot = slot + 1;
    }
    entry.count = 0;
    entry.owner_id = slot_map.invalid_key;
    owners[owner] = entry;
    last_status = CapabilitySpaceStatus.ok;
    return true;
}

pub fn has_rights(owner_id: usize, slot: usize, rights: CapabilityRights): bool {
    const capability_id = get(owner_id, slot);
    if capability_id == capability.invalid_id {
        return false;
    }
    return capability.has_rights(capability_id, rights);
}

pub fn count(owner_id: usize): usize {
    const owner = owner_index(owner_id);
    if !owner_is_valid(owner, owner_id) {
        last_status = CapabilitySpaceStatus.invalid_owner;
        return 0;
    }
    last_status = CapabilitySpaceStatus.ok;
    return owners[owner].count;
}

pub fn status(): CapabilitySpaceStatus {
    return last_status;
}
