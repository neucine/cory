import .arch.aarch64.context as aarch64_context;
import .arch.aarch64.page_table as aarch64_page_table;
import .arch.riscv64.context as riscv64_context;
import .arch.riscv64.page_table as riscv64_page_table;
import .memory.address_space;
import .memory.page_table;
import { Spec } from .memory.page_table;
import .memory.phys;
import .memory.user_loader;
import .memory.vm;
import .task.context;
import .task.process;
import .task.thread;
import .user_image_abi;

pub enum UserEntryStatus: i32 {
    ok = 0,
    unsupported_arch,
    invalid_entry,
    stack_page_failed,
    active_code_map_failed,
    active_stack_map_failed,
    user_root_failed,
    user_root_zero_failed,
    kernel_map_failed,
    user_space_failed,
    user_process_failed,
    user_process_activate_failed,
    user_code_map_failed,
    user_stack_map_failed,
    user_thread_failed,
    arch_context_failed,
    attach_context_failed,
    invalid_image,
}

pub const image_magic: usize = user_image_abi.image_magic;
pub const image_version: usize = user_image_abi.image_version;
pub const image_header_size: usize = user_image_abi.image_header_size;

pub cstruct UserImageHeader {
    magic: c_ulong;
    version: c_ulong;
    header_size: c_ulong;
    entry_offset: c_ulong;
    code_size: c_ulong;
    stack_pages: c_ulong;
}

pub struct UserImage {
    pub image_phys: usize;
    pub entry_phys: usize;
    pub header_size: usize;
    pub code_size: usize;
    pub stack_pages: usize;
    pub activate_process: bool;
}

pub struct UserEntryPlan {
    pub status: UserEntryStatus;
    pub thread_id: usize;
    pub process_id: usize;
    pub address_space_id: usize;
    pub arch_context_id: usize;
    pub active_root: usize;
    pub user_root: usize;
    pub entry_addr: usize;
    pub stack_pointer: usize;
    pub address_space_switch_supported: bool;
}

pub fn asm_image_header_constants_match(): bool {
    return user_image_abi.asm_header_constants_match();
}

fn empty_image(activate_process: bool): UserImage {
    return UserImage {
        image_phys: 0,
        entry_phys: 0,
        header_size: 0,
        code_size: 0,
        stack_pages: 0,
        activate_process: activate_process,
    };
}

fn empty_plan(status: UserEntryStatus): UserEntryPlan {
    return UserEntryPlan {
        status: status,
        thread_id: thread.invalid_id,
        process_id: process.invalid_id,
        address_space_id: address_space.invalid_id,
        arch_context_id: context.invalid_arch_context,
        active_root: 0,
        user_root: 0,
        entry_addr: 0,
        stack_pointer: 0,
        address_space_switch_supported: false,
    };
}

fn page_base(addr: usize, spec: Spec): usize {
    return addr & (0 - spec.page_size);
}

fn range_end(addr: usize, len: usize): usize {
    const end = addr + len;
    if end < addr {
        return 0;
    }
    return end;
}

fn arch_is_supported(arch: i32): bool {
    return arch == page_table.arch_aarch64 or arch == page_table.arch_riscv64;
}

fn map_active_user_page(arch: i32, root_table: usize, spec: Spec, virt: usize, phys_addr: usize, rights: u8): bool {
    if arch == page_table.arch_aarch64 {
        return aarch64_page_table.map_user_page(root_table, spec, virt, phys_addr, rights);
    }
    if arch == page_table.arch_riscv64 {
        return riscv64_page_table.map_user_page(root_table, spec, virt, phys_addr, rights);
    }
    return false;
}

fn map_kernel_page(arch: i32, root_table: usize, spec: Spec, virt: usize, phys_addr: usize, rights: u8, kind: i32): bool {
    if arch == page_table.arch_aarch64 {
        return aarch64_page_table.map_kernel_page(root_table, spec, kind, virt, phys_addr, rights);
    }
    if arch == page_table.arch_riscv64 {
        return riscv64_page_table.map_kernel_page(root_table, spec, virt, phys_addr, rights);
    }
    return false;
}

