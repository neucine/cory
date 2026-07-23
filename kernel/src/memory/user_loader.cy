import .arch.aarch64.page_table as aarch64_page_table;
import .arch.riscv64.page_table as riscv64_page_table;
import .memory.address_space;
import .memory.page_table;
import { Spec } from .memory.page_table;

pub enum UserLoaderStatus: i32 {
    ok = 0,
    invalid_mapping,
    unsupported_arch,
    page_table_update_failed,
}

var last_status: UserLoaderStatus = UserLoaderStatus.ok;

pub fn status(): UserLoaderStatus {
    return last_status;
}

pub fn map_page(arch: i32, address_space_id: usize, address_space_capability_id: usize, virt: usize, phys: usize, rights: u8, spec: Spec): bool {
    if !address_space.capability_can_map_user_page(address_space_capability_id, address_space_id, virt, phys, rights, spec) {
        last_status = UserLoaderStatus.invalid_mapping;
        return false;
    }

    const root_table = address_space.root_table(address_space_id);
    var mapped = false;
    if arch == page_table.arch_aarch64 {
        mapped = aarch64_page_table.map_user_page(root_table, spec, virt, phys, rights);
    } else if arch == page_table.arch_riscv64 {
        mapped = riscv64_page_table.map_user_page(root_table, spec, virt, phys, rights);
    } else {
        last_status = UserLoaderStatus.unsupported_arch;
        return false;
    }

    if !mapped {
        last_status = UserLoaderStatus.page_table_update_failed;
        return false;
    }
    last_status = UserLoaderStatus.ok;
    return true;
}

pub fn lookup_phys(arch: i32, address_space_id: usize, virt: usize, spec: Spec): usize {
    const root_table = address_space.root_table(address_space_id);
    if root_table == 0 {
        last_status = UserLoaderStatus.invalid_mapping;
        return 0;
    }
    if arch == page_table.arch_aarch64 {
        last_status = UserLoaderStatus.ok;
        return aarch64_page_table.lookup_user_phys(root_table, spec, virt);
    }
    if arch == page_table.arch_riscv64 {
        last_status = UserLoaderStatus.ok;
        return riscv64_page_table.lookup_user_phys(root_table, spec, virt);
    }
    last_status = UserLoaderStatus.unsupported_arch;
    return 0;
}
