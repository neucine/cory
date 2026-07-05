import .kernel.collections.slot_map;
import { StaticSlotMap } from .kernel.collections.slot_map;
import { Spec } from .kernel.memory.page_table;
import .kernel.memory.vm;
import .kernel.object.capability;
import { CapabilityRights } from .kernel.object.capability;
import .kernel.object.kernel_object;
import { KernelObjectKind } from .kernel.object.kernel_object;

pub const invalid_id: usize = slot_map.invalid_key;
pub const max_address_spaces: usize = 8;

pub enum AddressSpaceKind: i32 {
    empty = 0,
    kernel,
    user,
}

pub enum AddressSpaceStatus: i32 {
    ok = 0,
    table_full,
    invalid_bootstrap_plan,
    invalid_id,
    root_unallocated,
    object_allocation_failed,
    capability_allocation_failed,
    invalid_capability,
    capability_object_mismatch,
    capability_right_missing,
}

pub struct AddressSpace {
    pub id: usize;
    pub object_id: usize;
    pub capability_id: usize;
    pub kind: AddressSpaceKind;
    pub root_table: usize;
    pub user_base: usize;
    pub user_end: usize;
    pub kernel_base: usize;
    pub kernel_heap_base: usize;
    pub kernel_heap_end: usize;
    pub active: bool;
}

var spaces: StaticSlotMap<[8]AddressSpace> = StaticSlotMap<[8]AddressSpace> {
    values: [AddressSpace {
        id: invalid_id,
        object_id: kernel_object.invalid_id,
        capability_id: capability.invalid_id,
        kind: AddressSpaceKind.empty,
        root_table: 0,
        user_base: 0,
        user_end: 0,
        kernel_base: 0,
        kernel_heap_base: 0,
        kernel_heap_end: 0,
        active: false,
    }] ** 8,
    live: [false] ** 8,
    generations: [0] ** 8,
    live_count: 0,
    last_status: slot_map.status_ok,
};
var current_id: usize = invalid_id;
var last_status: AddressSpaceStatus = AddressSpaceStatus.ok;

fn empty_address_space(): AddressSpace {
    return AddressSpace {
        id: invalid_id,
        object_id: kernel_object.invalid_id,
        capability_id: capability.invalid_id,
        kind: AddressSpaceKind.empty,
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
    spaces.clear();
    var index: usize = 0;
    while index < max_address_spaces {
        spaces.values[index] = empty_address_space();
        index = index + 1;
    }
    current_id = invalid_id;
    last_status = AddressSpaceStatus.ok;
}

fn index_for_id(id: usize): usize {
    if id == invalid_id {
        return max_address_spaces;
    }
    if !spaces.contains(id) {
        return max_address_spaces;
    }
    return spaces.index(id);
}

fn rights_for_kind(kind: AddressSpaceKind): CapabilityRights {
    if kind == AddressSpaceKind.kernel {
        return CapabilityRights.map | CapabilityRights.inspect | CapabilityRights.manage | CapabilityRights.duplicate;
    }
    return CapabilityRights.map | CapabilityRights.inspect | CapabilityRights.duplicate;
}

fn allocate_slot(kind: AddressSpaceKind, root: usize, user_base: usize, user_end: usize, kernel_base: usize, heap_base: usize, heap_end: usize, active: bool): usize {
    if spaces.count() >= max_address_spaces {
        last_status = AddressSpaceStatus.table_full;
        return invalid_id;
    }
    const object_id = kernel_object.allocate(KernelObjectKind.address_space);
    if object_id == kernel_object.invalid_id {
        last_status = AddressSpaceStatus.object_allocation_failed;
        return invalid_id;
    }
    const capability_id = capability.mint(object_id, rights_for_kind(kind));
    if capability_id == capability.invalid_id {
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
        last_status = AddressSpaceStatus.capability_allocation_failed;
        return invalid_id;
    }
    const id = spaces.reserve();
    if id == invalid_id {
        if !capability.release(capability_id) {
            return invalid_id;
        }
        if !kernel_object.release(object_id) {
            return invalid_id;
        }
        last_status = AddressSpaceStatus.table_full;
        return invalid_id;
    }
    spaces.values[spaces.index(id)] = AddressSpace {
        id: id,
        object_id: object_id,
        capability_id: capability_id,
        kind: kind,
        root_table: root,
        user_base: user_base,
        user_end: user_end,
        kernel_base: kernel_base,
        kernel_heap_base: heap_base,
        kernel_heap_end: heap_end,
        active: active,
    };
    last_status = AddressSpaceStatus.ok;
    return id;
}

pub fn create_kernel_bootstrap(root_table: usize, user_base: usize, user_end: usize, kernel_base: usize, heap_base: usize, heap_end: usize): usize {
    if root_table == 0 {
        last_status = AddressSpaceStatus.invalid_bootstrap_plan;
        return invalid_id;
    }
    if kernel_base == 0 {
        last_status = AddressSpaceStatus.invalid_bootstrap_plan;
        return invalid_id;
    }
    if user_end <= user_base {
        last_status = AddressSpaceStatus.invalid_bootstrap_plan;
        return invalid_id;
    }
    const id = allocate_slot(AddressSpaceKind.kernel, root_table, user_base, user_end, kernel_base, heap_base, heap_end, true);
    if id != invalid_id {
        current_id = id;
    }
    return id;
}

// Creates an unrooted user-shaped address space for policy selftests. Real
// userspace creation should allocate a root page table before mapping pages.
pub fn create_user_policy_fixture(spec: Spec): usize {
    return allocate_slot(AddressSpaceKind.user, 0, vm.user_virtual_base_for_spec(spec), vm.user_virtual_end_for_spec(spec), vm.kernel_virtual_base_for_spec(spec), vm.kernel_heap_virtual_base_for_spec(spec), vm.kernel_heap_virtual_end_for_spec(spec), false);
}

pub fn get(id: usize): AddressSpace {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        return empty_address_space();
    }
    return spaces.values[index];
}

