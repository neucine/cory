// RISC-V trap state has two layers in Cycor:
//
// - TrapDiagnosticFrame is the small state snapshot passed by the current
//   panic-only vector path. It is enough to explain an unhandled trap.
// - TrapFrame is the future recoverable context shape. Scheduler, user-mode
//   return, and syscall/trap recovery must save the full integer register set,
//   not only the supervisor trap CSRs.

pub struct TrapDiagnosticFrame {
    pub scause: usize;
    pub sepc: usize;
    pub stval: usize;
    pub sstatus: usize;
}

// Assembly saves this frame directly on the active trap stack before calling
// Cyna. Field order is therefore an ABI between trap.S and this module; append
// or reorder fields only together with the assembly offsets.
pub cstruct TrapFrame {
    ra: c_ulong;
    sp: c_ulong;
    gp: c_ulong;
    tp: c_ulong;
    t0: c_ulong;
    t1: c_ulong;
    t2: c_ulong;
    s0: c_ulong;
    s1: c_ulong;
    a0: c_ulong;
    a1: c_ulong;
    a2: c_ulong;
    a3: c_ulong;
    a4: c_ulong;
    a5: c_ulong;
    a6: c_ulong;
    a7: c_ulong;
    s2: c_ulong;
    s3: c_ulong;
    s4: c_ulong;
    s5: c_ulong;
    s6: c_ulong;
    s7: c_ulong;
    s8: c_ulong;
    s9: c_ulong;
    s10: c_ulong;
    s11: c_ulong;
    t3: c_ulong;
    t4: c_ulong;
    t5: c_ulong;
    t6: c_ulong;
    sepc: c_ulong;
    sstatus: c_ulong;
    scause: c_ulong;
    stval: c_ulong;
}

pub fn diagnostic(scause: c_ulong, sepc: c_ulong, stval: c_ulong, sstatus: c_ulong): TrapDiagnosticFrame {
    return TrapDiagnosticFrame {
        scause: scause as usize,
        sepc: sepc as usize,
        stval: stval as usize,
        sstatus: sstatus as usize,
    };
}

pub fn diagnostic_from_frame(frame: *TrapFrame): TrapDiagnosticFrame {
    unchecked {
        return TrapDiagnosticFrame {
            scause: (*frame).scause as usize,
            sepc: (*frame).sepc as usize,
            stval: (*frame).stval as usize,
            sstatus: (*frame).sstatus as usize,
        };
    }
}
