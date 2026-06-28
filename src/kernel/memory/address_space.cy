import { Spec } from .kernel.memory.page_table;
import .kernel.memory.vm;

pub const invalid_id: usize = 0;
pub const max_address_spaces: usize = 8;

pub const kind_empty: i32 = 0;
pub const kind_kernel: i32 = 1;
pub const kind_user: i32 = 2;

pub const status_ok: i32 = 0;
pub const status_table_full: i32 = 1;
pub const status_invalid_bootstrap_plan: i32 = 2;
pub const status_invalid_id: i32 = 3;
pub const status_root_unallocated: i32 = 4;

pub struct AddressSpace {
    pub id: usize;
    pub kind: i32;
    pub root_table: usize;
    pub user_base: usize;
    pub user_end: usize;
    pub kernel_base: usize;
    pub kernel_heap_base: usize;
    pub kernel_heap_end: usize;
    pub active: bool;
}

var ids: [8]usize = [0, 0, 0, 0, 0, 0, 0, 0];
var kinds: [8]i32 = [kind_empty, kind_empty, kind_empty, kind_empty, kind_empty, kind_empty, kind_empty, kind_empty];
var root_tables: [8]usize = [0, 0, 0, 0, 0, 0, 0, 0];
var user_bases: [8]usize = [0, 0, 0, 0, 0, 0, 0, 0];
var user_ends: [8]usize = [0, 0, 0, 0, 0, 0, 0, 0];
var kernel_bases: [8]usize = [0, 0, 0, 0, 0, 0, 0, 0];
var kernel_heap_bases: [8]usize = [0, 0, 0, 0, 0, 0, 0, 0];
var kernel_heap_ends: [8]usize = [0, 0, 0, 0, 0, 0, 0, 0];
var active_flags: [8]bool = [false, false, false, false, false, false, false, false];
var used_slots: usize = 0;
var next_id: usize = 1;
var current_id: usize = invalid_id;
var last_status: i32 = status_ok;

fn empty_address_space(): AddressSpace {
    return AddressSpace {
        id: invalid_id,
        kind: kind_empty,
        root_table: 0,
        user_base: 0,
        user_end: 0,
        kernel_base: 0,
        kernel_heap_base: 0,
        kernel_heap_end: 0,
        active: false,
    };
}

pub fn init(): void {
    var index: usize = 0;
    while index < max_address_spaces {
        ids[index] = invalid_id;
        kinds[index] = kind_empty;
        root_tables[index] = 0;
        user_bases[index] = 0;
        user_ends[index] = 0;
        kernel_bases[index] = 0;
        kernel_heap_bases[index] = 0;
        kernel_heap_ends[index] = 0;
        active_flags[index] = false;
        index = index + 1;
    }
    used_slots = 0;
    next_id = 1;
    current_id = invalid_id;
    last_status = status_ok;
}

fn index_for_id(id: usize): usize {
    var index: usize = 0;
    while index < used_slots {
        if ids[index] == id {
            return index;
        }
        index = index + 1;
    }
    return max_address_spaces;
}

fn write_slot(index: usize, id: usize, kind: i32, root: usize, user_base: usize, user_end: usize, kernel_base: usize, heap_base: usize, heap_end: usize, active: bool): void {
    ids[index] = id;
    kinds[index] = kind;
    root_tables[index] = root;
    user_bases[index] = user_base;
    user_ends[index] = user_end;
    kernel_bases[index] = kernel_base;
    kernel_heap_bases[index] = heap_base;
    kernel_heap_ends[index] = heap_end;
    active_flags[index] = active;
}

fn allocate_slot(kind: i32, root: usize, user_base: usize, user_end: usize, kernel_base: usize, heap_base: usize, heap_end: usize, active: bool): usize {
    if used_slots >= max_address_spaces {
        last_status = status_table_full;
        return invalid_id;
    }
    const id = next_id;
    next_id = next_id + 1;
    write_slot(used_slots, id, kind, root, user_base, user_end, kernel_base, heap_base, heap_end, active);
    used_slots = used_slots + 1;
    last_status = status_ok;
    return id;
}

pub fn create_kernel_bootstrap(root_table: usize, user_base: usize, user_end: usize, kernel_base: usize, heap_base: usize, heap_end: usize): usize {
    if root_table == 0 {
        last_status = status_invalid_bootstrap_plan;
        return invalid_id;
    }
    if kernel_base == 0 {
        last_status = status_invalid_bootstrap_plan;
        return invalid_id;
    }
    if user_end <= user_base {
        last_status = status_invalid_bootstrap_plan;
        return invalid_id;
    }
    const id = allocate_slot(kind_kernel, root_table, user_base, user_end, kernel_base, heap_base, heap_end, true);
    if id != invalid_id {
        current_id = id;
    }
    return id;
}

pub fn create_user_draft(spec: Spec): usize {
    return allocate_slot(kind_user, 0, vm.user_virtual_base_for_spec(spec), vm.user_virtual_end_for_spec(spec), vm.kernel_virtual_base_for_spec(spec), vm.kernel_heap_virtual_base_for_spec(spec), vm.kernel_heap_virtual_end_for_spec(spec), false);
}

pub fn get(id: usize): AddressSpace {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        return empty_address_space();
    }
    return AddressSpace {
        id: ids[index],
        kind: kinds[index],
        root_table: root_tables[index],
        user_base: user_bases[index],
        user_end: user_ends[index],
        kernel_base: kernel_bases[index],
        kernel_heap_base: kernel_heap_bases[index],
        kernel_heap_end: kernel_heap_ends[index],
        active: active_flags[index],
    };
}

pub fn count(): usize {
    return used_slots;
}

pub fn current(): usize {
    return current_id;
}

pub fn status(): i32 {
    return last_status;
}

pub fn kind(id: usize): i32 {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return kind_empty;
    }
    return kinds[index];
}

pub fn root_table(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return 0;
    }
    return root_tables[index];
}

pub fn user_base(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return 0;
    }
    return user_bases[index];
}

pub fn user_end(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return 0;
    }
    return user_ends[index];
}

pub fn kernel_base(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return 0;
    }
    return kernel_bases[index];
}

pub fn kernel_heap_base(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return 0;
    }
    return kernel_heap_bases[index];
}

pub fn kernel_heap_end(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return 0;
    }
    return kernel_heap_ends[index];
}

pub fn active(id: usize): bool {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return false;
    }
    return active_flags[index];
}

pub fn has_root(id: usize): bool {
    return root_table(id) != 0;
}

pub fn can_map_user_page(id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return false;
    }
    if kinds[index] != kind_user {
        return false;
    }
    if root_tables[index] == 0 {
        last_status = status_root_unallocated;
        return false;
    }
    return vm.validate_user_page_mapping(virt, phys, rights, spec);
}

pub fn accepts_user_mapping_policy(id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return false;
    }
    if kinds[index] != kind_user {
        return false;
    }
    return vm.validate_user_page_mapping(virt, phys, rights, spec);
}

pub fn can_map_kernel_page(id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = status_invalid_id;
        return false;
    }
    if kinds[index] != kind_kernel {
        return false;
    }
    if root_tables[index] == 0 {
        last_status = status_root_unallocated;
        return false;
    }
    return vm.validate_kernel_page_mapping(virt, phys, rights, spec);
}
