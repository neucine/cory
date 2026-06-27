// AArch64 trap state has two layers in Cycor:
//
// - ExceptionDiagnosticFrame is the small state snapshot passed by the current
//   panic-only vector path. It is enough to explain an unhandled exception.
// - TrapFrame is the future recoverable context shape. Scheduler, user-mode
//   return, and signal-style recovery must save the full general register set,
//   not only the exception syndrome registers.

pub struct ExceptionDiagnosticFrame {
    pub esr_el1: usize;
    pub elr_el1: usize;
    pub far_el1: usize;
    pub spsr_el1: usize;
}

// Assembly saves this frame directly on the active exception stack before
// calling Cyna. Field order is therefore an ABI between exception.S and this
// module; append or reorder fields only together with the assembly offsets.
pub cstruct TrapFrame {
    x0: c_ulong;
    x1: c_ulong;
    x2: c_ulong;
    x3: c_ulong;
    x4: c_ulong;
    x5: c_ulong;
    x6: c_ulong;
    x7: c_ulong;
    x8: c_ulong;
    x9: c_ulong;
    x10: c_ulong;
    x11: c_ulong;
    x12: c_ulong;
    x13: c_ulong;
    x14: c_ulong;
    x15: c_ulong;
    x16: c_ulong;
    x17: c_ulong;
    x18: c_ulong;
    x19: c_ulong;
    x20: c_ulong;
    x21: c_ulong;
    x22: c_ulong;
    x23: c_ulong;
    x24: c_ulong;
    x25: c_ulong;
    x26: c_ulong;
    x27: c_ulong;
    x28: c_ulong;
    x29: c_ulong;
    x30: c_ulong;
    sp: c_ulong;
    elr_el1: c_ulong;
    spsr_el1: c_ulong;
    esr_el1: c_ulong;
    far_el1: c_ulong;
}

pub fn diagnostic(esr_el1: c_ulong, elr_el1: c_ulong, far_el1: c_ulong, spsr_el1: c_ulong): ExceptionDiagnosticFrame {
    return ExceptionDiagnosticFrame {
        esr_el1: esr_el1 as usize,
        elr_el1: elr_el1 as usize,
        far_el1: far_el1 as usize,
        spsr_el1: spsr_el1 as usize,
    };
}

pub fn diagnostic_from_frame(frame: *TrapFrame): ExceptionDiagnosticFrame {
    unchecked {
        return ExceptionDiagnosticFrame {
            esr_el1: (*frame).esr_el1 as usize,
            elr_el1: (*frame).elr_el1 as usize,
            far_el1: (*frame).far_el1 as usize,
            spsr_el1: (*frame).spsr_el1 as usize,
        };
    }
}