fn mirror_kernel_mappings(arch: i32, root_table: usize, spec: Spec): bool {
    var request_index: usize = 0;
    while request_index < vm.mapping_request_count() {
        const request = vm.mapping_request(request_index);
        var offset: usize = 0;
        while offset < request.size {
            if !map_kernel_page(arch, root_table, spec, request.virt_start + offset, request.phys_start + offset, request.rights, request.kind) {
                return false;
            }
            offset = offset + spec.page_size;
        }
        request_index = request_index + 1;
    }
    return true;
}

fn allocate_arch_context(arch: i32, thread_id: usize): usize {
    if arch == page_table.arch_aarch64 {
        return aarch64_context.allocate(thread_id);
    }
    if arch == page_table.arch_riscv64 {
        return riscv64_context.allocate(thread_id);
    }
    return context.invalid_arch_context;
}

pub fn image_from_entry(entry_phys: usize): UserImage {
    return UserImage {
        image_phys: entry_phys,
        entry_phys: entry_phys,
        header_size: 0,
        code_size: 4096,
        stack_pages: 1,
        activate_process: false,
    };
}

pub fn init_image_from_entry(entry_phys: usize): UserImage {
    return UserImage {
        image_phys: entry_phys,
        entry_phys: entry_phys,
        header_size: 0,
        code_size: 4096,
        stack_pages: 1,
        activate_process: true,
    };
}

pub fn image_from_parts(image_phys: usize, entry_phys: usize, header_size: usize, code_size: usize, stack_pages: usize, activate_process: bool): UserImage {
    return UserImage {
        image_phys: image_phys,
        entry_phys: entry_phys,
        header_size: header_size,
        code_size: code_size,
        stack_pages: stack_pages,
        activate_process: activate_process,
    };
}

fn load_image_from_header_with_activation(header_phys: usize, activate_process: bool): UserImage {
    if header_phys == 0 {
        return empty_image(activate_process);
    }
    unchecked {
        const header = header_phys as! *UserImageHeader;
        if (*header).magic as usize != image_magic {
            return empty_image(activate_process);
        }
        if (*header).version as usize != image_version {
            return empty_image(activate_process);
        }
        if (*header).header_size as usize != image_header_size {
            return empty_image(activate_process);
        }
        return UserImage {
            image_phys: header_phys,
            entry_phys: header_phys + ((*header).entry_offset as usize),
            header_size: (*header).header_size as usize,
            code_size: (*header).code_size as usize,
            stack_pages: (*header).stack_pages as usize,
            activate_process: activate_process,
        };
    }
}

pub fn image_from_header(header_phys: usize): UserImage {
    return load_image_from_header_with_activation(header_phys, false);
}

pub fn init_image_from_header(header_phys: usize): UserImage {
    return load_image_from_header_with_activation(header_phys, true);
}

