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

pub struct TrapFrame {
    pub ra: usize;
    pub sp: usize;
    pub gp: usize;
    pub tp: usize;
    pub t0: usize;
    pub t1: usize;
    pub t2: usize;
    pub s0: usize;
    pub s1: usize;
    pub a0: usize;
    pub a1: usize;
    pub a2: usize;
    pub a3: usize;
    pub a4: usize;
    pub a5: usize;
    pub a6: usize;
    pub a7: usize;
    pub s2: usize;
    pub s3: usize;
    pub s4: usize;
    pub s5: usize;
    pub s6: usize;
    pub s7: usize;
    pub s8: usize;
    pub s9: usize;
    pub s10: usize;
    pub s11: usize;
    pub t3: usize;
    pub t4: usize;
    pub t5: usize;
    pub t6: usize;
    pub sepc: usize;
    pub sstatus: usize;
    pub scause: usize;
    pub stval: usize;
}

pub fn diagnostic(scause: c_ulong, sepc: c_ulong, stval: c_ulong, sstatus: c_ulong): TrapDiagnosticFrame {
    return TrapDiagnosticFrame {
        scause: scause as usize,
        sepc: sepc as usize,
        stval: stval as usize,
        sstatus: sstatus as usize,
    };
}
