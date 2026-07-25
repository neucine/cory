extern c("cory_initramfs_addr") fn initramfs_addr(): c_ulong;
extern c("cory_initramfs_size") fn initramfs_size(): c_ulong;

pub const record_none: usize = 0;
pub const kind_dir: usize = 1;
pub const kind_file: usize = 2;

const archive_magic: usize = 3554261880372413184;
const archive_header_size: usize = 16;
const archive_path_size: usize = 64;
const archive_record_size: usize = 88;
const root_record_index: usize = 0;

const program_selftest: usize = 1;
const program_shell: usize = 2;
const program_echo: usize = 3;
const program_ps: usize = 4;
const program_ls: usize = 5;
const program_cat: usize = 6;

fn archive_base(): usize {
    return initramfs_addr() as usize;
}

fn archive_size(): usize {
    return initramfs_size() as usize;
}

fn archive_word(offset: usize): usize {
    unchecked {
        return *((archive_base() + offset) as! *usize);
    }
}

fn archive_record_count(): usize {
    return archive_word(8);
}

fn archive_valid(): bool {
    if archive_size() < archive_header_size {
        return false;
    }
    if archive_word(0) != archive_magic {
        return false;
    }
    return archive_size() >= archive_header_size + archive_record_count() * archive_record_size;
}

fn record_offset(record_index: usize): usize {
    return archive_header_size + record_index * archive_record_size;
}

fn record_path_byte(record_index: usize, offset: usize): u8 {
    unchecked {
        return *((archive_base() + record_offset(record_index) + offset) as! *u8);
    }
}

fn record_kind(record_index: usize): usize {
    return archive_word(record_offset(record_index) + archive_path_size);
}

fn record_data_offset(record_index: usize): usize {
    return archive_word(record_offset(record_index) + archive_path_size + 8);
}

fn record_data_len(record_index: usize): usize {
    return archive_word(record_offset(record_index) + archive_path_size + 16);
}

fn record_path_len(record_index: usize): usize {
    var len: usize = 0;
    while len < archive_path_size and record_path_byte(record_index, len) != 0 {
        len = len + 1;
    }
    return len;
}

fn user_byte(addr: usize, offset: usize): u8 {
    unchecked {
        return *((addr + offset) as! *u8);
    }
}

