import .fs;
import { FsStatus } from .fs;
import .syscall;
import { SyscallError } from .syscall;
import .task.process;
import { ProcessStatus } from .task.process;
import .task.process_reaper;
import { ReapStatus } from .task.process_reaper;

pub fn process_status_error(): SyscallError {
    if process.status() == ProcessStatus.not_exited {
        return SyscallError.process_not_exited;
    }
    return SyscallError.invalid_process;
}

pub fn reaper_status_error(): SyscallError {
    if process_reaper.status() == ReapStatus.not_exited {
        return SyscallError.process_not_exited;
    }
    return SyscallError.invalid_process;
}

pub fn fs_status_error(): SyscallError {
    if fs.status() == FsStatus.not_found {
        return SyscallError.not_found;
    }
    if fs.status() == FsStatus.invalid_fd {
        return SyscallError.invalid_fd;
    }
    return SyscallError.invalid_user_buffer;
}
