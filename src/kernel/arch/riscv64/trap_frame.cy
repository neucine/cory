// RISC-V trap state has two layers in Cory:
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
//
// RISC-V64 has 35 saved 8-byte values, so the C ABI payload is 280 bytes.
// trap.S reserves 288 bytes to keep the stack 16-byte aligned across the call
// into Cyna; that final 8 bytes is trap-stack padding, not a TrapFrame field.
//
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

// Public layout constants are materialized from Cyna's target C ABI metadata.
// They are the Cyna-side source for trap-frame layout checks. The `export asm`
// constants below are the assembly boundary; Cyna emits them as `.equ` values
// and injects the generated include into trap.S during native builds.
// `verify_layout` remains a boot-time guard that catches drift before trap
// vectors are installed.
pub const trap_frame_size: usize = comptime TrapFrame.size;
pub const trap_frame_align: usize = comptime TrapFrame.align;
pub const trap_frame_ra_offset: usize = comptime TrapFrame.field.ra.offset;
pub const trap_frame_sp_offset: usize = comptime TrapFrame.field.sp.offset;
pub const trap_frame_gp_offset: usize = comptime TrapFrame.field.gp.offset;
pub const trap_frame_tp_offset: usize = comptime TrapFrame.field.tp.offset;
pub const trap_frame_t0_offset: usize = comptime TrapFrame.field.t0.offset;
pub const trap_frame_t1_offset: usize = comptime TrapFrame.field.t1.offset;
pub const trap_frame_t2_offset: usize = comptime TrapFrame.field.t2.offset;
pub const trap_frame_s0_offset: usize = comptime TrapFrame.field.s0.offset;
pub const trap_frame_s1_offset: usize = comptime TrapFrame.field.s1.offset;
pub const trap_frame_a0_offset: usize = comptime TrapFrame.field.a0.offset;
pub const trap_frame_a1_offset: usize = comptime TrapFrame.field.a1.offset;
pub const trap_frame_a2_offset: usize = comptime TrapFrame.field.a2.offset;
pub const trap_frame_a3_offset: usize = comptime TrapFrame.field.a3.offset;
pub const trap_frame_a4_offset: usize = comptime TrapFrame.field.a4.offset;
pub const trap_frame_a5_offset: usize = comptime TrapFrame.field.a5.offset;
pub const trap_frame_a6_offset: usize = comptime TrapFrame.field.a6.offset;
pub const trap_frame_a7_offset: usize = comptime TrapFrame.field.a7.offset;
pub const trap_frame_s2_offset: usize = comptime TrapFrame.field.s2.offset;
pub const trap_frame_s3_offset: usize = comptime TrapFrame.field.s3.offset;
pub const trap_frame_s4_offset: usize = comptime TrapFrame.field.s4.offset;
pub const trap_frame_s5_offset: usize = comptime TrapFrame.field.s5.offset;
pub const trap_frame_s6_offset: usize = comptime TrapFrame.field.s6.offset;
pub const trap_frame_s7_offset: usize = comptime TrapFrame.field.s7.offset;
pub const trap_frame_s8_offset: usize = comptime TrapFrame.field.s8.offset;
pub const trap_frame_s9_offset: usize = comptime TrapFrame.field.s9.offset;
pub const trap_frame_s10_offset: usize = comptime TrapFrame.field.s10.offset;
pub const trap_frame_s11_offset: usize = comptime TrapFrame.field.s11.offset;
pub const trap_frame_t3_offset: usize = comptime TrapFrame.field.t3.offset;
pub const trap_frame_t4_offset: usize = comptime TrapFrame.field.t4.offset;
pub const trap_frame_t5_offset: usize = comptime TrapFrame.field.t5.offset;
pub const trap_frame_t6_offset: usize = comptime TrapFrame.field.t6.offset;
pub const trap_frame_sepc_offset: usize = comptime TrapFrame.field.sepc.offset;
pub const trap_frame_sstatus_offset: usize = comptime TrapFrame.field.sstatus.offset;
pub const trap_frame_scause_offset: usize = comptime TrapFrame.field.scause.offset;
pub const trap_frame_stval_offset: usize = comptime TrapFrame.field.stval.offset;

