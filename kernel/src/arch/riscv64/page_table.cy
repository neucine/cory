import { LeafEntry, Spec, TableEntry } from .memory.page_table;
import .memory.page_table as common_page_table;
import .memory.phys;
import .memory.vm;

// RISC-V64 starts with the Sv39 page-table shape. The eventual SATP write,
// PTE flag bits, and TLB fencing are arch-local; common VM code only needs the
// portable geometry while building the bootstrap mapping plan.
pub const arch_id: i32 = common_page_table.arch_riscv64;

pub fn spec(): Spec {
    return Spec {
        page_size: 4096,
        page_offset_bits: 12,
        level_count: 3,
        level_index_bits: 9,
        entries_per_table: 512,
        entry_size: 8,
        virtual_address_bits: 39,
        physical_address_bits: 56,
    };
}

pub const pte_valid: usize = 1;
pub const pte_read: usize = 1 << 1;
pub const pte_write: usize = 1 << 2;
pub const pte_execute: usize = 1 << 3;
pub const pte_user: usize = 1 << 4;
pub const pte_accessed: usize = 1 << 6;
pub const pte_dirty: usize = 1 << 7;
pub const ppn_shift: usize = 10;
pub const page_shift: usize = 12;
pub const satp_mode_sv39: usize = 8 << 60;

fn flags_for_rights(rights: u8): usize {
    var bits: usize = pte_valid | pte_accessed | pte_dirty;
    if (rights & vm.rights_read) != 0 {
        bits = bits | pte_read;
    }
    if (rights & vm.rights_write) != 0 {
        bits = bits | pte_write;
    }
    if (rights & vm.rights_execute) != 0 {
        bits = bits | pte_execute;
    }
    if (rights & vm.rights_user) != 0 {
        bits = bits | pte_user;
    }
    return bits;
}

// Encodes an Sv39 leaf PTE for the bootstrap mapping plan. SATP installation is
// platform-owned; non-leaf table PTEs are encoded below.
pub fn encode_leaf(phys: usize, rights: u8): LeafEntry {
    return LeafEntry {
        raw: ((phys >> page_shift) << ppn_shift) | flags_for_rights(rights),
    };
}

// Encodes a non-leaf PTE with only the valid bit set. VM owns table allocation;
// RISC-V owns PPN placement and the rule that R/W/X clear means "next table".
pub fn encode_table(phys: usize): TableEntry {
    return TableEntry {
        raw: ((phys >> page_shift) << ppn_shift) | pte_valid,
    };
}

pub fn leaf_phys(entry: LeafEntry): usize {
    return (entry.raw >> ppn_shift) << page_shift;
}

pub fn leaf_is_writable(entry: LeafEntry): bool {
    return (entry.raw & pte_write) != 0;
}

pub fn leaf_is_executable(entry: LeafEntry): bool {
    return (entry.raw & pte_execute) != 0;
}

pub fn leaf_is_user_accessible(entry: LeafEntry): bool {
    return (entry.raw & pte_user) != 0;
}

pub fn table_phys(entry: TableEntry): usize {
    return (entry.raw >> ppn_shift) << page_shift;
}

pub fn activation_satp(root_table_phys: usize): usize {
    return satp_mode_sv39 | (root_table_phys >> page_shift);
}

pub fn activation_root_phys(satp: usize): usize {
    return (satp & ((1 << 44) - 1)) << page_shift;
}

fn ensure_child_table(parent_page: usize, entry_index: usize, tables: Spec): usize {
    const existing = vm.read_bootstrap_table_entry(parent_page, entry_index, tables);
    if existing != 0 {
        return vm.bootstrap_table_page_index(table_phys(TableEntry { raw: existing }));
    }

    const child = vm.allocate_bootstrap_table_page();
    if child == 0 {
        return tables.entries_per_table;
    }
    const entry = encode_table(child);
    if !vm.write_bootstrap_table_entry(parent_page, entry_index, tables, entry.raw) {
        return tables.entries_per_table;
    }
    return vm.bootstrap_table_page_index(child);
}

fn leaf_table_page_for_virt(tables: Spec, virt: usize, create: bool): usize {
    var table_page: usize = 0;
    var level: usize = 0;
    while level < tables.level_count - 1 {
        const entry_index = vm.page_table_level_index(virt, tables, level);
        if create {
            table_page = ensure_child_table(table_page, entry_index, tables);
        } else {
            const raw = vm.read_bootstrap_table_entry(table_page, entry_index, tables);
            if raw == 0 {
                return tables.entries_per_table;
            }
            table_page = vm.bootstrap_table_page_index(table_phys(TableEntry { raw: raw }));
        }
        if table_page >= vm.bootstrap_table_page_count() {
            return tables.entries_per_table;
        }
        level = level + 1;
    }
    return table_page;
}

fn ensure_child_table_phys(parent_table: usize, entry_index: usize, tables: Spec): usize {
    const existing = vm.read_table_entry(parent_table, entry_index, tables);
    if existing != 0 {
        return table_phys(TableEntry { raw: existing });
    }

    const child = phys.alloc_page();
    if child == 0 {
        return 0;
    }
    if !vm.zero_table_page(child, tables) {
        return 0;
    }
    const entry = encode_table(child);
    if !vm.write_table_entry(parent_table, entry_index, tables, entry.raw) {
        return 0;
    }
    return child;
}

