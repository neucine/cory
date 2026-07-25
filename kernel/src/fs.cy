import .collections.slot_map;
import .fs_archive;
import .memory.user_memory;
import { Spec } from .memory.page_table;
import .task.process;

pub enum FsStatus: i32 {
    ok = 0,
    invalid_user_buffer,
    not_found,
    invalid_fd,
    table_full,
}

const max_fds_per_process: usize = 4;
const fd_base: usize = 3;

var last_status: FsStatus = FsStatus.ok;
var fd_live: [32]bool = [false] ** 32;
var fd_record: [32]usize = [fs_archive.record_none] ** 32;
var fd_offset: [32]usize = [0] ** 32;

pub fn status(): FsStatus {
    return last_status;
}

pub fn init(): void {
    var index: usize = 0;
    while index < 32 {
        fd_live[index] = false;
        fd_record[index] = fs_archive.record_none;
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

fn validate_user_path(arch: i32, process_id: usize, path: usize, path_len: usize, spec: Spec): bool {
    if path_len == 0 {
        last_status = FsStatus.invalid_user_buffer;
        return false;
    }
    if !user_memory.validate_user_range(arch, process_id, path, path_len, spec) {
        last_status = FsStatus.invalid_user_buffer;
        return false;
    }
    return true;
}

fn validate_user_output(arch: i32, process_id: usize, out: usize, max_len: usize, spec: Spec): bool {
    if max_len == 0 {
        last_status = FsStatus.invalid_user_buffer;
        return false;
    }
    if !user_memory.validate_user_range(arch, process_id, out, max_len, spec) {
        last_status = FsStatus.invalid_user_buffer;
        return false;
    }
    return true;
}

fn record_for_user_path(path: usize, path_len: usize): usize {
    const record_id = fs_archive.find_user_path(path, path_len);
    if record_id == fs_archive.record_none {
        last_status = FsStatus.not_found;
    }
    return record_id;
}

pub fn list_to_user(arch: i32, process_id: usize, path: usize, path_len: usize, out: usize, max_len: usize, spec: Spec): usize {
    if !validate_user_path(arch, process_id, path, path_len, spec) {
        return 0;
    }
    if !validate_user_output(arch, process_id, out, max_len, spec) {
        return 0;
    }

    const record_id = record_for_user_path(path, path_len);
    if record_id == fs_archive.record_none {
        return 0;
    }
    if fs_archive.kind(record_id) != fs_archive.kind_dir {
        last_status = FsStatus.not_found;
        return 0;
    }

    last_status = FsStatus.ok;
    return fs_archive.read_to_user(record_id, out, max_len, 0);
}

pub fn read_to_user(arch: i32, process_id: usize, path: usize, path_len: usize, out: usize, max_len: usize, spec: Spec): usize {
    if !validate_user_path(arch, process_id, path, path_len, spec) {
        return 0;
    }
    if !validate_user_output(arch, process_id, out, max_len, spec) {
        return 0;
    }

    const record_id = record_for_user_path(path, path_len);
    if record_id == fs_archive.record_none {
        return 0;
    }

    last_status = FsStatus.ok;
    return fs_archive.read_to_user(record_id, out, max_len, 0);
}

pub fn open(arch: i32, process_id: usize, path: usize, path_len: usize, spec: Spec): usize {
    if !validate_user_path(arch, process_id, path, path_len, spec) {
        return 0;
    }

    const record_id = record_for_user_path(path, path_len);
    if record_id == fs_archive.record_none {
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
    if !validate_user_output(arch, process_id, out, max_len, spec) {
        return 0;
    }

    const copied = fs_archive.read_to_user(fd_record[index], out, max_len, fd_offset[index]);
    fd_offset[index] = fd_offset[index] + copied;
    last_status = FsStatus.ok;
    return copied;
}

pub fn bin_program_data_addr(program_id: usize): usize {
    return fs_archive.bin_program_data_addr(program_id);
}

pub fn bin_program_data_len(program_id: usize): usize {
    return fs_archive.bin_program_data_len(program_id);
}

pub fn close(process_id: usize, fd: usize): bool {
    const slot = slot_for_fd(fd);
    const index = table_index(process_id, slot);
    if index >= 32 or !fd_live[index] {
        last_status = FsStatus.invalid_fd;
        return false;
    }
    fd_live[index] = false;
    fd_record[index] = fs_archive.record_none;
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
            fd_record[index] = fs_archive.record_none;
            fd_offset[index] = 0;
        }
        slot = slot + 1;
    }
}
