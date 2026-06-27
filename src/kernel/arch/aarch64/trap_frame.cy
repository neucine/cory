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

pub struct TrapFrame {
    pub x0: usize;
    pub x1: usize;
    pub x2: usize;
    pub x3: usize;
    pub x4: usize;
    pub x5: usize;
    pub x6: usize;
    pub x7: usize;
    pub x8: usize;
    pub x9: usize;
    pub x10: usize;
    pub x11: usize;
    pub x12: usize;
    pub x13: usize;
    pub x14: usize;
    pub x15: usize;
    pub x16: usize;
    pub x17: usize;
    pub x18: usize;
    pub x19: usize;
    pub x20: usize;
    pub x21: usize;
    pub x22: usize;
    pub x23: usize;
    pub x24: usize;
    pub x25: usize;
    pub x26: usize;
    pub x27: usize;
    pub x28: usize;
    pub x29: usize;
    pub x30: usize;
    pub sp: usize;
    pub elr_el1: usize;
    pub spsr_el1: usize;
    pub esr_el1: usize;
    pub far_el1: usize;
}

pub fn diagnostic(esr_el1: c_ulong, elr_el1: c_ulong, far_el1: c_ulong, spsr_el1: c_ulong): ExceptionDiagnosticFrame {
    return ExceptionDiagnosticFrame {
        esr_el1: esr_el1 as usize,
        elr_el1: elr_el1 as usize,
        far_el1: far_el1 as usize,
        spsr_el1: spsr_el1 as usize,
    };
}