pub fn count(): usize {
    return spaces.count();
}

pub fn current(): usize {
    return current_id;
}

pub fn status(): AddressSpaceStatus {
    return last_status;
}

pub fn kind(id: usize): AddressSpaceKind {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return AddressSpaceKind.empty;
    }
    return spaces.values[index].kind;
}

pub fn object_id(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return kernel_object.invalid_id;
    }
    return spaces.values[index].object_id;
}

pub fn capability_id(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return capability.invalid_id;
    }
    return spaces.values[index].capability_id;
}

pub fn capability_has_rights(id: usize, rights: CapabilityRights): bool {
    const cap = capability_id(id);
    if cap == capability.invalid_id {
        return false;
    }
    return capability.has_rights(cap, rights);
}

fn capability_authorizes(index: usize, cap_id: usize, required_rights: CapabilityRights): bool {
    const cap = capability.get(cap_id);
    if !cap.live {
        last_status = AddressSpaceStatus.invalid_capability;
        return false;
    }
    if cap.object_id != spaces.values[index].object_id {
        last_status = AddressSpaceStatus.capability_object_mismatch;
        return false;
    }
    if !capability.has_rights(cap_id, required_rights) {
        last_status = AddressSpaceStatus.capability_right_missing;
        return false;
    }
    last_status = AddressSpaceStatus.ok;
    return true;
}

pub fn root_table(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return 0;
    }
    return spaces.values[index].root_table;
}

pub fn user_base(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return 0;
    }
    return spaces.values[index].user_base;
}

pub fn user_end(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return 0;
    }
    return spaces.values[index].user_end;
}

pub fn kernel_base(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return 0;
    }
    return spaces.values[index].kernel_base;
}

pub fn kernel_heap_base(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return 0;
    }
    return spaces.values[index].kernel_heap_base;
}

pub fn kernel_heap_end(id: usize): usize {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return 0;
    }
    return spaces.values[index].kernel_heap_end;
}

pub fn active(id: usize): bool {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return false;
    }
    return spaces.values[index].active;
}

pub fn has_root(id: usize): bool {
    return root_table(id) != 0;
}

pub fn can_map_user_page(id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    return capability_can_map_user_page(capability_id(id), id, virt, phys, rights, spec);
}

pub fn capability_can_map_user_page(cap_id: usize, id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return false;
    }
    if !capability_authorizes(index, cap_id, CapabilityRights.map) {
        return false;
    }
    if spaces.values[index].kind != AddressSpaceKind.user {
        return false;
    }
    if spaces.values[index].root_table == 0 {
        last_status = AddressSpaceStatus.root_unallocated;
        return false;
    }
    return vm.validate_user_page_mapping(virt, phys, rights, spec);
}

pub fn accepts_user_mapping_policy(id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    return capability_accepts_user_mapping_policy(capability_id(id), id, virt, phys, rights, spec);
}

pub fn capability_accepts_user_mapping_policy(cap_id: usize, id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return false;
    }
    if !capability_authorizes(index, cap_id, CapabilityRights.map) {
        return false;
    }
    if spaces.values[index].kind != AddressSpaceKind.user {
        return false;
    }
    return vm.validate_user_page_mapping(virt, phys, rights, spec);
}

pub fn can_map_kernel_page(id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    return capability_can_map_kernel_page(capability_id(id), id, virt, phys, rights, spec);
}

pub fn capability_can_map_kernel_page(cap_id: usize, id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    const index = index_for_id(id);
    if index >= max_address_spaces {
        last_status = AddressSpaceStatus.invalid_id;
        return false;
    }
    if !capability_authorizes(index, cap_id, CapabilityRights.map) {
        return false;
    }
    if spaces.values[index].kind != AddressSpaceKind.kernel {
        return false;
    }
    if spaces.values[index].root_table == 0 {
        last_status = AddressSpaceStatus.root_unallocated;
        return false;
    }
    return vm.validate_kernel_page_mapping(virt, phys, rights, spec);
}
