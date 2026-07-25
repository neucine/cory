pub enum SyscallOp: i32 {
    unknown = 0,
    scheduler_yield_current,
    scheduler_block_current,
    debug_write,
    process_exit_current,
    process_wait_exited,
    process_current,
    process_spawn_known,
    process_spawn_path,
    program_inspect,
    console_read,
    console_write,
    process_list,
    process_arg_read,
    program_find,
    program_find_path,
    fs_list,
    fs_read,
    fs_open,
    fs_fd_read,
    fs_close,
}

pub enum SyscallStatus: i32 {
    ok = 0,
    unknown_number,
}

pub enum SyscallError: i32 {
    ok = 0,
    unknown_number,
    unsupported_return,
    invalid_user_buffer,
    invalid_process,
    process_not_exited,
    no_input,
    not_found,
    invalid_fd,
}

pub enum SyscallOrigin: i32 {
    kernel = 0,
    user,
}

pub struct SyscallRequest {
    pub origin: SyscallOrigin;
    pub number: usize;
    pub op: SyscallOp;
    pub status: SyscallStatus;
    pub arg0: usize;
    pub arg1: usize;
    pub arg2: usize;
    pub arg3: usize;
}

pub struct SyscallResult {
    pub error: SyscallError;
    pub value0: usize;
    pub value1: usize;
}

pub const number_unknown: usize = 0;
pub const number_scheduler_yield_current: usize = 1;
pub const number_scheduler_block_current: usize = 2;
pub const number_debug_write: usize = 3;
pub const number_process_exit_current: usize = 4;
pub const number_process_wait_exited: usize = 5;
pub const number_process_current: usize = 6;
pub const number_process_spawn_known: usize = 7;
pub const number_program_inspect: usize = 8;
pub const number_console_read: usize = 9;
pub const number_console_write: usize = 10;
pub const number_process_list: usize = 11;
pub const number_process_arg_read: usize = 12;
pub const number_program_find: usize = 13;
pub const number_fs_list: usize = 14;
pub const number_fs_read: usize = 15;
pub const number_fs_open: usize = 16;
pub const number_fs_fd_read: usize = 17;
pub const number_fs_close: usize = 18;
pub const number_program_find_path: usize = 19;
pub const number_process_spawn_path: usize = 20;

pub const asm_number_scheduler_yield_current: usize = 1;
pub const asm_number_debug_write: usize = 3;
pub const asm_number_process_exit_current: usize = 4;
pub const asm_number_process_wait_exited: usize = 5;
pub const asm_number_process_current: usize = 6;
pub const asm_number_process_spawn_known: usize = 7;
pub const asm_number_program_inspect: usize = 8;
pub const asm_number_console_read: usize = 9;
pub const asm_number_console_write: usize = 10;
pub const asm_number_process_list: usize = 11;
pub const asm_number_process_arg_read: usize = 12;
pub const asm_number_program_find: usize = 13;
pub const asm_number_fs_list: usize = 14;
pub const asm_number_fs_read: usize = 15;
pub const asm_number_fs_open: usize = 16;
pub const asm_number_fs_fd_read: usize = 17;
pub const asm_number_fs_close: usize = 18;
pub const asm_number_program_find_path: usize = 19;
pub const asm_number_process_spawn_path: usize = 20;

