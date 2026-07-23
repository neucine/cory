import .memory.address_space;
import .memory.page_table;
import { Spec } from .memory.page_table;
import .console;
import .task.process;

pub enum UserMemoryStatus: i32 {
    ok = 0,
    invalid_process,
    invalid_address_space,
    invalid_range,
    unsupported_arch,
    buffer_too_large,
    no_input,
}

pub const max_debug_copy: usize = 128;

var last_status: UserMemoryStatus = UserMemoryStatus.ok;

pub fn status(): UserMemoryStatus {
    return last_status;
}

fn range_end(addr: usize, len: usize): usize {
    const end = addr + len;
    if end < addr {
        return 0;
    }
    return end;
}

pub fn validate_user_range(arch: i32, process_id: usize, addr: usize, len: usize, spec: Spec): bool {
    const process_info = process.get(process_id);
    if process_info.id == process.invalid_id {
        last_status = UserMemoryStatus.invalid_process;
        return false;
    }
    const space = address_space.get(process_info.address_space_id);
    if space.id == address_space.invalid_id {
        last_status = UserMemoryStatus.invalid_address_space;
        return false;
    }
    const end = range_end(addr, len);
    if len == 0 or end == 0 {
        last_status = UserMemoryStatus.invalid_range;
        return false;
    }
    if addr < space.user_base or end > space.user_end {
        last_status = UserMemoryStatus.invalid_range;
        return false;
    }

    if arch != page_table.arch_aarch64 and arch != page_table.arch_riscv64 {
        last_status = UserMemoryStatus.unsupported_arch;
        return false;
    }

    last_status = UserMemoryStatus.ok;
    return true;
}

pub fn write_to_console_from_user(arch: i32, process_id: usize, addr: usize, len: usize, spec: Spec): usize {
    if len > max_debug_copy {
        last_status = UserMemoryStatus.buffer_too_large;
        return 0;
    }
    if !validate_user_range(arch, process_id, addr, len, spec) {
        return 0;
    }
    unchecked {
        var index: usize = 0;
        while index < len {
            console.putc(*((addr + index) as! *u8));
            index = index + 1;
        }
    }
    last_status = UserMemoryStatus.ok;
    return len;
}

pub fn write_byte_to_user(arch: i32, process_id: usize, addr: usize, value: usize, spec: Spec): bool {
    if !validate_user_range(arch, process_id, addr, 1, spec) {
        return false;
    }
    unchecked {
        *((addr) as! *u8) = value as u8;
    }
    last_status = UserMemoryStatus.ok;
    return true;
}

pub fn read_line_from_console_to_user(arch: i32, process_id: usize, addr: usize, len: usize, spec: Spec): usize {
    if !validate_user_range(arch, process_id, addr, len, spec) {
        return 0;
    }

    unchecked {
        var copied: usize = 0;
        while copied < len {
            const next = console.read_byte();
            if next == console.no_input {
                if copied == 0 {
                    last_status = UserMemoryStatus.no_input;
                    return 0;
                }
                last_status = UserMemoryStatus.ok;
                return copied;
            }
            *((addr + copied) as! *u8) = next as u8;
            copied = copied + 1;
            if next == console.newline {
                last_status = UserMemoryStatus.ok;
                return copied;
            }
        }
        last_status = UserMemoryStatus.ok;
        return copied;
    }
}

pub fn read_line_blocking_from_console_to_user(arch: i32, process_id: usize, addr: usize, len: usize, spec: Spec): usize {
    if !validate_user_range(arch, process_id, addr, len, spec) {
        return 0;
    }

    unchecked {
        var copied: usize = 0;
        while copied < len {
            const next = console.read_byte();
            if next == console.no_input {
                continue;
            }
            *((addr + copied) as! *u8) = next as u8;
            copied = copied + 1;
            if next == console.newline {
                last_status = UserMemoryStatus.ok;
                return copied;
            }
        }
        last_status = UserMemoryStatus.ok;
        return copied;
    }
}
