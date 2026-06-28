// Common page-table vocabulary. Architecture modules fill this structure with
// their hardware format; common VM code uses it to plan mappings without
// knowing descriptor bit layouts or control registers.
pub struct Spec {
    pub page_size: usize;
    pub page_offset_bits: usize;
    pub level_count: usize;
    pub level_index_bits: usize;
    pub entries_per_table: usize;
    pub entry_size: usize;
    pub virtual_address_bits: usize;
    pub physical_address_bits: usize;
}

pub struct LeafEntry {
    pub raw: usize;
}

pub struct TableEntry {
    pub raw: usize;
}

// Architecture identifiers let common boot checks select the correct hardware
// entry encoder while keeping descriptor bit layouts under `kernel.arch`.
pub const arch_aarch64: i32 = 1;
pub const arch_riscv64: i32 = 2;

pub fn page_offset_mask(spec: Spec): usize {
    return spec.page_size - 1;
}

pub fn table_bytes(spec: Spec): usize {
    return spec.entries_per_table * spec.entry_size;
}

pub fn mapped_bits(spec: Spec): usize {
    return spec.page_offset_bits + (spec.level_count * spec.level_index_bits);
}

pub fn entry_is_present(entry: LeafEntry): bool {
    return entry.raw != 0;
}

pub fn table_entry_is_present(entry: TableEntry): bool {
    return entry.raw != 0;
}

pub fn validate(spec: Spec): bool {
    if spec.page_size == 0 {
        return false;
    }
    if spec.page_offset_bits == 0 {
        return false;
    }
    if spec.level_count == 0 {
        return false;
    }
    if spec.level_index_bits == 0 {
        return false;
    }
    if spec.entries_per_table == 0 {
        return false;
    }
    if spec.entry_size == 0 {
        return false;
    }
    // Bootstrap table storage is read and written as raw `usize` entries.
    // Supporting a different hardware entry width needs typed/raw byte access.
    if spec.entry_size != 8 {
        return false;
    }
    if spec.virtual_address_bits == 0 {
        return false;
    }
    if spec.physical_address_bits == 0 {
        return false;
    }
    if table_bytes(spec) != spec.page_size {
        return false;
    }
    if mapped_bits(spec) != spec.virtual_address_bits {
        return false;
    }
    return true;
}