export asm("CORY_SYSCALL_YIELD") const exported_asm_number_scheduler_yield_current: usize = 1;
export asm("CORY_SYSCALL_DEBUG_WRITE") const exported_asm_number_debug_write: usize = 3;
export asm("CORY_SYSCALL_PROCESS_EXIT") const exported_asm_number_process_exit_current: usize = 4;
export asm("CORY_SYSCALL_PROCESS_WAIT") const exported_asm_number_process_wait_exited: usize = 5;
export asm("CORY_SYSCALL_PROCESS_CURRENT") const exported_asm_number_process_current: usize = 6;
export asm("CORY_SYSCALL_PROCESS_SPAWN") const exported_asm_number_process_spawn_known: usize = 7;
export asm("CORY_SYSCALL_PROGRAM_INSPECT") const exported_asm_number_program_inspect: usize = 8;
export asm("CORY_SYSCALL_CONSOLE_READ") const exported_asm_number_console_read: usize = 9;
export asm("CORY_SYSCALL_CONSOLE_WRITE") const exported_asm_number_console_write: usize = 10;
export asm("CORY_SYSCALL_PROCESS_LIST") const exported_asm_number_process_list: usize = 11;
export asm("CORY_SYSCALL_PROCESS_ARG_READ") const exported_asm_number_process_arg_read: usize = 12;
export asm("CORY_SYSCALL_PROGRAM_FIND") const exported_asm_number_program_find: usize = 13;
export asm("CORY_SYSCALL_FS_LIST") const exported_asm_number_fs_list: usize = 14;
export asm("CORY_SYSCALL_FS_READ") const exported_asm_number_fs_read: usize = 15;
export asm("CORY_SYSCALL_FS_OPEN") const exported_asm_number_fs_open: usize = 16;
export asm("CORY_SYSCALL_FS_FD_READ") const exported_asm_number_fs_fd_read: usize = 17;
export asm("CORY_SYSCALL_FS_CLOSE") const exported_asm_number_fs_close: usize = 18;
export asm("CORY_SYSCALL_PROGRAM_FIND_PATH") const exported_asm_number_program_find_path: usize = 19;
export asm("CORY_SYSCALL_PROCESS_SPAWN_PATH") const exported_asm_number_process_spawn_path: usize = 20;

var last_status: SyscallStatus = SyscallStatus.ok;

pub fn asm_numbers_match(): bool {
    if asm_number_scheduler_yield_current != number_scheduler_yield_current {
        return false;
    }
    if asm_number_debug_write != number_debug_write {
        return false;
    }
    if asm_number_process_exit_current != number_process_exit_current {
        return false;
    }
    if asm_number_process_wait_exited != number_process_wait_exited {
        return false;
    }
    if asm_number_process_current != number_process_current {
        return false;
    }
    if asm_number_process_spawn_known != number_process_spawn_known {
        return false;
    }
    if asm_number_program_inspect != number_program_inspect {
        return false;
    }
    if asm_number_console_read != number_console_read {
        return false;
    }
    if asm_number_console_write != number_console_write {
        return false;
    }
    if asm_number_process_list != number_process_list {
        return false;
    }
    if asm_number_process_arg_read != number_process_arg_read {
        return false;
    }
    if asm_number_program_find != number_program_find {
        return false;
    }
    if asm_number_fs_list != number_fs_list {
        return false;
    }
    if asm_number_fs_read != number_fs_read {
        return false;
    }
    if asm_number_fs_open != number_fs_open {
        return false;
    }
    if asm_number_fs_fd_read != number_fs_fd_read {
        return false;
    }
    if asm_number_fs_close != number_fs_close {
        return false;
    }
    if asm_number_program_find_path != number_program_find_path {
        return false;
    }
    if asm_number_process_spawn_path != number_process_spawn_path {
        return false;
    }
    return true;
}