fn leaf_table_phys_for_virt(root_table: usize, tables: Spec, virt: usize, create: bool): usize {
    var table_phys_addr: usize = root_table;
    var level: usize = 0;
    while level < tables.level_count - 1 {
        const entry_index = vm.page_table_level_index(virt, tables, level);
        if create {
            table_phys_addr = ensure_child_table_phys(table_phys_addr, entry_index, tables);
        } else {
            const raw = vm.read_table_entry(table_phys_addr, entry_index, tables);
            if raw == 0 {
                return 0;
            }
            table_phys_addr = table_phys(TableEntry { raw: raw });
        }
        if table_phys_addr == 0 {
            return 0;
        }
        level = level + 1;
    }
    return table_phys_addr;
}

pub fn map_bootstrap_page(tables: Spec, virt: usize, phys: usize, rights: u8): bool {
    if !vm.validate_page_mapping(virt, phys, rights, tables) {
        return false;
    }

    const table_page = leaf_table_page_for_virt(tables, virt, true);
    if table_page >= vm.bootstrap_table_page_count() {
        return false;
    }

    const leaf_index = vm.page_table_level_index(virt, tables, tables.level_count - 1);
    if vm.read_bootstrap_table_entry(table_page, leaf_index, tables) != 0 {
        return false;
    }
    const leaf = encode_leaf(phys, rights);
    return vm.write_bootstrap_table_entry(table_page, leaf_index, tables, leaf.raw);
}

pub fn map_user_page(root_table: usize, tables: Spec, virt: usize, phys_addr: usize, rights: u8): bool {
    if !vm.validate_user_page_mapping(virt, phys_addr, rights, tables) {
        return false;
    }
    if root_table == 0 {
        return false;
    }
    if !vm.is_page_aligned(root_table, tables.page_size) {
        return false;
    }

    const table_phys_addr = leaf_table_phys_for_virt(root_table, tables, virt, true);
    if table_phys_addr == 0 {
        return false;
    }
    const leaf_index = vm.page_table_level_index(virt, tables, tables.level_count - 1);
    if vm.read_table_entry(table_phys_addr, leaf_index, tables) != 0 {
        return false;
    }
    const leaf = encode_leaf(phys_addr, rights);
    return vm.write_table_entry(table_phys_addr, leaf_index, tables, leaf.raw);
}

pub fn map_kernel_page(root_table: usize, tables: Spec, virt: usize, phys_addr: usize, rights: u8): bool {
    if !vm.validate_page_mapping(virt, phys_addr, rights, tables) {
        return false;
    }
    if !vm.rights_are_kernel(rights) {
        return false;
    }
    if root_table == 0 {
        return false;
    }
    if !vm.is_page_aligned(root_table, tables.page_size) {
        return false;
    }

    const table_phys_addr = leaf_table_phys_for_virt(root_table, tables, virt, true);
    if table_phys_addr == 0 {
        return false;
    }
    const leaf_index = vm.page_table_level_index(virt, tables, tables.level_count - 1);
    if vm.read_table_entry(table_phys_addr, leaf_index, tables) != 0 {
        return false;
    }
    const leaf = encode_leaf(phys_addr, rights);
    return vm.write_table_entry(table_phys_addr, leaf_index, tables, leaf.raw);
}

pub fn unmap_bootstrap_page(tables: Spec, virt: usize): bool {
    if !vm.is_page_aligned(virt, tables.page_size) {
        return false;
    }
    const table_page = leaf_table_page_for_virt(tables, virt, false);
    if table_page >= vm.bootstrap_table_page_count() {
        return false;
    }
    const leaf_index = vm.page_table_level_index(virt, tables, tables.level_count - 1);
    if vm.read_bootstrap_table_entry(table_page, leaf_index, tables) == 0 {
        return false;
    }
    return vm.write_bootstrap_table_entry(table_page, leaf_index, tables, 0);
}

pub fn lookup_user_phys(root_table: usize, tables: Spec, virt: usize): usize {
    if !vm.is_page_aligned(virt, tables.page_size) {
        return 0;
    }
    if root_table == 0 {
        return 0;
    }
    if !vm.is_page_aligned(root_table, tables.page_size) {
        return 0;
    }

    const table_phys_addr = leaf_table_phys_for_virt(root_table, tables, virt, false);
    if table_phys_addr == 0 {
        return 0;
    }
    const leaf_index = vm.page_table_level_index(virt, tables, tables.level_count - 1);
    const raw = vm.read_table_entry(table_phys_addr, leaf_index, tables);
    if raw == 0 {
        return 0;
    }
    return leaf_phys(LeafEntry { raw: raw });
}

pub fn populate_bootstrap_tables(tables: Spec): bool {
    var request_index: usize = 0;
    while request_index < vm.mapping_request_count() {
        const request = vm.mapping_request(request_index);
        var offset: usize = 0;
        while offset < request.size {
            if !map_bootstrap_page(tables, request.virt_start + offset, request.phys_start + offset, request.rights) {
                return false;
            }
            offset = offset + tables.page_size;
        }
        request_index = request_index + 1;
    }
    return true;
}

pub fn lookup_bootstrap_phys(tables: Spec, virt: usize): usize {
    const table_page = leaf_table_page_for_virt(tables, virt, false);
    if table_page >= vm.bootstrap_table_page_count() {
        return 0;
    }

    const leaf_index = vm.page_table_level_index(virt, tables, tables.level_count - 1);
    const raw = vm.read_bootstrap_table_entry(table_page, leaf_index, tables);
    if raw == 0 {
        return 0;
    }
    return leaf_phys(LeafEntry { raw: raw });
}
