import .kernel.collections.slot_map;
import { StaticSlotMap } from .kernel.collections.slot_map;

pub const invalid_id: usize = slot_map.invalid_key;
pub const max_objects: usize = 32;

pub enum KernelObjectKind: i32 {
    empty = 0,
    address_space,
    process,
    thread,
    channel,
    event,
    shared_buffer,
    device,
}

pub enum KernelObjectStatus: i32 {
    ok = 0,
    table_full,
    invalid_kind,
    invalid_id,
    refcount_overflow,
}

pub struct KernelObject {
    pub id: usize;
    pub kind: KernelObjectKind;
    pub ref_count: usize;
    pub live: bool;
}

var objects: StaticSlotMap<[32]KernelObject> = StaticSlotMap<[32]KernelObject> {
    values: [KernelObject {
        id: invalid_id,
        kind: KernelObjectKind.empty,
        ref_count: 0,
        live: false,
    }] ** 32,
    live: [false] ** 32,
    generations: [0] ** 32,
    live_count: 0,
    last_status: slot_map.status_ok,
};
var last_status: KernelObjectStatus = KernelObjectStatus.ok;

fn empty_object(): KernelObject {
    return KernelObject {
        id: invalid_id,
        kind: KernelObjectKind.empty,
        ref_count: 0,
        live: false,
    };
}

pub fn init(): void {
    objects.clear();
    var index: usize = 0;
    while index < max_objects {
        objects.values[index] = empty_object();
        index = index + 1;
    }
    last_status = KernelObjectStatus.ok;
}

fn is_allocatable_kind(kind: KernelObjectKind): bool {
    return kind != KernelObjectKind.empty;
}

fn index_for_id(id: usize): usize {
    if id == invalid_id {
        return max_objects;
    }
    if !objects.contains(id) {
        return max_objects;
    }
    return objects.index(id);
}

pub fn allocate(kind: KernelObjectKind): usize {
    if !is_allocatable_kind(kind) {
        last_status = KernelObjectStatus.invalid_kind;
        return invalid_id;
    }

    const id = objects.reserve();
    if id == invalid_id {
        last_status = KernelObjectStatus.table_full;
        return invalid_id;
    }

    objects.values[objects.index(id)] = KernelObject {
        id: id,
        kind: kind,
        ref_count: 1,
        live: true,
    };
    last_status = KernelObjectStatus.ok;
    return id;
}

pub fn allocate_raw_kind(kind: i32): usize {
    const first = KernelObjectKind.address_space as i32;
    const last = KernelObjectKind.device as i32;
    if kind < first or kind > last {
        last_status = KernelObjectStatus.invalid_kind;
        return invalid_id;
    }
    return allocate(kind as KernelObjectKind);
}

pub fn retain(id: usize): bool {
    const index = index_for_id(id);
    if index >= max_objects {
        last_status = KernelObjectStatus.invalid_id;
        return false;
    }
    var entry = objects.values[index];
    if entry.ref_count == 0 - 1 {
        last_status = KernelObjectStatus.refcount_overflow;
        return false;
    }
    entry.ref_count = entry.ref_count + 1;
    objects.values[index] = entry;
    last_status = KernelObjectStatus.ok;
    return true;
}

pub fn release(id: usize): bool {
    const index = index_for_id(id);
    if index >= max_objects {
        last_status = KernelObjectStatus.invalid_id;
        return false;
    }
    var entry = objects.values[index];
    if entry.ref_count == 0 {
        last_status = KernelObjectStatus.invalid_id;
        return false;
    }
    entry.ref_count = entry.ref_count - 1;
    if entry.ref_count == 0 {
        objects.values[index] = empty_object();
        if objects.remove(id) is _ {
        } else {
            last_status = KernelObjectStatus.invalid_id;
            return false;
        }
    } else {
        objects.values[index] = entry;
    }
    last_status = KernelObjectStatus.ok;
    return true;
}

pub fn get(id: usize): KernelObject {
    const index = index_for_id(id);
    if index >= max_objects {
        return empty_object();
    }
    return objects.values[index];
}

pub fn is_live(id: usize): bool {
    return index_for_id(id) < max_objects;
}

pub fn count(): usize {
    return objects.count();
}

pub fn status(): KernelObjectStatus {
    return last_status;
}
