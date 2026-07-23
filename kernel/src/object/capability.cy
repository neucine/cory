import .collections.slot_map;
import { StaticSlotMap } from .collections.slot_map;
import .object.kernel_object;

pub const invalid_id: usize = slot_map.invalid_key;
pub const max_capabilities: usize = 64;

pub flags CapabilityRights: u16 {
    empty = 0,
    read = 1,
    write = 2,
    execute = 4,
    map = 8,
    send = 16,
    receive = 32,
    signal = 64,
    inspect = 128,
    manage = 256,
    configure = 512,
    transfer = 1024,
    duplicate = 2048,
    revoke = 4096,
}

pub enum CapabilityStatus: i32 {
    ok = 0,
    table_full,
    invalid_object,
    invalid_capability,
    invalid_rights,
    rights_exceed_source,
    missing_duplicate_right,
}

pub struct Capability {
    pub id: usize;
    pub object_id: usize;
    pub rights: CapabilityRights;
    pub live: bool;
    pub reserved: usize;
}

var capabilities: StaticSlotMap<Capability, 64> = StaticSlotMap<Capability, 64> {
    values: [Capability {
        id: invalid_id,
        object_id: kernel_object.invalid_id,
        rights: CapabilityRights.empty,
        live: false,
        reserved: 0,
    }] ** 64,
    live: [false] ** 64,
    generations: [0] ** 64,
    live_count: 0,
    last_status: slot_map.status_ok,
};
var last_status: CapabilityStatus = CapabilityStatus.ok;

fn all_rights(): CapabilityRights {
    return CapabilityRights.read | CapabilityRights.write | CapabilityRights.execute | CapabilityRights.map | CapabilityRights.send | CapabilityRights.receive | CapabilityRights.signal | CapabilityRights.inspect | CapabilityRights.manage | CapabilityRights.configure | CapabilityRights.transfer | CapabilityRights.duplicate | CapabilityRights.revoke;
}

fn empty_capability(): Capability {
    return Capability {
        id: invalid_id,
        object_id: kernel_object.invalid_id,
        rights: CapabilityRights.empty,
        live: false,
        reserved: 0,
    };
}

pub fn init(): void {
    capabilities.clear();
    var index: usize = 0;
    while index < max_capabilities {
        capabilities.values[index] = empty_capability();
        index = index + 1;
    }
    last_status = CapabilityStatus.ok;
}

fn rights_are_valid(rights: CapabilityRights): bool {
    if (rights as u16) == 0 {
        return false;
    }
    return ((rights | all_rights()) as u16) == (all_rights() as u16);
}

fn index_for_id(id: usize): usize {
    if id == invalid_id {
        return max_capabilities;
    }
    if !capabilities.contains(id) {
        return max_capabilities;
    }
    return capabilities.index(id);
}

fn allocate_slot(object_id: usize, rights: CapabilityRights): usize {
    const id = capabilities.reserve();
    if id == invalid_id {
        last_status = CapabilityStatus.table_full;
        return invalid_id;
    }

    capabilities.values[capabilities.index(id)] = Capability {
        id: id,
        object_id: object_id,
        rights: rights,
        live: true,
        reserved: 0,
    };
    last_status = CapabilityStatus.ok;
    return id;
}

pub fn mint(object_id: usize, rights: CapabilityRights): usize {
    if !kernel_object.is_live(object_id) {
        last_status = CapabilityStatus.invalid_object;
        return invalid_id;
    }
    if !rights_are_valid(rights) {
        last_status = CapabilityStatus.invalid_rights;
        return invalid_id;
    }
    if !kernel_object.retain(object_id) {
        last_status = CapabilityStatus.invalid_object;
        return invalid_id;
    }
    const id = allocate_slot(object_id, rights);
    if id == invalid_id {
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
    }
    return id;
}

pub fn mint_raw_rights(object_id: usize, rights: u16): usize {
    if rights == 0 {
        last_status = CapabilityStatus.invalid_rights;
        return invalid_id;
    }
    if (rights | (all_rights() as u16)) != (all_rights() as u16) {
        last_status = CapabilityStatus.invalid_rights;
        return invalid_id;
    }
    return mint(object_id, rights as CapabilityRights);
}

pub fn duplicate(source_id: usize, rights: CapabilityRights): usize {
    const index = index_for_id(source_id);
    if index >= max_capabilities {
        last_status = CapabilityStatus.invalid_capability;
        return invalid_id;
    }
    const source = capabilities.values[index];
    if ((source.rights & CapabilityRights.duplicate) as u16) == 0 {
        last_status = CapabilityStatus.missing_duplicate_right;
        return invalid_id;
    }
    if !rights_are_valid(rights) {
        last_status = CapabilityStatus.invalid_rights;
        return invalid_id;
    }
    if ((rights | source.rights) as u16) != (source.rights as u16) {
        last_status = CapabilityStatus.rights_exceed_source;
        return invalid_id;
    }
    return mint(source.object_id, rights);
}

pub fn release(id: usize): bool {
    const index = index_for_id(id);
    if index >= max_capabilities {
        last_status = CapabilityStatus.invalid_capability;
        return false;
    }
    const object_id = capabilities.values[index].object_id;
    capabilities.values[index] = empty_capability();
    if capabilities.remove(id) is _ {
    } else {
        last_status = CapabilityStatus.invalid_capability;
        return false;
    }
    if !kernel_object.release(object_id) {
        last_status = CapabilityStatus.invalid_object;
        return false;
    }
    last_status = CapabilityStatus.ok;
    return true;
}

pub fn get(id: usize): Capability {
    const index = index_for_id(id);
    if index >= max_capabilities {
        return empty_capability();
    }
    return capabilities.values[index];
}

pub fn has_rights(id: usize, rights: CapabilityRights): bool {
    const index = index_for_id(id);
    if index >= max_capabilities {
        last_status = CapabilityStatus.invalid_capability;
        return false;
    }
    if !rights_are_valid(rights) {
        last_status = CapabilityStatus.invalid_rights;
        return false;
    }
    last_status = CapabilityStatus.ok;
    return ((rights | capabilities.values[index].rights) as u16) == (capabilities.values[index].rights as u16);
}

pub fn can_transfer(id: usize): bool {
    return has_rights(id, CapabilityRights.transfer);
}

pub fn can_duplicate(id: usize): bool {
    return has_rights(id, CapabilityRights.duplicate);
}

pub fn count(): usize {
    return capabilities.count();
}

pub fn status(): CapabilityStatus {
    return last_status;
}
