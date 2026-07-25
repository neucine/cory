import .collections.slot_map;
import .memory.user_memory;
import { Spec } from .memory.page_table;
import .task.process;

extern c("cory_initramfs_addr") fn initramfs_addr(): c_ulong;
extern c("cory_initramfs_size") fn initramfs_size(): c_ulong;

pub enum FsStatus: i32 {
    ok = 0,
    invalid_user_buffer,
    not_found,
    invalid_fd,
    table_full,
}

const max_fds_per_process: usize = 4;
const fd_base: usize = 3;
const fd_record_none: usize = 0;
const archive_magic: usize = 3554261880372413184;
const archive_header_size: usize = 16;
const archive_path_size: usize = 64;
const archive_record_size: usize = 88;
const archive_kind_dir: usize = 1;
const archive_kind_file: usize = 2;
const root_record_index: usize = 0;

var last_status: FsStatus = FsStatus.ok;
var fd_live: [32]bool = [false] ** 32;
var fd_record: [32]usize = [fd_record_none] ** 32;
var fd_offset: [32]usize = [0] ** 32;

pub fn status(): FsStatus {
    return last_status;
}

pub fn init(): void {
    var index: usize = 0;
    while index < 32 {
        fd_live[index] = false;
        fd_record[index] = fd_record_none;
        fd_offset[index] = 0;
        index = index + 1;
    }
    last_status = FsStatus.ok;
}

fn process_index(process_id: usize): usize {
    const index = slot_map.index(process.max_processes, process_id);
    if index >= process.max_processes {
        return process.max_processes;
    }
    return index;
}

fn table_index(process_id: usize, slot: usize): usize {
    const proc_index = process_index(process_id);
    if proc_index >= process.max_processes or slot >= max_fds_per_process {
        return 32;
    }
    return proc_index * max_fds_per_process + slot;
}

fn slot_for_fd(fd: usize): usize {
    if fd < fd_base {
        return max_fds_per_process;
    }
    return fd - fd_base;
}

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

fn archive_valid(): bool {
    if archive_size() < archive_header_size {
        return false;
    }
    if archive_word(0) != archive_magic {
        return false;
    }
    return archive_size() >= archive_header_size + archive_record_count() * archive_record_size;
}

fn archive_record_count(): usize {
    return archive_word(8);
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

fn record_id_for_user_path(path: usize, path_len: usize): usize {
    if !archive_valid() {
        return fd_record_none;
    }
    var index: usize = 0;
    while index < archive_record_count() {
        if record_matches_user_path(index, path, path_len) {
            return index + 1;
        }
        index = index + 1;
    }
    return fd_record_none;
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

fn read_record_to_user(record_index: usize, out: usize, max_len: usize, offset: usize): usize {
    if record_kind(record_index) == archive_kind_dir {
        return copy_dir_listing_to_user(record_index, out, max_len, offset);
    }
    if record_kind(record_index) == archive_kind_file {
        return copy_file_to_user(record_index, out, max_len, offset);
    }
    return 0;
}

pub fn list_to_user(arch: i32, process_id: usize, path: usize, path_len: usize, out: usize, max_len: usize, spec: Spec): usize {
    if path_len == 0 or max_len == 0 {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }
    if !user_memory.validate_user_range(arch, process_id, path, path_len, spec) {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }
    if !user_memory.validate_user_range(arch, process_id, out, max_len, spec) {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }

    const record_id = record_id_for_user_path(path, path_len);
    if record_id == fd_record_none {
        last_status = FsStatus.not_found;
        return 0;
    }
    const record_index = record_id - 1;
    if record_kind(record_index) != archive_kind_dir {
        last_status = FsStatus.not_found;
        return 0;
    }

    last_status = FsStatus.ok;
    return read_record_to_user(record_index, out, max_len, 0);
}

pub fn read_to_user(arch: i32, process_id: usize, path: usize, path_len: usize, out: usize, max_len: usize, spec: Spec): usize {
    if path_len == 0 or max_len == 0 {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }
    if !user_memory.validate_user_range(arch, process_id, path, path_len, spec) {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }
    if !user_memory.validate_user_range(arch, process_id, out, max_len, spec) {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }

    const record_id = record_id_for_user_path(path, path_len);
    if record_id == fd_record_none {
        last_status = FsStatus.not_found;
        return 0;
    }

    last_status = FsStatus.ok;
    return read_record_to_user(record_id - 1, out, max_len, 0);
}

pub fn open(arch: i32, process_id: usize, path: usize, path_len: usize, spec: Spec): usize {
    if path_len == 0 {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }
    if !user_memory.validate_user_range(arch, process_id, path, path_len, spec) {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }

    const record_id = record_id_for_user_path(path, path_len);
    if record_id == fd_record_none {
        last_status = FsStatus.not_found;
        return 0;
    }

    var slot: usize = 0;
    while slot < max_fds_per_process {
        const index = table_index(process_id, slot);
        if index < 32 and !fd_live[index] {
            fd_live[index] = true;
            fd_record[index] = record_id;
            fd_offset[index] = 0;
            last_status = FsStatus.ok;
            return fd_base + slot;
        }
        slot = slot + 1;
    }
    last_status = FsStatus.table_full;
    return 0;
}

pub fn read_fd_to_user(arch: i32, process_id: usize, fd: usize, out: usize, max_len: usize, spec: Spec): usize {
    const slot = slot_for_fd(fd);
    const index = table_index(process_id, slot);
    if index >= 32 or !fd_live[index] {
        last_status = FsStatus.invalid_fd;
        return 0;
    }
    if max_len == 0 {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }
    if !user_memory.validate_user_range(arch, process_id, out, max_len, spec) {
        last_status = FsStatus.invalid_user_buffer;
        return 0;
    }

    const copied = read_record_to_user(fd_record[index] - 1, out, max_len, fd_offset[index]);
    fd_offset[index] = fd_offset[index] + copied;
    last_status = FsStatus.ok;
    return copied;
}

pub fn close(process_id: usize, fd: usize): bool {
    const slot = slot_for_fd(fd);
    const index = table_index(process_id, slot);
    if index >= 32 or !fd_live[index] {
        last_status = FsStatus.invalid_fd;
        return false;
    }
    fd_live[index] = false;
    fd_record[index] = fd_record_none;
    fd_offset[index] = 0;
    last_status = FsStatus.ok;
    return true;
}

pub fn clear_for_process(process_id: usize): void {
    var slot: usize = 0;
    while slot < max_fds_per_process {
        const index = table_index(process_id, slot);
        if index < 32 {
            fd_live[index] = false;
            fd_record[index] = fd_record_none;
            fd_offset[index] = 0;
        }
        slot = slot + 1;
    }
}
