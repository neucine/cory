import .task.process;
import .task.thread;
import { ThreadState } from .task.thread;
import .task.user_entry;
import { UserImage } from .task.user_entry;

pub const invalid_program_id: usize = 0;
pub const max_programs: usize = 8;

pub enum UserProgramStatus: i32 {
    ok = 0,
    invalid_program,
    duplicate_program,
    table_full,
    invalid_process,
    invalid_thread,
    active_process,
    exited_process,
    invalid_image,
}

pub struct UserProgram {
    pub program_id: usize;
    pub image_phys: usize;
    pub image_entry_phys: usize;
    pub image_header_size: usize;
    pub image_code_size: usize;
    pub image_stack_pages: usize;
    pub process_id: usize;
    pub thread_id: usize;
}

var program_ids: [8]usize = [invalid_program_id] ** 8;
var image_phys_values: [8]usize = [0] ** 8;
var image_entry_phys_values: [8]usize = [0] ** 8;
var image_header_size_values: [8]usize = [0] ** 8;
var image_code_size_values: [8]usize = [0] ** 8;
var image_stack_pages_values: [8]usize = [0] ** 8;
var process_ids: [8]usize = [process.invalid_id] ** 8;
var thread_ids: [8]usize = [thread.invalid_id] ** 8;
var used_programs: usize = 0;
var last_status: UserProgramStatus = UserProgramStatus.ok;

fn empty_program(): UserProgram {
    return UserProgram {
        program_id: invalid_program_id,
        image_phys: 0,
        image_entry_phys: 0,
        image_header_size: 0,
        image_code_size: 0,
        image_stack_pages: 0,
        process_id: process.invalid_id,
        thread_id: thread.invalid_id,
    };
}

pub fn init(): void {
    var index: usize = 0;
    while index < max_programs {
        program_ids[index] = invalid_program_id;
        image_phys_values[index] = 0;
        image_entry_phys_values[index] = 0;
        image_header_size_values[index] = 0;
        image_code_size_values[index] = 0;
        image_stack_pages_values[index] = 0;
        process_ids[index] = process.invalid_id;
        thread_ids[index] = thread.invalid_id;
        index = index + 1;
    }
    used_programs = 0;
    last_status = UserProgramStatus.ok;
}

fn index_for_program(program_id: usize): usize {
    var index: usize = 0;
    while index < used_programs and index < max_programs {
        if program_ids[index] == program_id {
            return index;
        }
        index = index + 1;
    }
    return max_programs;
}

fn program_exists(program_id: usize): bool {
    return index_for_program(program_id) < max_programs;
}

fn prepared_instance_exists(program_id: usize, process_id: usize, thread_id: usize): bool {
    var index: usize = 0;
    while index < used_programs and index < max_programs {
        if program_ids[index] == program_id and process_ids[index] == process_id and thread_ids[index] == thread_id {
            return true;
        }
        index = index + 1;
    }
    return false;
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
    if used_programs >= max_programs {
        last_status = UserProgramStatus.table_full;
        return false;
    }
    if prepared_instance_exists(program_id, process_id, thread_id) {
        last_status = UserProgramStatus.duplicate_program;
        return false;
    }
    if !validate_process_thread(process_id, thread_id) {
        return false;
    }
    program_ids[used_programs] = program_id;
    image_phys_values[used_programs] = 0;
    image_entry_phys_values[used_programs] = 0;
    image_header_size_values[used_programs] = 0;
    image_code_size_values[used_programs] = 0;
    image_stack_pages_values[used_programs] = 0;
    process_ids[used_programs] = process_id;
    thread_ids[used_programs] = thread_id;
    used_programs = used_programs + 1;
    last_status = UserProgramStatus.ok;
    return true;
}

pub fn register_image(program_id: usize, image: UserImage): bool {
    if program_id == invalid_program_id {
        last_status = UserProgramStatus.invalid_program;
        return false;
    }
    if image.image_phys == 0 {
        last_status = UserProgramStatus.invalid_image;
        return false;
    }
    if program_exists(program_id) {
        last_status = UserProgramStatus.duplicate_program;
        return false;
    }
    if used_programs >= max_programs {
        last_status = UserProgramStatus.table_full;
        return false;
    }
    program_ids[used_programs] = program_id;
    image_phys_values[used_programs] = image.image_phys;
    image_entry_phys_values[used_programs] = image.entry_phys;
    image_header_size_values[used_programs] = image.header_size;
    image_code_size_values[used_programs] = image.code_size;
    image_stack_pages_values[used_programs] = image.stack_pages;
    process_ids[used_programs] = process.invalid_id;
    thread_ids[used_programs] = thread.invalid_id;
    used_programs = used_programs + 1;
    last_status = UserProgramStatus.ok;
    return true;
}

pub fn refresh_image(program_id: usize, image: UserImage): bool {
    const index = index_for_program(program_id);
    if index >= max_programs {
        last_status = UserProgramStatus.invalid_program;
        return false;
    }
    if image.image_phys == 0 {
        last_status = UserProgramStatus.invalid_image;
        return false;
    }
    image_phys_values[index] = image.image_phys;
    image_entry_phys_values[index] = image.entry_phys;
    image_header_size_values[index] = image.header_size;
    image_code_size_values[index] = image.code_size;
    image_stack_pages_values[index] = image.stack_pages;
    last_status = UserProgramStatus.ok;
    return true;
}

pub fn register_or_refresh_image(program_id: usize, image: UserImage): bool {
    if program_exists(program_id) {
        return refresh_image(program_id, image);
    }
    return register_image(program_id, image);
}

pub fn image_from_program(program: UserProgram): UserImage {
    return user_entry.image_from_parts(program.image_phys, program.image_entry_phys, program.image_header_size, program.image_code_size, program.image_stack_pages, false);
}

pub fn image_for_program(program_id: usize): UserImage {
    const index = index_for_program(program_id);
    if index >= max_programs {
        last_status = UserProgramStatus.invalid_program;
        return user_entry.image_from_parts(0, 0, 0, 0, 0, false);
    }
    if image_phys_values[index] == 0 {
        last_status = UserProgramStatus.invalid_image;
        return user_entry.image_from_parts(0, 0, 0, 0, 0, false);
    }
    last_status = UserProgramStatus.ok;
    return user_entry.image_from_parts(image_phys_values[index], image_entry_phys_values[index], image_header_size_values[index], image_code_size_values[index], image_stack_pages_values[index], false);
}

pub fn get(program_id: usize): UserProgram {
    var saw_program = false;
    var index: usize = 0;
    while index < used_programs and index < max_programs {
        if program_ids[index] == program_id {
            saw_program = true;
            const entry = UserProgram {
                program_id: program_ids[index],
                image_phys: image_phys_values[index],
                image_entry_phys: image_entry_phys_values[index],
                image_header_size: image_header_size_values[index],
                image_code_size: image_code_size_values[index],
                image_stack_pages: image_stack_pages_values[index],
                process_id: process_ids[index],
                thread_id: thread_ids[index],
            };
            if image_phys_values[index] != 0 {
                last_status = UserProgramStatus.ok;
                return entry;
            }
            if validate_process_thread(process_ids[index], thread_ids[index]) {
                last_status = UserProgramStatus.ok;
                return entry;
            }
        }
        index = index + 1;
    }
    if !saw_program {
        last_status = UserProgramStatus.invalid_program;
    }
    return empty_program();
}

pub fn count(): usize {
    return used_programs;
}

pub fn status(): UserProgramStatus {
    return last_status;
}
