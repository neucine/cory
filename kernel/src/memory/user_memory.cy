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

fn normalize_line_byte(ch: usize): usize {
    if ch == console.carriage_return {
        return console.newline;
    }
    return ch;
}

fn line_byte_is_backspace(ch: usize): bool {
    return ch == 8 or ch == 127;
}

fn echo_backspace(): void {
    console.putc(8);
    console.putc(32);
    console.putc(8);
}

fn echo_pending_line(addr: usize, echoed: usize, copied: usize): usize {
    unchecked {
        var index = echoed;
        while index < copied {
            console.putc(*((addr + index) as! *u8));
            index = index + 1;
        }
    }
    return copied;
}

pub fn read_line_from_console_to_user(arch: i32, process_id: usize, addr: usize, len: usize, spec: Spec): usize {
    if !validate_user_range(arch, process_id, addr, len, spec) {
        return 0;
    }

    unchecked {
        var copied: usize = 0;
        var echoed: usize = 0;
        while copied < len {
            const next = console.read_byte();
            if next == console.no_input {
                if copied == 0 {
                    last_status = UserMemoryStatus.no_input;
                    return 0;
                }
                echoed = echo_pending_line(addr, echoed, copied);
                last_status = UserMemoryStatus.ok;
                return copied;
            }
            if line_byte_is_backspace(next) {
                if copied > 0 {
                    copied = copied - 1;
                    if echoed > copied {
                        echo_backspace();
                        echoed = copied;
                    }
                }
                continue;
            }
            const normalized = normalize_line_byte(next);
            *((addr + copied) as! *u8) = normalized as u8;
            copied = copied + 1;
            if normalized == console.newline {
                echoed = echo_pending_line(addr, echoed, copied);
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
        var echoed: usize = 0;
        while copied < len {
            const next = console.read_byte();
            if next == console.no_input {
                if copied > echoed {
                    echoed = echo_pending_line(addr, echoed, copied);
                }
                continue;
            }
            if line_byte_is_backspace(next) {
                if copied > 0 {
                    copied = copied - 1;
                    if echoed > copied {
                        echo_backspace();
                        echoed = copied;
                    }
                }
                continue;
            }
            const normalized = normalize_line_byte(next);
            *((addr + copied) as! *u8) = normalized as u8;
            copied = copied + 1;
            if normalized == console.newline {
                echoed = echo_pending_line(addr, echoed, copied);
                last_status = UserMemoryStatus.ok;
                return copied;
            }
        }
        echoed = echo_pending_line(addr, echoed, copied);
        last_status = UserMemoryStatus.ok;
        return copied;
    }
}
