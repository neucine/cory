import .collections.slot_map;
import .task.process;

var stack_phys_values: [8]usize = [0] ** 8;

fn index_for_process(process_id: usize): usize {
    const index = slot_map.index(process.max_processes, process_id);
    if index >= process.max_processes {
        return process.max_processes;
    }
    return index;
}

pub fn init(): void {
    var index: usize = 0;
    while index < process.max_processes {
        stack_phys_values[index] = 0;
        index = index + 1;
    }
}

pub fn set_stack_phys(process_id: usize, stack_phys: usize): bool {
    const index = index_for_process(process_id);
    if index >= process.max_processes {
        return false;
    }
    stack_phys_values[index] = stack_phys;
    return true;
}

pub fn stack_phys(process_id: usize): usize {
    const index = index_for_process(process_id);
    if index >= process.max_processes {
        return 0;
    }
    return stack_phys_values[index];
}

pub fn clear(process_id: usize): void {
    const index = index_for_process(process_id);
    if index >= process.max_processes {
        return;
    }
    stack_phys_values[index] = 0;
}