fn prepare_image_thread_with_active_mapping(arch: i32, active_root: usize, spec: Spec, image: UserImage, map_active_pages: bool): UserEntryPlan {
    if !arch_is_supported(arch) {
        return empty_plan(UserEntryStatus.unsupported_arch);
    }
    if image.image_phys == 0 {
        return empty_plan(UserEntryStatus.invalid_image);
    }
    if image.entry_phys == 0 {
        return empty_plan(UserEntryStatus.invalid_entry);
    }
    if image.entry_phys < image.image_phys {
        return empty_plan(UserEntryStatus.invalid_image);
    }
    if image.code_size == 0 or image.code_size > spec.page_size {
        return empty_plan(UserEntryStatus.invalid_image);
    }
    if image.stack_pages != 1 {
        return empty_plan(UserEntryStatus.invalid_image);
    }

    const entry_page = page_base(image.image_phys, spec);
    const image_offset = image.image_phys - entry_page;
    if image.code_size > spec.page_size - image_offset {
        return empty_plan(UserEntryStatus.invalid_image);
    }
    const image_end = range_end(image.image_phys, image.code_size);
    if image_end == 0 {
        return empty_plan(UserEntryStatus.invalid_image);
    }
    if image.header_size != 0 {
        if image.header_size != image_header_size {
            return empty_plan(UserEntryStatus.invalid_image);
        }
        if image.header_size > image.code_size {
            return empty_plan(UserEntryStatus.invalid_image);
        }
        if image.entry_phys < image.image_phys + image.header_size {
            return empty_plan(UserEntryStatus.invalid_image);
        }
    }
    if image.entry_phys >= image_end {
        return empty_plan(UserEntryStatus.invalid_image);
    }
    if page_base(image.entry_phys, spec) != entry_page {
        return empty_plan(UserEntryStatus.invalid_image);
    }
    const entry_offset = image.entry_phys - entry_page;
    const user_entry_page = vm.user_virtual_base_for_spec(spec) + spec.page_size;
    const user_entry = user_entry_page + entry_offset;
    const user_stack_page = user_entry_page + spec.page_size;
    const user_stack = user_stack_page + spec.page_size;
    const user_stack_phys = phys.alloc_page();
    if user_stack_phys == 0 {
        return empty_plan(UserEntryStatus.stack_page_failed);
    }

    if map_active_pages {
        if !map_active_user_page(arch, active_root, spec, user_entry_page, entry_page, vm.rights_user_rx()) {
            return empty_plan(UserEntryStatus.active_code_map_failed);
        }
        if !map_active_user_page(arch, active_root, spec, user_stack_page, user_stack_phys, vm.rights_user_rw()) {
            return empty_plan(UserEntryStatus.active_stack_map_failed);
        }
    }

    const user_root = phys.alloc_page();
    if user_root == 0 {
        return empty_plan(UserEntryStatus.user_root_failed);
    }
    if !vm.zero_table_page(user_root, spec) {
        return empty_plan(UserEntryStatus.user_root_zero_failed);
    }
    if !mirror_kernel_mappings(arch, user_root, spec) {
        return empty_plan(UserEntryStatus.kernel_map_failed);
    }

    const user_space = address_space.create_user_rooted(user_root, spec);
    if user_space == address_space.invalid_id {
        return empty_plan(UserEntryStatus.user_space_failed);
    }
    const user_process = process.create_user_inactive(user_space, address_space.capability_id(user_space));
    if user_process == process.invalid_id {
        return empty_plan(UserEntryStatus.user_process_failed);
    }
    if image.activate_process {
        if !process.mark_active(user_process) {
            return empty_plan(UserEntryStatus.user_process_activate_failed);
        }
    }

    const process_info = process.get(user_process);
    if !user_loader.map_page(arch, user_space, process_info.address_space_capability_id, user_entry_page, entry_page, vm.rights_user_rx(), spec) {
        return empty_plan(UserEntryStatus.user_code_map_failed);
    }
    if !user_loader.map_page(arch, user_space, process_info.address_space_capability_id, user_stack_page, user_stack_phys, vm.rights_user_rw(), spec) {
        return empty_plan(UserEntryStatus.user_stack_map_failed);
    }

    const user_thread = thread.create_user_ready(user_process, process_info.capability_slot, user_entry, user_stack);
    if user_thread == thread.invalid_id {
        return empty_plan(UserEntryStatus.user_thread_failed);
    }
    const arch_context = allocate_arch_context(arch, user_thread);
    if arch_context == context.invalid_arch_context {
        return empty_plan(UserEntryStatus.arch_context_failed);
    }
    if !context.attach_user_context(user_thread, arch, arch_context) {
        return empty_plan(UserEntryStatus.attach_context_failed);
    }

    return UserEntryPlan {
        status: UserEntryStatus.ok,
        thread_id: user_thread,
        process_id: user_process,
        address_space_id: user_space,
        arch_context_id: arch_context,
        active_root: active_root,
        user_root: user_root,
        entry_addr: user_entry,
        stack_pointer: user_stack,
        address_space_switch_supported: true,
    };
}

pub fn prepare_image_thread(arch: i32, active_root: usize, spec: Spec, image: UserImage): UserEntryPlan {
    return prepare_image_thread_with_active_mapping(arch, active_root, spec, image, true);
}

pub fn prepare_spawned_image_thread(arch: i32, active_root: usize, spec: Spec, image: UserImage): UserEntryPlan {
    return prepare_image_thread_with_active_mapping(arch, active_root, spec, image, false);
}

pub fn prepare_probe_thread(arch: i32, active_root: usize, spec: Spec, entry_phys: usize): UserEntryPlan {
    return prepare_image_thread(arch, active_root, spec, image_from_parts(page_base(entry_phys, spec), entry_phys, 0, spec.page_size, 1, false));
}
