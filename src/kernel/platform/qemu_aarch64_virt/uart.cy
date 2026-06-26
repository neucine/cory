packed struct Data {
    value: u8;
}

fn data(): *volatile Data {
    unchecked {
        return 0x09000000 as! *volatile Data;
    }
}

pub fn tx(ch: u8): void {
    unchecked {
        (*data()).value = ch;
    }
}
