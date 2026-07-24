import .memory.phys;

pub const max_roots: usize = 16;
pub const max_pages_per_root: usize = 64;

var root_values: [16]usize = [0] ** 16;
var page_values: [1024]usize = [0] ** 1024;
var page_counts: [16]usize = [0] ** 16;
var used_roots: usize = 0;

fn page_slot(root_index: usize, page_index: usize): usize {
    return (root_index * max_pages_per_root) + page_index;
}

fn index_for_root(root: usize): usize {
    var index: usize = 0;
    while index < max_roots {
        if root_values[index] == root {
            return index;
        }
        index = index + 1;
    }
    return max_roots;
}

pub fn init(): void {
    var root_index: usize = 0;
    while root_index < max_roots {
        root_values[root_index] = 0;
        page_counts[root_index] = 0;
        var page_index: usize = 0;
        while page_index < max_pages_per_root {
            page_values[page_slot(root_index, page_index)] = 0;
            page_index = page_index + 1;
        }
        root_index = root_index + 1;
    }
    used_roots = 0;
}

pub fn register_root(root: usize): bool {
    if root == 0 {
        return false;
    }
    if index_for_root(root) < max_roots {
        return true;
    }
    var index: usize = 0;
    while index < max_roots {
        if root_values[index] == 0 {
            root_values[index] = root;
            page_counts[index] = 0;
            if index >= used_roots {
                used_roots = index + 1;
            }
            return true;
        }
        index = index + 1;
    }
    return false;
}

pub fn record_for_root(root: usize, page: usize): bool {
    const root_index = index_for_root(root);
    if root_index >= max_roots {
        return true;
    }
    if page_counts[root_index] >= max_pages_per_root {
        return false;
    }
    page_values[page_slot(root_index, page_counts[root_index])] = page;
    page_counts[root_index] = page_counts[root_index] + 1;
    return true;
}

pub fn free_for_root(root: usize): bool {
    const root_index = index_for_root(root);
    if root_index >= max_roots {
        return false;
    }
    var page_index = page_counts[root_index];
    while page_index > 0 {
        page_index = page_index - 1;
        if !phys.free_page(page_values[page_slot(root_index, page_index)]) {
            return false;
        }
        page_values[page_slot(root_index, page_index)] = 0;
    }
    page_counts[root_index] = 0;
    if !phys.free_page(root) {
        return false;
    }
    root_values[root_index] = 0;
    return true;
}
