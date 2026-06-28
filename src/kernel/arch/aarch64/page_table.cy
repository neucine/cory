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
pub const tcr_irgn0_write_back: usize = 1 << 8;
pub const tcr_orgn0_write_back: usize = 1 << 10;
pub const tcr_sh0_inner: usize = 3 << 12;
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

// Initial EL1 translation regime: TTBR0 only, 4 KiB granule, 48-bit VA and
// 40-bit PA. QEMU's cortex-a53 model exposes a 40-bit physical-address range,
// so the bootstrap TCR must not request a wider IPS value.
pub fn activation_tcr(): usize {
    return tcr_t0sz_48_bit | tcr_irgn0_write_back | tcr_orgn0_write_back | tcr_sh0_inner | tcr_ips_40_bit;
}

// First activation only turns on translation. Cache and alignment policy should
// be enabled as a separate step once the early identity map is proven stable.
pub fn activation_sctlr_set_bits(): usize {
    return sctlr_mmu_enable;
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

fn map_request_page(tables: Spec, request: vm.MappingRequest, offset: usize): bool {
    var table_page: usize = 0;
    var level: usize = 0;
    const virt = request.virt_start + offset;
    while level < tables.level_count - 1 {
        const entry_index = vm.page_table_level_index(virt, tables, level);
        table_page = ensure_child_table(table_page, entry_index, tables);
        if table_page >= vm.bootstrap_table_page_count() {
            return false;
        }
        level = level + 1;
    }

    const leaf_index = vm.page_table_level_index(virt, tables, tables.level_count - 1);
    const leaf = encode_leaf_for_kind(request.kind, request.phys_start + offset, request.rights);
    return vm.write_bootstrap_table_entry(table_page, leaf_index, tables, leaf.raw);
}

pub fn populate_bootstrap_tables(tables: Spec): bool {
    var request_index: usize = 0;
    while request_index < vm.mapping_request_count() {
        const request = vm.mapping_request(request_index);
        var offset: usize = 0;
        while offset < request.size {
            if !map_request_page(tables, request, offset) {
                return false;
            }
            offset = offset + tables.page_size;
        }
        request_index = request_index + 1;
    }
    return true;
}

pub fn lookup_bootstrap_phys(tables: Spec, virt: usize): usize {
    var table_page: usize = 0;
    var level: usize = 0;
    while level < tables.level_count - 1 {
        const entry_index = vm.page_table_level_index(virt, tables, level);
        const raw = vm.read_bootstrap_table_entry(table_page, entry_index, tables);
        if raw == 0 {
            return 0;
        }
        table_page = vm.bootstrap_table_page_index(table_phys(TableEntry { raw: raw }));
        level = level + 1;
    }

    const leaf_index = vm.page_table_level_index(virt, tables, tables.level_count - 1);
    const raw = vm.read_bootstrap_table_entry(table_page, leaf_index, tables);
    if raw == 0 {
        return 0;
    }
    return leaf_phys(LeafEntry { raw: raw });
}
