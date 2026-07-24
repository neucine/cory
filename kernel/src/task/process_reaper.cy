import .memory.address_space;
import .memory.page_table_pages;
import .memory.phys;
import .task.context;
import .task.process;
import { ProcessStatus } from .task.process;
import .task.process_arg;
import .task.process_resources;
import .task.thread;

pub enum ReapStatus: i32 {
    ok = 0,
    invalid_process,
    not_exited,
    missing_thread,
    missing_stack,
    context_release_failed,
    thread_release_failed,
    process_release_failed,
    address_space_release_failed,
    stack_page_release_failed,
    page_table_release_failed,
}

var last_status: ReapStatus = ReapStatus.ok;

fn process_status_to_reap_status(): ReapStatus {
    if process.status() == ProcessStatus.not_exited {
        return ReapStatus.not_exited;
    }
    return ReapStatus.invalid_process;
}

pub fn reap_exited_user(process_id: usize): usize {
    const proc = process.get(process_id);
    if proc.id == process.invalid_id {
        last_status = ReapStatus.invalid_process;
        return 0;
    }
    if !proc.exited {
        last_status = ReapStatus.not_exited;
        return 0;
    }

    const child_thread = thread.first_for_process(process_id);
    if child_thread == thread.invalid_id {
        last_status = ReapStatus.missing_thread;
        return 0;
    }
    const stack_phys = process_resources.stack_phys(process_id);
    if stack_phys == 0 {
        last_status = ReapStatus.missing_stack;
        return 0;
    }
    if !context.release_for_thread(child_thread) {
        last_status = ReapStatus.context_release_failed;
        return 0;
    }
    if !thread.release(child_thread) {
        last_status = ReapStatus.thread_release_failed;
        return 0;
    }

    const child_address_space = proc.address_space_id;
    const child_root = address_space.root_table(child_address_space);
    process_arg.clear_for_process(process_id);
    process_resources.clear(process_id);
    const code = process.reap_exited(process_id);
    if process.status() != ProcessStatus.ok {
        last_status = process_status_to_reap_status();
        return 0;
    }
    if !phys.free_page(stack_phys) {
        last_status = ReapStatus.stack_page_release_failed;
        return 0;
    }
    if !page_table_pages.free_for_root(child_root) {
        last_status = ReapStatus.page_table_release_failed;
        return 0;
    }
    if !address_space.release(child_address_space) {
        last_status = ReapStatus.address_space_release_failed;
        return 0;
    }

    last_status = ReapStatus.ok;
    return code;
}

pub fn status(): ReapStatus {
    return last_status;
}
