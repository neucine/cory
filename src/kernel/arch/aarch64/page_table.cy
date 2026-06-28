import { LeafEntry, Spec, TableEntry } from .kernel.memory.page_table;
import .kernel.memory.page_table as common_page_table;
import .kernel.memory.map as memory_map;
import .kernel.memory.vm;

// AArch64 uses the EL1 4 KiB translation-granule shape for the initial kernel
// plan. Descriptor bits and MAIR/TCR programming stay arch-local; this module
// only publishes the format facts common VM planning can depend on.
pub const arch_id: i32 = common_page_table.arch_aarch64;

pub fn spec(): Spec {
    return Spec {
        page_size: 4096,
        page_offset_bits: 12,
        level_count: 4,
        level_index_bits: 9,
        entries_per_table: 512,
        entry_size: 8,
        virtual_address_bits: 48,
        physical_address_bits: 40,
    };
}

pub const descriptor_valid: usize = 1;
pub const descriptor_table_or_page: usize = 2;
pub const attr_index_normal: usize = 0 << 2;
pub const attr_index_device: usize = 1 << 2;
pub const access_flag: usize = 1 << 10;
pub const user_accessible: usize = 1 << 6;
pub const read_only: usize = 1 << 7;
pub const privileged_execute_never: usize = 1 << 53;
pub const unprivileged_execute_never: usize = 1 << 54;
pub const output_address_mask: usize = 0x0000fffffffff000;
pub const mair_attr_normal_wbwa: usize = 0xff;
pub const mair_attr_device_ngnre: usize = 0x04 << 8;
pub const tcr_t0sz_48_bit: usize = 16;
pub const tcr_t1sz_48_bit: usize = 16 << 16;
pub const tcr_irgn0_write_back: usize = 1 << 8;
pub const tcr_orgn0_write_back: usize = 1 << 10;
pub const tcr_sh0_inner: usize = 3 << 12;
pub const tcr_irgn1_write_back: usize = 1 << 24;
pub const tcr_orgn1_write_back: usize = 1 << 26;
pub const tcr_sh1_inner: usize = 3 << 28;
pub const tcr_tg1_4k: usize = 2 << 30;
pub const tcr_ips_40_bit: usize = 2 << 32;
pub const sctlr_mmu_enable: usize = 1;
pub const sctlr_alignment_check: usize = 1 << 1;
pub const sctlr_data_cache_enable: usize = 1 << 2;
pub const sctlr_stack_alignment_check: usize = 1 << 3;
pub const sctlr_instruction_cache_enable: usize = 1 << 12;

fn attr_for_rights(kind: i32, rights: u8): usize {
    const no_write = (rights & vm.rights_write) == 0;
    const no_exec = (rights & vm.rights_execute) == 0;
    var attr = descriptor_valid | descriptor_table_or_page | access_flag;
    if kind == memory_map.kind_device_mmio {
        attr = attr | attr_index_device;
    } else {
        attr = attr | attr_index_normal;
    }
    if no_write {
        attr = attr | read_only;
    }
    if no_exec {
        attr = attr | privileged_execute_never;
    }
    if (rights & vm.rights_user) != 0 {
        attr = attr | user_accessible;
    }
    return attr | unprivileged_execute_never;
}

// Encodes a 4 KiB level-3 page descriptor for the bootstrap mapping plan. Block
// descriptors are intentionally separate future work.
pub fn encode_leaf(phys: usize, rights: u8): LeafEntry {
    return encode_leaf_for_kind(memory_map.kind_free_ram, phys, rights);
}

pub fn encode_leaf_for_kind(kind: i32, phys: usize, rights: u8): LeafEntry {
    return LeafEntry {
        raw: (phys & output_address_mask) | attr_for_rights(kind, rights),
    };
}

// Encodes a non-leaf table descriptor that points at the next translation
// table. VM owns table allocation; AArch64 owns the descriptor bit layout.
pub fn encode_table(phys: usize): TableEntry {
    return TableEntry {
        raw: (phys & output_address_mask) | descriptor_valid | descriptor_table_or_page,
    };
}

pub fn leaf_phys(entry: LeafEntry): usize {
    return entry.raw & output_address_mask;
}

pub fn leaf_is_writable(entry: LeafEntry): bool {
    return (entry.raw & read_only) == 0;
}

pub fn leaf_is_executable(entry: LeafEntry): bool {
    return (entry.raw & privileged_execute_never) == 0;
}

pub fn leaf_is_user_accessible(entry: LeafEntry): bool {
    return (entry.raw & user_accessible) != 0;
}

pub fn table_phys(entry: TableEntry): usize {
    return entry.raw & output_address_mask;
}

pub fn activation_ttbr0(root_table_phys: usize): usize {
    return root_table_phys & output_address_mask;
}

// MAIR index 0 is normal cached RAM; index 1 is device memory for MMIO leaves.
pub fn activation_mair(): usize {
    return mair_attr_normal_wbwa | mair_attr_device_ngnre;
}

// Initial EL1 translation regime: the same bootstrap root is installed for
// TTBR0 and TTBR1 so both identity mappings and the high-half heap alias work.
// QEMU's cortex-a53 model exposes a 40-bit physical-address range, so the
// bootstrap TCR must not request a wider IPS value.
pub fn activation_tcr(): usize {
    return tcr_t0sz_48_bit | tcr_irgn0_write_back | tcr_orgn0_write_back | tcr_sh0_inner | tcr_t1sz_48_bit | tcr_irgn1_write_back | tcr_orgn1_write_back | tcr_sh1_inner | tcr_tg1_4k | tcr_ips_40_bit;
}

// First activation only turns on translation. Cache and alignment policy should
// be enabled as a separate step once the early identity map is proven stable.
pub fn activation_sctlr_set_bits(): usize {
    return sctlr_mmu_enable;
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

pub fn map_bootstrap_page_for_kind(tables: Spec, kind: i32, virt: usize, phys: usize, rights: u8): bool {
    return map_bootstrap_page_for_kind_geometry(kind, virt, phys, rights, tables.page_size, tables.page_offset_bits, tables.level_count, tables.level_index_bits, tables.entries_per_table, tables.entry_size);
}

pub fn map_bootstrap_page_for_kind_geometry(kind: i32, virt: usize, phys: usize, rights: u8, page_size: usize, page_offset_bits: usize, level_count: usize, level_index_bits: usize, entries_per_table: usize, entry_size: usize): bool {
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
    const leaf = encode_leaf_for_kind(kind, phys, rights);
    return vm.write_bootstrap_table_entry_for_geometry(table_page, leaf_index, page_size, entries_per_table, entry_size, leaf.raw);
}

pub fn map_bootstrap_page(tables: Spec, virt: usize, phys: usize, rights: u8): bool {
    return map_bootstrap_page_for_kind(tables, memory_map.kind_free_ram, virt, phys, rights);
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
            if !map_bootstrap_page_for_kind(tables, request.kind, request.virt_start + offset, request.phys_start + offset, request.rights) {
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
