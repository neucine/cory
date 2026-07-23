pub const invalid_key: usize = 0;

pub const status_ok: i32 = 0;
pub const status_full: i32 = 1;
pub const status_invalid_key: i32 = 2;

pub struct StaticSlotMap<T, const N: usize> {
    pub values: [N]T;
    pub live: [N]bool;
    pub generations: [N]usize;
    pub live_count: usize;
    pub last_status: i32;

    pub fn capacity(self: StaticSlotMap<T, N>): usize {
        return N;
    }

    pub fn clear(self: &StaticSlotMap<T, N>): void {
        const cap = self.capacity();
        var index: usize = 0;
        while index < cap {
            if self.live[index] {
                self.generations[index] = self.generations[index] + 1;
            }
            self.live[index] = false;
            index = index + 1;
        }
        self.live_count = 0;
        self.last_status = status_ok;
    }

    pub fn key(self: &StaticSlotMap<T, N>, index: usize, generation: usize): usize {
        return key(self.capacity(), index, generation);
    }

    pub fn index(self: &StaticSlotMap<T, N>, key: usize): usize {
        return index(self.capacity(), key);
    }

    pub fn generation(self: &StaticSlotMap<T, N>, key: usize): usize {
        return generation(self.capacity(), key);
    }

    pub fn contains(self: &StaticSlotMap<T, N>, key: usize): bool {
        const cap = self.capacity();
        const key_index = self.index(key);
        if key_index >= cap {
            self.last_status = status_invalid_key;
            return false;
        }
        if !self.live[key_index] {
            self.last_status = status_invalid_key;
            return false;
        }
        if self.generations[key_index] != self.generation(key) {
            self.last_status = status_invalid_key;
            return false;
        }
        self.last_status = status_ok;
        return true;
    }

    pub fn insert(self: &StaticSlotMap<T, N>, value: T): usize {
        const cap = self.capacity();
        if self.live_count >= cap {
            self.last_status = status_full;
            return invalid_key;
        }
        var index: usize = 0;
        while index < cap {
            if !self.live[index] {
                self.values[index] = value;
                self.live[index] = true;
                self.live_count = self.live_count + 1;
                self.last_status = status_ok;
                return self.key(index, self.generations[index]);
            }
            index = index + 1;
        }
        self.last_status = status_full;
        return invalid_key;
    }

    pub fn reserve(self: &StaticSlotMap<T, N>): usize {
        const cap = self.capacity();
        if self.live_count >= cap {
            self.last_status = status_full;
            return invalid_key;
        }
        var index: usize = 0;
        while index < cap {
            if !self.live[index] {
                self.live[index] = true;
                self.live_count = self.live_count + 1;
                self.last_status = status_ok;
                return self.key(index, self.generations[index]);
            }
            index = index + 1;
        }
        self.last_status = status_full;
        return invalid_key;
    }

    pub fn get(self: &StaticSlotMap<T, N>, key: usize): ?T {
        if !self.contains(key) {
            return none;
        }
        return self.values[self.index(key)];
    }

    pub fn set(self: &StaticSlotMap<T, N>, key: usize, value: T): bool {
        if !self.contains(key) {
            return false;
        }
        self.values[self.index(key)] = value;
        self.last_status = status_ok;
        return true;
    }

    pub fn remove(self: &StaticSlotMap<T, N>, key: usize): ?T {
        if !self.contains(key) {
            return none;
        }
        const key_index = self.index(key);
        const value = self.values[key_index];
        self.live[key_index] = false;
        self.generations[key_index] = self.generations[key_index] + 1;
        self.live_count = self.live_count - 1;
        self.last_status = status_ok;
        return value;
    }

    pub fn count(self: &StaticSlotMap<T, N>): usize {
        return self.live_count;
    }

    pub fn status(self: &StaticSlotMap<T, N>): i32 {
        return self.last_status;
    }
}

pub fn key(capacity: usize, index: usize, generation: usize): usize {
    if capacity == 0 {
        return invalid_key;
    }
    if index >= capacity {
        return invalid_key;
    }
    return (generation * capacity) + index + 1;
}

pub fn index(capacity: usize, key: usize): usize {
    if capacity == 0 {
        return 0;
    }
    if key == invalid_key {
        return capacity;
    }
    const raw = key - 1;
    const key_generation = raw / capacity;
    return raw - (key_generation * capacity);
}

pub fn generation(capacity: usize, key: usize): usize {
    if capacity == 0 {
        return 0;
    }
    if key == invalid_key {
        return 0;
    }
    return (key - 1) / capacity;
}
