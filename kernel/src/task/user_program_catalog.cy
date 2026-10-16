pub const invalid_program_id: usize = 0;
pub const selftest: usize = 1;
pub const shell: usize = 2;
pub const echo: usize = 3;
pub const ps: usize = 4;
pub const ls: usize = 5;
pub const cat: usize = 6;
pub const max_name_len: usize = 16;
pub const bin_prefix_len: usize = 5;

fn user_byte(addr: usize, offset: usize): u8 {
    unchecked {
        return *((addr + offset) as! *u8);
    }
}

pub fn name_len(program_id: usize): usize {
    if program_id == selftest {
        return 8;
    }
    if program_id == shell {
        return 5;
    }
    if program_id == echo {
        return 4;
    }
    if program_id == ps {
        return 2;
    }
    if program_id == ls {
        return 2;
    }
    if program_id == cat {
        return 3;
    }
    return 0;
}

// A typed local shapes an ASCII rune into a byte on the current compiler.
pub fn name_byte(program_id: usize, offset: usize): u8 {
    if program_id == selftest {
        if offset == 0 {
            const byte: u8 = 's';
            return byte;
        }
        if offset == 1 {
            const byte: u8 = 'e';
            return byte;
        }
        if offset == 2 {
            const byte: u8 = 'l';
            return byte;
        }
        if offset == 3 {
            const byte: u8 = 'f';
            return byte;
        }
        if offset == 4 {
            const byte: u8 = 't';
            return byte;
        }
        if offset == 5 {
            const byte: u8 = 'e';
            return byte;
        }
        if offset == 6 {
            const byte: u8 = 's';
            return byte;
        }
        if offset == 7 {
            const byte: u8 = 't';
            return byte;
        }
    }
    if program_id == shell {
        if offset == 0 {
            const byte: u8 = 's';
            return byte;
        }
        if offset == 1 {
            const byte: u8 = 'h';
            return byte;
        }
        if offset == 2 {
            const byte: u8 = 'e';
            return byte;
        }
        if offset == 3 {
            const byte: u8 = 'l';
            return byte;
        }
        if offset == 4 {
            const byte: u8 = 'l';
            return byte;
        }
    }
    if program_id == echo {
        if offset == 0 {
            const byte: u8 = 'e';
            return byte;
        }
        if offset == 1 {
            const byte: u8 = 'c';
            return byte;
        }
        if offset == 2 {
            const byte: u8 = 'h';
            return byte;
        }
        if offset == 3 {
            const byte: u8 = 'o';
            return byte;
        }
    }
    if program_id == ps {
        if offset == 0 {
            const byte: u8 = 'p';
            return byte;
        }
        if offset == 1 {
            const byte: u8 = 's';
            return byte;
        }
    }
    if program_id == ls {
        if offset == 0 {
            const byte: u8 = 'l';
            return byte;
        }
        if offset == 1 {
            const byte: u8 = 's';
            return byte;
        }
    }
    if program_id == cat {
        if offset == 0 {
            const byte: u8 = 'c';
            return byte;
        }
        if offset == 1 {
            const byte: u8 = 'a';
            return byte;
        }
        if offset == 2 {
            const byte: u8 = 't';
            return byte;
        }
    }
    return 0;
}

pub fn bin_path_len(program_id: usize): usize {
    const len = name_len(program_id);
    if len == 0 {
        return 0;
    }
    return bin_prefix_len + len;
}

pub fn bin_path_byte(program_id: usize, offset: usize): u8 {
    if offset == 0 {
        const byte: u8 = '/';
        return byte;
    }
    if offset == 1 {
        const byte: u8 = 'b';
        return byte;
    }
    if offset == 2 {
        const byte: u8 = 'i';
        return byte;
    }
    if offset == 3 {
        const byte: u8 = 'n';
        return byte;
    }
    if offset == 4 {
        const byte: u8 = '/';
        return byte;
    }
    return name_byte(program_id, offset - bin_prefix_len);
}

fn name_matches_user(program_id: usize, addr: usize, len: usize): bool {
    if len != name_len(program_id) {
        return false;
    }
    var index: usize = 0;
    while index < len {
        if user_byte(addr, index) != name_byte(program_id, index) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

pub fn name_to_program_id(addr: usize, len: usize): usize {
    if name_matches_user(selftest, addr, len) {
        return selftest;
    }
    if name_matches_user(shell, addr, len) {
        return shell;
    }
    if name_matches_user(echo, addr, len) {
        return echo;
    }
    if name_matches_user(ps, addr, len) {
        return ps;
    }
    if name_matches_user(ls, addr, len) {
        return ls;
    }
    if name_matches_user(cat, addr, len) {
        return cat;
    }
    return invalid_program_id;
}

fn path_has_bin_prefix(addr: usize, len: usize): bool {
    if len <= bin_prefix_len {
        return false;
    }
    const slash: u8 = '/';
    const b: u8 = 'b';
    const i: u8 = 'i';
    const n: u8 = 'n';
    return user_byte(addr, 0) == slash and user_byte(addr, 1) == b and user_byte(addr, 2) == i and user_byte(addr, 3) == n and user_byte(addr, 4) == slash;
}

pub fn path_to_program_id(addr: usize, len: usize): usize {
    if !path_has_bin_prefix(addr, len) {
        return invalid_program_id;
    }
    return name_to_program_id(addr + bin_prefix_len, len - bin_prefix_len);
}
