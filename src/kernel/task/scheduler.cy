import .kernel.task.thread;
import { ThreadState } from .kernel.task.thread;

pub const max_run_queue: usize = 16;

pub enum SchedulerStatus: i32 {
    ok = 0,
    empty,
    full,
    invalid_thread,
    not_ready,
    duplicate,
}

var run_queue: [16]usize = [0] ** 16;
var queued_count: usize = 0;
var current_thread: usize = thread.invalid_id;
var last_status: SchedulerStatus = SchedulerStatus.ok;

pub fn init(): void {
    var index: usize = 0;
    while index < max_run_queue {
        run_queue[index] = thread.invalid_id;
        index = index + 1;
    }
    queued_count = 0;
    current_thread = thread.invalid_id;
    last_status = SchedulerStatus.ok;
}

fn queue_index(thread_id: usize): usize {
    var index: usize = 0;
    while index < queued_count {
        if run_queue[index] == thread_id {
            return index;
        }
        index = index + 1;
    }
    return max_run_queue;
}

pub fn set_current(thread_id: usize): bool {
    if thread.get(thread_id).id == thread.invalid_id {
        last_status = SchedulerStatus.invalid_thread;
        return false;
    }
    if !thread.mark_running(thread_id) {
        last_status = SchedulerStatus.invalid_thread;
        return false;
    }
    current_thread = thread_id;
    last_status = SchedulerStatus.ok;
    return true;
}

pub fn current(): usize {
    return current_thread;
}

pub fn enqueue(thread_id: usize): bool {
    const entry = thread.get(thread_id);
    if entry.id == thread.invalid_id {
        last_status = SchedulerStatus.invalid_thread;
        return false;
    }
    if entry.state != ThreadState.ready {
        last_status = SchedulerStatus.not_ready;
        return false;
    }
    if queue_index(thread_id) < max_run_queue {
        last_status = SchedulerStatus.duplicate;
        return false;
    }
    if queued_count >= max_run_queue {
        last_status = SchedulerStatus.full;
        return false;
    }
    run_queue[queued_count] = thread_id;
    queued_count = queued_count + 1;
    last_status = SchedulerStatus.ok;
    return true;
}

pub fn peek(): usize {
    if queued_count == 0 {
        last_status = SchedulerStatus.empty;
        return thread.invalid_id;
    }
    last_status = SchedulerStatus.ok;
    return run_queue[0];
}

pub fn dequeue(): usize {
    if queued_count == 0 {
        last_status = SchedulerStatus.empty;
        return thread.invalid_id;
    }
    const thread_id = run_queue[0];
    var index: usize = 1;
    while index < queued_count {
        run_queue[index - 1] = run_queue[index];
        index = index + 1;
    }
    queued_count = queued_count - 1;
    run_queue[queued_count] = thread.invalid_id;
    last_status = SchedulerStatus.ok;
    return thread_id;
}

pub fn schedule_next(): usize {
    if queued_count == 0 {
        last_status = SchedulerStatus.empty;
        return current_thread;
    }

    const previous = current_thread;
    const next = dequeue();
    if next == thread.invalid_id {
        return thread.invalid_id;
    }

    const previous_entry = thread.get(previous);
    if previous_entry.id != thread.invalid_id and previous_entry.state == ThreadState.running {
        if !thread.mark_ready(previous) {
            last_status = SchedulerStatus.invalid_thread;
            return thread.invalid_id;
        }
        if !enqueue(previous) {
            return thread.invalid_id;
        }
    }

    if !set_current(next) {
        return thread.invalid_id;
    }
    last_status = SchedulerStatus.ok;
    return next;
}

pub fn count(): usize {
    return queued_count;
}

pub fn status(): SchedulerStatus {
    return last_status;
}
