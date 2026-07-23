import .task.process;
import .task.thread;
import { ThreadState } from .task.thread;

pub const invalid_program_id: usize = 0;
pub const max_programs: usize = 4;

pub enum UserProgramStatus: i32 {
    ok = 0,
    invalid_program,
    duplicate_program,
    table_full,
    invalid_process,
    invalid_thread,
    active_process,
    exited_process,
}

pub struct UserProgram {
    pub program_id: usize;
    pub process_id: usize;
    pub thread_id: usize;
}

var programs: [4]UserProgram = [UserProgram {
    program_id: invalid_program_id,
    process_id: process.invalid_id,
    thread_id: thread.invalid_id,
}] ** 4;
var used_programs: usize = 0;
var last_status: UserProgramStatus = UserProgramStatus.ok;

fn empty_program(): UserProgram {
    return UserProgram {
        program_id: invalid_program_id,
        process_id: process.invalid_id,
        thread_id: thread.invalid_id,
    };
}

pub fn init(): void {
    var index: usize = 0;
    while index < max_programs {
        programs[index] = empty_program();
        index = index + 1;
    }
    used_programs = 0;
    last_status = UserProgramStatus.ok;
}

fn index_for_program(program_id: usize): usize {
    var index: usize = 0;
    while index < used_programs {
        if programs[index].program_id == program_id {
            return index;
        }
        index = index + 1;
    }
    return max_programs;
}

fn validate_process_thread(process_id: usize, thread_id: usize): bool {
    const proc = process.get(process_id);
    if proc.id == process.invalid_id {
        last_status = UserProgramStatus.invalid_process;
        return false;
    }
    if proc.active {
        last_status = UserProgramStatus.active_process;
        return false;
    }
    if proc.exited {
        last_status = UserProgramStatus.exited_process;
        return false;
    }
    const th = thread.get(thread_id);
    if th.id == thread.invalid_id {
        last_status = UserProgramStatus.invalid_thread;
        return false;
    }
    if th.process_id != process_id {
        last_status = UserProgramStatus.invalid_thread;
        return false;
    }
    if th.state != ThreadState.ready {
        last_status = UserProgramStatus.invalid_thread;
        return false;
    }
    last_status = UserProgramStatus.ok;
    return true;
}

pub fn register_prepared(program_id: usize, process_id: usize, thread_id: usize): bool {
    if program_id == invalid_program_id {
        last_status = UserProgramStatus.invalid_program;
        return false;
    }
    if index_for_program(program_id) < max_programs {
        last_status = UserProgramStatus.duplicate_program;
        return false;
    }
    if used_programs >= max_programs {
        last_status = UserProgramStatus.table_full;
        return false;
    }
    if !validate_process_thread(process_id, thread_id) {
        return false;
    }
    programs[used_programs] = UserProgram {
        program_id: program_id,
        process_id: process_id,
        thread_id: thread_id,
    };
    used_programs = used_programs + 1;
    last_status = UserProgramStatus.ok;
    return true;
}

pub fn get(program_id: usize): UserProgram {
    const index = index_for_program(program_id);
    if index >= max_programs {
        last_status = UserProgramStatus.invalid_program;
        return empty_program();
    }
    const entry = programs[index];
    if !validate_process_thread(entry.process_id, entry.thread_id) {
        return empty_program();
    }
    last_status = UserProgramStatus.ok;
    return entry;
}

pub fn count(): usize {
    return used_programs;
}

pub fn status(): UserProgramStatus {
    return last_status;
}