pub fn from_number(number: usize): SyscallOp {
    if number == number_scheduler_yield_current {
        return SyscallOp.scheduler_yield_current;
    }
    if number == number_scheduler_block_current {
        return SyscallOp.scheduler_block_current;
    }
    if number == number_debug_write {
        return SyscallOp.debug_write;
    }
    if number == number_process_exit_current {
        return SyscallOp.process_exit_current;
    }
    if number == number_process_wait_exited {
        return SyscallOp.process_wait_exited;
    }
    if number == number_process_current {
        return SyscallOp.process_current;
    }
    if number == number_process_spawn_known {
        return SyscallOp.process_spawn_known;
    }
    if number == number_process_spawn_path {
        return SyscallOp.process_spawn_path;
    }
    if number == number_program_inspect {
        return SyscallOp.program_inspect;
    }
    if number == number_console_read {
        return SyscallOp.console_read;
    }
    if number == number_console_write {
        return SyscallOp.console_write;
    }
    if number == number_process_list {
        return SyscallOp.process_list;
    }
    if number == number_process_arg_read {
        return SyscallOp.process_arg_read;
    }
    if number == number_program_find {
        return SyscallOp.program_find;
    }
    if number == number_program_find_path {
        return SyscallOp.program_find_path;
    }
    if number == number_fs_list {
        return SyscallOp.fs_list;
    }
    if number == number_fs_read {
        return SyscallOp.fs_read;
    }
    if number == number_fs_open {
        return SyscallOp.fs_open;
    }
    if number == number_fs_fd_read {
        return SyscallOp.fs_fd_read;
    }
    if number == number_fs_close {
        return SyscallOp.fs_close;
    }
    return SyscallOp.unknown;
}

pub fn decode_number(number: usize): SyscallOp {
    return decode_request(number).op;
}

pub fn decode_request(number: usize): SyscallRequest {
    return decode_kernel_request(number);
}

pub fn decode_request_with_args(number: usize, arg0: usize, arg1: usize, arg2: usize, arg3: usize): SyscallRequest {
    return decode_kernel_request_with_args(number, arg0, arg1, arg2, arg3);
}

pub fn decode_kernel_request(number: usize): SyscallRequest {
    return decode_request_for_origin(SyscallOrigin.kernel, number, 0, 0, 0, 0);
}

pub fn decode_kernel_request_with_args(number: usize, arg0: usize, arg1: usize, arg2: usize, arg3: usize): SyscallRequest {
    return decode_request_for_origin(SyscallOrigin.kernel, number, arg0, arg1, arg2, arg3);
}

pub fn decode_user_request(number: usize): SyscallRequest {
    return decode_request_for_origin(SyscallOrigin.user, number, 0, 0, 0, 0);
}

pub fn decode_request_for_origin(origin: SyscallOrigin, number: usize, arg0: usize, arg1: usize, arg2: usize, arg3: usize): SyscallRequest {
    const op = from_number(number);
    var decoded_status = SyscallStatus.ok;
    if op == SyscallOp.unknown {
        decoded_status = SyscallStatus.unknown_number;
    }
    last_status = decoded_status;
    return SyscallRequest {
        origin: origin,
        number: number,
        op: op,
        status: decoded_status,
        arg0: arg0,
        arg1: arg1,
        arg2: arg2,
        arg3: arg3,
    };
}

pub fn ok_result(value0: usize, value1: usize): SyscallResult {
    return SyscallResult {
        error: SyscallError.ok,
        value0: value0,
        value1: value1,
    };
}

pub fn error_result(error: SyscallError): SyscallResult {
    return SyscallResult {
        error: error,
        value0: 0,
        value1: 0,
    };
}

pub fn result_for_request(request: SyscallRequest): SyscallResult {
    if request.status == SyscallStatus.unknown_number {
        return error_result(SyscallError.unknown_number);
    }
    if request.op == SyscallOp.scheduler_yield_current {
        return ok_result(0, 0);
    }
    return error_result(SyscallError.unsupported_return);
}

pub fn error_code(error: SyscallError): usize {
    if error == SyscallError.ok {
        return 0;
    }
    if error == SyscallError.unknown_number {
        return 1;
    }
    if error == SyscallError.unsupported_return {
        return 2;
    }
    if error == SyscallError.invalid_user_buffer {
        return 3;
    }
    if error == SyscallError.invalid_process {
        return 4;
    }
    if error == SyscallError.process_not_exited {
        return 5;
    }
    if error == SyscallError.no_input {
        return 6;
    }
    if error == SyscallError.not_found {
        return 7;
    }
    if error == SyscallError.invalid_fd {
        return 8;
    }
    return 2;
}

pub fn result_error_code(result: SyscallResult): usize {
    return error_code(result.error);
}

pub fn status(): SyscallStatus {
    return last_status;
}
