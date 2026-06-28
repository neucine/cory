import { LeafEntry, Spec, TableEntry } from .kernel.memory.page_table;
import .kernel.memory.page_table as common_page_table;
import .kernel.memory.vm;

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

fn ensure_child_table_for_geometry(parent_page: usize, entry_index: usize, page_size: usize, entries_per_table: usize, entry_size: usize): usize {
    const existing = vm.read_bootstrap_table_entry_for_geometry(parent_page, entry_index, page_size, entries_per_table, entry_size);
    if existing != 0 {
        return vm.bootstrap_table_page_index(table_phys(TableEntry { raw: existing }));
    }

    const child = vm.allocate_bootstrap_table_page();
    if child == 0 {
        return entries_per_table;
    }
    const entry = encode_table(child);
    if !vm.write_bootstrap_table_entry_for_geometry(parent_page, entry_index, page_size, entries_per_table, entry_size, entry.raw) {
        return entries_per_table;
    }
    return vm.bootstrap_table_page_index(child);
}

fn ensure_child_table(parent_page: usize, entry_index: usize, tables: Spec): usize {
    return ensure_child_table_for_geometry(parent_page, entry_index, tables.page_size, tables.entries_per_table, tables.entry_size);
}

fn leaf_table_page_for_geometry(page_size: usize, page_offset_bits: usize, level_count: usize, level_index_bits: usize, entries_per_table: usize, entry_size: usize, virt: usize, create: bool): usize {
    var table_page: usize = 0;
    var level: usize = 0;
    while level < level_count - 1 {
        const entry_index = vm.page_table_level_index_for_geometry(virt, page_offset_bits, level_count, level_index_bits, entries_per_table, level);
        if create {
            table_page = ensure_child_table_for_geometry(table_page, entry_index, page_size, entries_per_table, entry_size);
        } else {
            const raw = vm.read_bootstrap_table_entry_for_geometry(table_page, entry_index, page_size, entries_per_table, entry_size);
            if raw == 0 {
                return entries_per_table;
            }
            table_page = vm.bootstrap_table_page_index(table_phys(TableEntry { raw: raw }));
        }
        if table_page >= vm.bootstrap_table_page_count() {
            return entries_per_table;
        }
        level = level + 1;
    }
    return table_page;
}

fn leaf_table_page_for_virt(tables: Spec, virt: usize, create: bool): usize {
    return leaf_table_page_for_geometry(tables.page_size, tables.page_offset_bits, tables.level_count, tables.level_index_bits, tables.entries_per_table, tables.entry_size, virt, create);
}

pub fn map_bootstrap_page(tables: Spec, virt: usize, phys: usize, rights: u8): bool {
    return map_bootstrap_page_geometry(virt, phys, rights, tables.page_size, tables.page_offset_bits, tables.level_count, tables.level_index_bits, tables.entries_per_table, tables.entry_size);
}

pub fn map_bootstrap_page_geometry(virt: usize, phys: usize, rights: u8, page_size: usize, page_offset_bits: usize, level_count: usize, level_index_bits: usize, entries_per_table: usize, entry_size: usize): bool {
    if !vm.validate_page_mapping_for_size(virt, phys, rights, page_size) {
        return false;
    }

    const table_page = leaf_table_page_for_geometry(page_size, page_offset_bits, level_count, level_index_bits, entries_per_table, entry_size, virt, true);
    if table_page >= vm.bootstrap_table_page_count() {
        return false;
    }

    const leaf_index = vm.page_table_level_index_for_geometry(virt, page_offset_bits, level_count, level_index_bits, entries_per_table, level_count - 1);
    if vm.read_bootstrap_table_entry_for_geometry(table_page, leaf_index, page_size, entries_per_table, entry_size) != 0 {
        return false;
    }
    const leaf = encode_leaf(phys, rights);
    return vm.write_bootstrap_table_entry_for_geometry(table_page, leaf_index, page_size, entries_per_table, entry_size, leaf.raw);
}

pub fn unmap_bootstrap_page(tables: Spec, virt: usize): bool {
    return unmap_bootstrap_page_geometry(virt, tables.page_size, tables.page_offset_bits, tables.level_count, tables.level_index_bits, tables.entries_per_table, tables.entry_size);
}

pub fn unmap_bootstrap_page_geometry(virt: usize, page_size: usize, page_offset_bits: usize, level_count: usize, level_index_bits: usize, entries_per_table: usize, entry_size: usize): bool {
    if !vm.is_page_aligned(virt, page_size) {
        return false;
    }
    const table_page = leaf_table_page_for_geometry(page_size, page_offset_bits, level_count, level_index_bits, entries_per_table, entry_size, virt, false);
    if table_page >= vm.bootstrap_table_page_count() {
        return false;
    }
    const leaf_index = vm.page_table_level_index_for_geometry(virt, page_offset_bits, level_count, level_index_bits, entries_per_table, level_count - 1);
    if vm.read_bootstrap_table_entry_for_geometry(table_page, leaf_index, page_size, entries_per_table, entry_size) == 0 {
        return false;
    }
    return vm.write_bootstrap_table_entry_for_geometry(table_page, leaf_index, page_size, entries_per_table, entry_size, 0);
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
    return lookup_bootstrap_phys_geometry(virt, tables.page_size, tables.page_offset_bits, tables.level_count, tables.level_index_bits, tables.entries_per_table, tables.entry_size);
}

pub fn lookup_bootstrap_phys_geometry(virt: usize, page_size: usize, page_offset_bits: usize, level_count: usize, level_index_bits: usize, entries_per_table: usize, entry_size: usize): usize {
    const table_page = leaf_table_page_for_geometry(page_size, page_offset_bits, level_count, level_index_bits, entries_per_table, entry_size, virt, false);
    if table_page >= vm.bootstrap_table_page_count() {
        return 0;
    }

    const leaf_index = vm.page_table_level_index_for_geometry(virt, page_offset_bits, level_count, level_index_bits, entries_per_table, level_count - 1);
    const raw = vm.read_bootstrap_table_entry_for_geometry(table_page, leaf_index, page_size, entries_per_table, entry_size);
    if raw == 0 {
        return 0;
    }
    return leaf_phys(LeafEntry { raw: raw });
}