fn record_matches_user_path(record_index: usize, path: usize, path_len: usize): bool {
    if record_path_len(record_index) != path_len {
        return false;
    }
    var index: usize = 0;
    while index < path_len {
        if record_path_byte(record_index, index) != user_byte(path, index) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

fn bin_program_path_len(program_id: usize): usize {
    if program_id == program_selftest {
        return 13;
    }
    if program_id == program_shell {
        return 10;
    }
    if program_id == program_echo {
        return 9;
    }
    if program_id == program_ps {
        return 7;
    }
    if program_id == program_ls {
        return 7;
    }
    if program_id == program_cat {
        return 8;
    }
    return 0;
}

fn bin_program_name_byte(program_id: usize, offset: usize): u8 {
    if program_id == program_selftest {
        if offset == 0 { return 's'; }
        if offset == 1 { return 'e'; }
        if offset == 2 { return 'l'; }
        if offset == 3 { return 'f'; }
        if offset == 4 { return 't'; }
        if offset == 5 { return 'e'; }
        if offset == 6 { return 's'; }
        if offset == 7 { return 't'; }
    }
    if program_id == program_shell {
        if offset == 0 { return 's'; }
        if offset == 1 { return 'h'; }
        if offset == 2 { return 'e'; }
        if offset == 3 { return 'l'; }
        if offset == 4 { return 'l'; }
    }
    if program_id == program_echo {
        if offset == 0 { return 'e'; }
        if offset == 1 { return 'c'; }
        if offset == 2 { return 'h'; }
        if offset == 3 { return 'o'; }
    }
    if program_id == program_ps {
        if offset == 0 { return 'p'; }
        if offset == 1 { return 's'; }
    }
    if program_id == program_ls {
        if offset == 0 { return 'l'; }
        if offset == 1 { return 's'; }
    }
    if program_id == program_cat {
        if offset == 0 { return 'c'; }
        if offset == 1 { return 'a'; }
        if offset == 2 { return 't'; }
    }
    return 0;
}

fn bin_program_path_byte(program_id: usize, offset: usize): u8 {
    if offset == 0 { return '/'; }
    if offset == 1 { return 'b'; }
    if offset == 2 { return 'i'; }
    if offset == 3 { return 'n'; }
    if offset == 4 { return '/'; }
    return bin_program_name_byte(program_id, offset - 5);
}

fn record_matches_bin_program(record_index: usize, program_id: usize): bool {
    const path_len = bin_program_path_len(program_id);
    if path_len == 0 or record_path_len(record_index) != path_len {
        return false;
    }
    var index: usize = 0;
    while index < path_len {
        if record_path_byte(record_index, index) != bin_program_path_byte(program_id, index) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

fn record_id_for_bin_program(program_id: usize): usize {
    if !archive_valid() {
        return record_none;
    }
    var index: usize = 0;
    while index < archive_record_count() {
        if record_matches_bin_program(index, program_id) {
            return index + 1;
        }
        index = index + 1;
    }
    return record_none;
}

fn child_of_root(child_index: usize): bool {
    return child_index != root_record_index;
}

fn child_name_offset_for_dir(child_index: usize, dir_index: usize): usize {
    if dir_index == root_record_index {
        return 0;
    }

    const dir_len = record_path_len(dir_index);
    const child_len = record_path_len(child_index);
    if child_len <= dir_len + 1 {
        return archive_path_size;
    }
    if record_path_byte(child_index, dir_len) != '/' {
        return archive_path_size;
    }

    var index: usize = 0;
    while index < dir_len {
        if record_path_byte(child_index, index) != record_path_byte(dir_index, index) {
            return archive_path_size;
        }
        index = index + 1;
    }
    return dir_len + 1;
}

fn child_name_len_for_dir(child_index: usize, dir_index: usize): usize {
    if dir_index == root_record_index {
        return record_path_len(child_index);
    }

    const name_offset = child_name_offset_for_dir(child_index, dir_index);
    if name_offset >= archive_path_size {
        return 0;
    }

    var len: usize = 0;
    while name_offset + len < archive_path_size {
        const ch = record_path_byte(child_index, name_offset + len);
        if ch == 0 {
            return len;
        }
        if ch == '/' {
            return 0;
        }
        len = len + 1;
    }
    return len;
}

fn listing_entry_len(record_index: usize, dir_index: usize): usize {
    if dir_index == root_record_index {
        if child_of_root(record_index) {
            return record_path_len(record_index) + 1;
        }
        return 0;
    }

    const name_len = child_name_len_for_dir(record_index, dir_index);
    if name_len == 0 {
        return 0;
    }
    return name_len + 1;
}

fn listing_entry_byte(record_index: usize, dir_index: usize, entry_offset: usize): u8 {
    if dir_index == root_record_index {
        const path_len = record_path_len(record_index);
        if entry_offset == path_len {
            return '\n';
        }
        return record_path_byte(record_index, entry_offset);
    }

    const name_offset = child_name_offset_for_dir(record_index, dir_index);
    const name_len = child_name_len_for_dir(record_index, dir_index);
    if entry_offset == name_len {
        return '\n';
    }
    return record_path_byte(record_index, name_offset + entry_offset);
}

fn listing_len_for_dir(dir_index: usize): usize {
    var total: usize = 0;
    var index: usize = 0;
    while index < archive_record_count() {
        total = total + listing_entry_len(index, dir_index);
        index = index + 1;
    }
    return total;
}

fn listing_byte_for_dir(dir_index: usize, wanted: usize): u8 {
    var cursor: usize = 0;
    var index: usize = 0;
    while index < archive_record_count() {
        const entry_len = listing_entry_len(index, dir_index);
        if wanted < cursor + entry_len {
            return listing_entry_byte(index, dir_index, wanted - cursor);
        }
        cursor = cursor + entry_len;
        index = index + 1;
    }
    return 0;
}

fn copy_dir_listing_to_user(record_index: usize, out: usize, max_len: usize, offset: usize): usize {
    const listing_len = listing_len_for_dir(record_index);
    var copied: usize = 0;
    unchecked {
        while offset + copied < listing_len and copied < max_len {
            *((out + copied) as! *u8) = listing_byte_for_dir(record_index, offset + copied);
            copied = copied + 1;
        }
    }
    return copied;
}

fn copy_file_to_user(record_index: usize, out: usize, max_len: usize, offset: usize): usize {
    const len = record_data_len(record_index);
    if offset >= len {
        return 0;
    }
    const data_offset = record_data_offset(record_index);
    var copied: usize = 0;
    unchecked {
        while offset + copied < len and copied < max_len {
            *((out + copied) as! *u8) = *((archive_base() + data_offset + offset + copied) as! *u8);
            copied = copied + 1;
        }
    }
    return copied;
}

pub fn find_user_path(path: usize, path_len: usize): usize {
    if !archive_valid() {
        return record_none;
    }
    var index: usize = 0;
    while index < archive_record_count() {
        if record_matches_user_path(index, path, path_len) {
            return index + 1;
        }
        index = index + 1;
    }
    return record_none;
}

pub fn kind(record_id: usize): usize {
    if record_id == record_none {
        return 0;
    }
    return record_kind(record_id - 1);
}

pub fn read_to_user(record_id: usize, out: usize, max_len: usize, offset: usize): usize {
    if record_id == record_none {
        return 0;
    }
    const record_index = record_id - 1;
    if record_kind(record_index) == kind_dir {
        return copy_dir_listing_to_user(record_index, out, max_len, offset);
    }
    if record_kind(record_index) == kind_file {
        return copy_file_to_user(record_index, out, max_len, offset);
    }
    return 0;
}

pub fn bin_program_data_addr(program_id: usize): usize {
    const record_id = record_id_for_bin_program(program_id);
    if record_id == record_none {
        return 0;
    }
    const record_index = record_id - 1;
    if record_kind(record_index) != kind_file {
        return 0;
    }
    if record_data_len(record_index) == 0 {
        return 0;
    }
    return archive_base() + record_data_offset(record_index);
}

pub fn bin_program_data_len(program_id: usize): usize {
    const record_id = record_id_for_bin_program(program_id);
    if record_id == record_none {
        return 0;
    }
    const record_index = record_id - 1;
    if record_kind(record_index) != kind_file {
        return 0;
    }
    return record_data_len(record_index);
}
