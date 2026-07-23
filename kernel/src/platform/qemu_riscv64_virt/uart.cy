packed struct Data {
    value: u8;
}

packed struct LineStatus {
    value: u8;
}

const line_status_data_ready: u8 = 1;
const no_input: usize = 256;

fn data(): *volatile Data {
    unchecked {
        return 0x10000000 as! *volatile Data;
    }
}

fn line_status(): *volatile LineStatus {
    unchecked {
        return 0x10000005 as! *volatile LineStatus;
    }
}

pub fn tx(ch: u8): void {
    unchecked {
        (*data()).value = ch;
    }
}

pub fn try_rx(): usize {
    unchecked {
        if ((*line_status()).value & line_status_data_ready) == 0 {
            return no_input;
        }
        return (*data()).value as usize;
    }
}
