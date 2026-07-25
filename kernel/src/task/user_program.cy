import .task.process;
import .task.thread;
import { ThreadState } from .task.thread;
import .task.user_entry;
import { UserImage } from .task.user_entry;
import .memory.user_memory;
import { Spec } from .memory.page_table;

extern c("cory_user_program_image_phys") fn platform_image_phys(program_id: c_ulong): c_ulong;
extern c("cory_user_program_image_entry_phys") fn platform_image_entry_phys(program_id: c_ulong): c_ulong;
extern c("cory_user_program_image_header_size") fn platform_image_header_size(program_id: c_ulong): c_ulong;
extern c("cory_user_program_image_code_size") fn platform_image_code_size(program_id: c_ulong): c_ulong;
extern c("cory_user_program_image_stack_pages") fn platform_image_stack_pages(program_id: c_ulong): c_ulong;

pub const invalid_program_id: usize = 0;
pub const max_programs: usize = 8;
pub const max_program_name_len: usize = 16;

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
    invalid_user_buffer,
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

fn image_from_platform(program_id: usize): UserImage {
    const image_phys = platform_image_phys(program_id as c_ulong) as usize;
    if image_phys == 0 {
        return user_entry.image_from_parts(0, 0, 0, 0, 0, false);
    }
    return user_entry.image_from_parts(
        image_phys,
        platform_image_entry_phys(program_id as c_ulong) as usize,
        platform_image_header_size(program_id as c_ulong) as usize,
        platform_image_code_size(program_id as c_ulong) as usize,
        platform_image_stack_pages(program_id as c_ulong) as usize,
        false
    );
}

fn user_byte(addr: usize, offset: usize): u8 {
    unchecked {
        return *((addr + offset) as! *u8);
    }
}

fn name_matches_selftest(addr: usize, len: usize): bool {
    if len != 8 {
        return false;
    }
    return user_byte(addr, 0) == 's' and user_byte(addr, 1) == 'e' and user_byte(addr, 2) == 'l' and user_byte(addr, 3) == 'f' and user_byte(addr, 4) == 't' and user_byte(addr, 5) == 'e' and user_byte(addr, 6) == 's' and user_byte(addr, 7) == 't';
}

fn name_matches_shell(addr: usize, len: usize): bool {
    if len != 5 {
        return false;
    }
    return user_byte(addr, 0) == 's' and user_byte(addr, 1) == 'h' and user_byte(addr, 2) == 'e' and user_byte(addr, 3) == 'l' and user_byte(addr, 4) == 'l';
}

fn name_matches_echo(addr: usize, len: usize): bool {
    if len != 4 {
        return false;
    }
    return user_byte(addr, 0) == 'e' and user_byte(addr, 1) == 'c' and user_byte(addr, 2) == 'h' and user_byte(addr, 3) == 'o';
}

fn name_matches_ps(addr: usize, len: usize): bool {
    if len != 2 {
        return false;
    }
    return user_byte(addr, 0) == 'p' and user_byte(addr, 1) == 's';
}

fn name_matches_ls(addr: usize, len: usize): bool {
    if len != 2 {
        return false;
    }
    return user_byte(addr, 0) == 'l' and user_byte(addr, 1) == 's';
}

fn name_matches_cat(addr: usize, len: usize): bool {
    if len != 3 {
        return false;
    }
    return user_byte(addr, 0) == 'c' and user_byte(addr, 1) == 'a' and user_byte(addr, 2) == 't';
}

fn name_to_program_id(addr: usize, len: usize): usize {
    if name_matches_selftest(addr, len) {
        return 1;
    }
    if name_matches_shell(addr, len) {
        return 2;
    }
    if name_matches_echo(addr, len) {
        return 3;
    }
    if name_matches_ps(addr, len) {
        return 4;
    }
    if name_matches_ls(addr, len) {
        return 5;
    }
    if name_matches_cat(addr, len) {
        return 6;
    }
    return invalid_program_id;
}

fn path_has_bin_prefix(addr: usize, len: usize): bool {
    if len <= 5 {
        return false;
    }
    return user_byte(addr, 0) == '/' and user_byte(addr, 1) == 'b' and user_byte(addr, 2) == 'i' and user_byte(addr, 3) == 'n' and user_byte(addr, 4) == '/';
}

pub fn find_by_user_name(arch: i32, process_id: usize, addr: usize, len: usize, spec: Spec): usize {
    if len == 0 or len > max_program_name_len {
        last_status = UserProgramStatus.invalid_program;
        return invalid_program_id;
    }
    if !user_memory.validate_user_range(arch, process_id, addr, len, spec) {
        last_status = UserProgramStatus.invalid_user_buffer;
        return invalid_program_id;
    }
    const program_id = name_to_program_id(addr, len);
    if program_id != invalid_program_id {
        last_status = UserProgramStatus.ok;
        return program_id;
    }
    last_status = UserProgramStatus.invalid_program;
    return invalid_program_id;
}

pub fn find_by_user_path(arch: i32, process_id: usize, addr: usize, len: usize, spec: Spec): usize {
    if len <= 5 or len > max_program_name_len + 5 {
        last_status = UserProgramStatus.invalid_program;
        return invalid_program_id;
    }
    if !user_memory.validate_user_range(arch, process_id, addr, len, spec) {
        last_status = UserProgramStatus.invalid_user_buffer;
        return invalid_program_id;
    }
    if !path_has_bin_prefix(addr, len) {
        last_status = UserProgramStatus.invalid_program;
        return invalid_program_id;
    }
    const program_id = name_to_program_id(addr + 5, len - 5);
    if program_id != invalid_program_id {
        last_status = UserProgramStatus.ok;
        return program_id;
    }
    last_status = UserProgramStatus.invalid_program;
    return invalid_program_id;
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

pub fn image_from_program(program: UserProgram): UserImage {
    return user_entry.image_from_parts(program.image_phys, program.image_entry_phys, program.image_header_size, program.image_code_size, program.image_stack_pages, false);
}

pub fn image_for_program(program_id: usize): UserImage {
    const platform_image = image_from_platform(program_id);
    if platform_image.image_phys != 0 {
        last_status = UserProgramStatus.ok;
        return platform_image;
    }
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
    const direct_image = image_from_platform(program_id);
    if direct_image.image_phys != 0 {
        last_status = UserProgramStatus.ok;
        return UserProgram {
            program_id: program_id,
            image_phys: direct_image.image_phys,
            image_entry_phys: direct_image.entry_phys,
            image_header_size: direct_image.header_size,
            image_code_size: direct_image.code_size,
            image_stack_pages: direct_image.stack_pages,
            process_id: process.invalid_id,
            thread_id: thread.invalid_id,
        };
    }
    var saw_program = false;
    var index: usize = 0;
    while index < used_programs and index < max_programs {
        if program_ids[index] == program_id {
            saw_program = true;
            const platform_image = image_from_platform(program_id);
            if platform_image.image_phys != 0 {
                last_status = UserProgramStatus.ok;
                return UserProgram {
                    program_id: program_ids[index],
                    image_phys: platform_image.image_phys,
                    image_entry_phys: platform_image.entry_phys,
                    image_header_size: platform_image.header_size,
                    image_code_size: platform_image.code_size,
                    image_stack_pages: platform_image.stack_pages,
                    process_id: process.invalid_id,
                    thread_id: thread.invalid_id,
                };
            }
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