export asm("TF_RA") const trap_frame_asm_ra: usize = comptime TrapFrame.field.ra.offset;
export asm("TF_SP") const trap_frame_asm_sp: usize = comptime TrapFrame.field.sp.offset;
export asm("TF_GP") const trap_frame_asm_gp: usize = comptime TrapFrame.field.gp.offset;
export asm("TF_TP") const trap_frame_asm_tp: usize = comptime TrapFrame.field.tp.offset;
export asm("TF_T0") const trap_frame_asm_t0: usize = comptime TrapFrame.field.t0.offset;
export asm("TF_T1") const trap_frame_asm_t1: usize = comptime TrapFrame.field.t1.offset;
export asm("TF_T2") const trap_frame_asm_t2: usize = comptime TrapFrame.field.t2.offset;
export asm("TF_S0") const trap_frame_asm_s0: usize = comptime TrapFrame.field.s0.offset;
export asm("TF_S1") const trap_frame_asm_s1: usize = comptime TrapFrame.field.s1.offset;
export asm("TF_A0") const trap_frame_asm_a0: usize = comptime TrapFrame.field.a0.offset;
export asm("TF_A1") const trap_frame_asm_a1: usize = comptime TrapFrame.field.a1.offset;
export asm("TF_A2") const trap_frame_asm_a2: usize = comptime TrapFrame.field.a2.offset;
export asm("TF_A3") const trap_frame_asm_a3: usize = comptime TrapFrame.field.a3.offset;
export asm("TF_A4") const trap_frame_asm_a4: usize = comptime TrapFrame.field.a4.offset;
export asm("TF_A5") const trap_frame_asm_a5: usize = comptime TrapFrame.field.a5.offset;
export asm("TF_A6") const trap_frame_asm_a6: usize = comptime TrapFrame.field.a6.offset;
export asm("TF_A7") const trap_frame_asm_a7: usize = comptime TrapFrame.field.a7.offset;
export asm("TF_S2") const trap_frame_asm_s2: usize = comptime TrapFrame.field.s2.offset;
export asm("TF_S3") const trap_frame_asm_s3: usize = comptime TrapFrame.field.s3.offset;
export asm("TF_S4") const trap_frame_asm_s4: usize = comptime TrapFrame.field.s4.offset;
export asm("TF_S5") const trap_frame_asm_s5: usize = comptime TrapFrame.field.s5.offset;
export asm("TF_S6") const trap_frame_asm_s6: usize = comptime TrapFrame.field.s6.offset;
export asm("TF_S7") const trap_frame_asm_s7: usize = comptime TrapFrame.field.s7.offset;
export asm("TF_S8") const trap_frame_asm_s8: usize = comptime TrapFrame.field.s8.offset;
export asm("TF_S9") const trap_frame_asm_s9: usize = comptime TrapFrame.field.s9.offset;
export asm("TF_S10") const trap_frame_asm_s10: usize = comptime TrapFrame.field.s10.offset;
export asm("TF_S11") const trap_frame_asm_s11: usize = comptime TrapFrame.field.s11.offset;
export asm("TF_T3") const trap_frame_asm_t3: usize = comptime TrapFrame.field.t3.offset;
export asm("TF_T4") const trap_frame_asm_t4: usize = comptime TrapFrame.field.t4.offset;
export asm("TF_T5") const trap_frame_asm_t5: usize = comptime TrapFrame.field.t5.offset;
export asm("TF_T6") const trap_frame_asm_t6: usize = comptime TrapFrame.field.t6.offset;
export asm("TF_SEPC") const trap_frame_asm_sepc: usize = comptime TrapFrame.field.sepc.offset;
export asm("TF_SSTATUS") const trap_frame_asm_sstatus: usize = comptime TrapFrame.field.sstatus.offset;
export asm("TF_SCAUSE") const trap_frame_asm_scause: usize = comptime TrapFrame.field.scause.offset;
export asm("TF_STVAL") const trap_frame_asm_stval: usize = comptime TrapFrame.field.stval.offset;

// RISC-V keeps the call stack 16-byte aligned, so the assembly reservation is
// larger than the C ABI payload by one 8-byte padding slot.
export asm("TF_SIZE") const trap_frame_asm_stack_size: usize = 288;

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

pub fn instruction_pointer_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).sepc as usize;
    }
}

pub fn stack_pointer_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).sp as usize;
    }
}

pub fn status_flags_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).sstatus as usize;
    }
}

pub fn argument0_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).a0 as usize;
    }
}

pub fn set_resume_state_in_frame(frame: *TrapFrame, instruction_pointer: usize, stack_pointer: usize, status_flags: usize): void {
    unchecked {
        (*frame).sepc = instruction_pointer as c_ulong;
        (*frame).sp = stack_pointer as c_ulong;
        (*frame).sstatus = status_flags as c_ulong;
    }
}

pub fn verify_layout(): bool {
    if trap_frame_size != 280 {
        return false;
    }
    if trap_frame_align != 8 {
        return false;
    }
    if trap_frame_ra_offset != 0 {
        return false;
    }
    if trap_frame_sp_offset != 8 {
        return false;
    }
    if trap_frame_gp_offset != 16 {
        return false;
    }
    if trap_frame_tp_offset != 24 {
        return false;
    }
    if trap_frame_t0_offset != 32 {
        return false;
    }
    if trap_frame_t1_offset != 40 {
        return false;
    }
    if trap_frame_t2_offset != 48 {
        return false;
    }
    if trap_frame_s0_offset != 56 {
        return false;
    }
    if trap_frame_s1_offset != 64 {
        return false;
    }
    if trap_frame_a0_offset != 72 {
        return false;
    }
    if trap_frame_a1_offset != 80 {
        return false;
    }
    if trap_frame_a2_offset != 88 {
        return false;
    }
    if trap_frame_a3_offset != 96 {
        return false;
    }
    if trap_frame_a4_offset != 104 {
        return false;
    }
    if trap_frame_a5_offset != 112 {
        return false;
    }
    if trap_frame_a6_offset != 120 {
        return false;
    }
    if trap_frame_a7_offset != 128 {
        return false;
    }
    if trap_frame_s2_offset != 136 {
        return false;
    }
    if trap_frame_s3_offset != 144 {
        return false;
    }
    if trap_frame_s4_offset != 152 {
        return false;
    }
    if trap_frame_s5_offset != 160 {
        return false;
    }
    if trap_frame_s6_offset != 168 {
        return false;
    }
    if trap_frame_s7_offset != 176 {
        return false;
    }
    if trap_frame_s8_offset != 184 {
        return false;
    }
    if trap_frame_s9_offset != 192 {
        return false;
    }
    if trap_frame_s10_offset != 200 {
        return false;
    }
    if trap_frame_s11_offset != 208 {
        return false;
    }
    if trap_frame_t3_offset != 216 {
        return false;
    }
    if trap_frame_t4_offset != 224 {
        return false;
    }
    if trap_frame_t5_offset != 232 {
        return false;
    }
    if trap_frame_t6_offset != 240 {
        return false;
    }
    if trap_frame_sepc_offset != 248 {
        return false;
    }
    if trap_frame_sstatus_offset != 256 {
        return false;
    }
    if trap_frame_scause_offset != 264 {
        return false;
    }
    if trap_frame_stval_offset != 272 {
        return false;
    }
    return true;
}
