import .collections.slot_map;
import .memory.page_table;
import { Spec } from .memory.page_table;
import .memory.user_memory;
import .task.process;

pub const max_arg_len: usize = 64;

pub enum ProcessArgStatus: i32 {
    ok = 0,
    invalid_process,
    invalid_user_buffer,
    too_large,
}

pub struct ProcessArg {
    pub len: usize;
    pub bytes: [64]u8;
}

var args: [8]ProcessArg = [ProcessArg {
    len: 0,
    bytes: [0] ** 64,
}] ** 8;
var last_status: ProcessArgStatus = ProcessArgStatus.ok;

fn index_for_process(process_id: usize): usize {
    const entry = process.get(process_id);
    if entry.id == process.invalid_id {
        last_status = ProcessArgStatus.invalid_process;
        return process.max_processes;
    }
    const index = slot_map.index(process.max_processes, process_id);
    if index >= process.max_processes {
        last_status = ProcessArgStatus.invalid_process;
        return process.max_processes;
    }
    last_status = ProcessArgStatus.ok;
    return index;
}

pub fn init(): void {
    var index: usize = 0;
    while index < process.max_processes {
        args[index] = ProcessArg {
            len: 0,
            bytes: [0] ** 64,
        };
        index = index + 1;
    }
    last_status = ProcessArgStatus.ok;
}

pub fn set_empty(process_id: usize): bool {
    const index = index_for_process(process_id);
    if index >= process.max_processes {
        return false;
    }
    var entry = args[index];
    entry.len = 0;
    args[index] = entry;
    last_status = ProcessArgStatus.ok;
    return true;
}

pub fn clear_for_process(process_id: usize): void {
    const index = slot_map.index(process.max_processes, process_id);
    if index >= process.max_processes {
        return;
    }
    args[index] = ProcessArg {
        len: 0,
        bytes: [0] ** 64,
    };
    last_status = ProcessArgStatus.ok;
}

pub fn set_from_user(arch: i32, source_process_id: usize, target_process_id: usize, addr: usize, len: usize, spec: Spec): bool {
    if len > max_arg_len {
        last_status = ProcessArgStatus.too_large;
        return false;
    }
    const index = index_for_process(target_process_id);
    if index >= process.max_processes {
        return false;
    }
    var entry = args[index];
    entry.len = 0;
    if len == 0 {
        args[index] = entry;
        last_status = ProcessArgStatus.ok;
        return true;
    }
    if !user_memory.validate_user_range(arch, source_process_id, addr, len, spec) {
        last_status = ProcessArgStatus.invalid_user_buffer;
        return false;
    }
    unchecked {
        var offset: usize = 0;
        while offset < len {
            entry.bytes[offset] = *((addr + offset) as! *u8);
            offset = offset + 1;
        }
    }
    entry.len = len;
    args[index] = entry;
    last_status = ProcessArgStatus.ok;
    return true;
}

pub fn read_to_user(arch: i32, process_id: usize, addr: usize, max_len: usize, spec: Spec): usize {
    const index = index_for_process(process_id);
    if index >= process.max_processes {
        return 0;
    }
    var len = args[index].len;
    if len > max_len {
        len = max_len;
    }
    if len == 0 {
        last_status = ProcessArgStatus.ok;
        return 0;
    }
    if !user_memory.validate_user_range(arch, process_id, addr, len, spec) {
        last_status = ProcessArgStatus.invalid_user_buffer;
        return 0;
    }
    unchecked {
        var offset: usize = 0;
        while offset < len {
            *((addr + offset) as! *u8) = args[index].bytes[offset];
            offset = offset + 1;
        }
    }
    last_status = ProcessArgStatus.ok;
    return len;
}

pub fn status(): ProcessArgStatus {
    return last_status;
}
