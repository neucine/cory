packed struct Data {
    value: u8;
}

packed struct Flags {
    value: u32;
}

const flag_receive_fifo_empty: u32 = 16;
const no_input: usize = 256;

fn data(): *volatile Data {
    unchecked {
        return 0x09000000 as! *volatile Data;
    }
}

fn flag_register(): *volatile Flags {
    unchecked {
        return 0x09000018 as! *volatile Flags;
    }
}

pub fn tx(ch: u8): void {
    unchecked {
        (*data()).value = ch;
    }
}

pub fn try_rx(): usize {
    unchecked {
        if ((*flag_register()).value & flag_receive_fifo_empty) != 0 {
            return no_input;
        }
        return (*data()).value as usize;
    }
}
