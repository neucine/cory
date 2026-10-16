// AArch64 trap state has two layers in Cory:
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
//
pub c struct TrapFrame {
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

pub const empty_frame_value: TrapFrame = {
    x0: 0,
    x1: 0,
    x2: 0,
    x3: 0,
    x4: 0,
    x5: 0,
    x6: 0,
    x7: 0,
    x8: 0,
    x9: 0,
    x10: 0,
    x11: 0,
    x12: 0,
    x13: 0,
    x14: 0,
    x15: 0,
    x16: 0,
    x17: 0,
    x18: 0,
    x19: 0,
    x20: 0,
    x21: 0,
    x22: 0,
    x23: 0,
    x24: 0,
    x25: 0,
    x26: 0,
    x27: 0,
    x28: 0,
    x29: 0,
    x30: 0,
    sp: 0,
    elr_el1: 0,
    spsr_el1: 0,
    esr_el1: 0,
    far_el1: 0,
};

// Public layout constants are materialized from Cyna's target C ABI metadata.
// They are the Cyna-side source for trap-frame layout checks. The `export asm`
// constants below are the assembly boundary; Cyna emits them as `.equ` values
// and injects the generated include into exception.S during native builds.
// `verify_layout` remains a boot-time guard that catches drift before exception
// vectors are installed.
pub const trap_frame_size: usize = comptime TrapFrame.size;
pub const trap_frame_align: usize = comptime TrapFrame.align;
pub const trap_frame_x0_offset: usize = comptime TrapFrame.field.x0.offset;
pub const trap_frame_x2_offset: usize = comptime TrapFrame.field.x2.offset;
pub const trap_frame_x4_offset: usize = comptime TrapFrame.field.x4.offset;
pub const trap_frame_x6_offset: usize = comptime TrapFrame.field.x6.offset;
pub const trap_frame_x8_offset: usize = comptime TrapFrame.field.x8.offset;
pub const trap_frame_x10_offset: usize = comptime TrapFrame.field.x10.offset;
pub const trap_frame_x12_offset: usize = comptime TrapFrame.field.x12.offset;
pub const trap_frame_x14_offset: usize = comptime TrapFrame.field.x14.offset;
pub const trap_frame_x16_offset: usize = comptime TrapFrame.field.x16.offset;
pub const trap_frame_x18_offset: usize = comptime TrapFrame.field.x18.offset;
pub const trap_frame_x20_offset: usize = comptime TrapFrame.field.x20.offset;
pub const trap_frame_x22_offset: usize = comptime TrapFrame.field.x22.offset;
pub const trap_frame_x24_offset: usize = comptime TrapFrame.field.x24.offset;
pub const trap_frame_x26_offset: usize = comptime TrapFrame.field.x26.offset;
pub const trap_frame_x28_offset: usize = comptime TrapFrame.field.x28.offset;
pub const trap_frame_x30_offset: usize = comptime TrapFrame.field.x30.offset;
pub const trap_frame_sp_offset: usize = comptime TrapFrame.field.sp.offset;
pub const trap_frame_elr_el1_offset: usize = comptime TrapFrame.field.elr_el1.offset;
pub const trap_frame_spsr_el1_offset: usize = comptime TrapFrame.field.spsr_el1.offset;
pub const trap_frame_esr_el1_offset: usize = comptime TrapFrame.field.esr_el1.offset;
pub const trap_frame_far_el1_offset: usize = comptime TrapFrame.field.far_el1.offset;

export asm("TF_X0") const trap_frame_asm_x0: usize = comptime TrapFrame.field.x0.offset;
export asm("TF_X2") const trap_frame_asm_x2: usize = comptime TrapFrame.field.x2.offset;
export asm("TF_X4") const trap_frame_asm_x4: usize = comptime TrapFrame.field.x4.offset;
export asm("TF_X6") const trap_frame_asm_x6: usize = comptime TrapFrame.field.x6.offset;
export asm("TF_X8") const trap_frame_asm_x8: usize = comptime TrapFrame.field.x8.offset;
export asm("TF_X10") const trap_frame_asm_x10: usize = comptime TrapFrame.field.x10.offset;
export asm("TF_X12") const trap_frame_asm_x12: usize = comptime TrapFrame.field.x12.offset;
export asm("TF_X14") const trap_frame_asm_x14: usize = comptime TrapFrame.field.x14.offset;
export asm("TF_X16") const trap_frame_asm_x16: usize = comptime TrapFrame.field.x16.offset;
export asm("TF_X18") const trap_frame_asm_x18: usize = comptime TrapFrame.field.x18.offset;
export asm("TF_X20") const trap_frame_asm_x20: usize = comptime TrapFrame.field.x20.offset;
export asm("TF_X22") const trap_frame_asm_x22: usize = comptime TrapFrame.field.x22.offset;
export asm("TF_X24") const trap_frame_asm_x24: usize = comptime TrapFrame.field.x24.offset;
export asm("TF_X26") const trap_frame_asm_x26: usize = comptime TrapFrame.field.x26.offset;
export asm("TF_X28") const trap_frame_asm_x28: usize = comptime TrapFrame.field.x28.offset;
export asm("TF_X30") const trap_frame_asm_x30: usize = comptime TrapFrame.field.x30.offset;
export asm("TF_SP") const trap_frame_asm_sp: usize = comptime TrapFrame.field.sp.offset;
export asm("TF_ELR_EL1") const trap_frame_asm_elr_el1: usize = comptime TrapFrame.field.elr_el1.offset;
export asm("TF_SPSR_EL1") const trap_frame_asm_spsr_el1: usize = comptime TrapFrame.field.spsr_el1.offset;
export asm("TF_ESR_EL1") const trap_frame_asm_esr_el1: usize = comptime TrapFrame.field.esr_el1.offset;
export asm("TF_FAR_EL1") const trap_frame_asm_far_el1: usize = comptime TrapFrame.field.far_el1.offset;
export asm("TF_SIZE") const trap_frame_asm_size: usize = comptime TrapFrame.size;

pub fn diagnostic(esr_el1: c_ulong, elr_el1: c_ulong, far_el1: c_ulong, spsr_el1: c_ulong): ExceptionDiagnosticFrame {
    return ExceptionDiagnosticFrame {
        esr_el1: esr_el1 as usize,
        elr_el1: elr_el1 as usize,
        far_el1: far_el1 as usize,
        spsr_el1: spsr_el1 as usize,
    };
}

pub fn copy_frame_with_resume(frame: *TrapFrame, instruction_pointer: usize): TrapFrame {
    unchecked {
        var saved = *frame;
        saved.elr_el1 = instruction_pointer as c_ulong;
        return saved;
    }
}

pub fn frame_with_resume_state(instruction_pointer: usize, stack_pointer: usize, status_flags: usize): TrapFrame {
    var frame = empty_frame_value;
    unchecked {
        frame.elr_el1 = instruction_pointer as c_ulong;
        frame.sp = stack_pointer as c_ulong;
        frame.spsr_el1 = status_flags as c_ulong;
    }
    return frame;
}

pub fn write_frame(destination: *TrapFrame, source: TrapFrame): void {
    unchecked {
        *destination = source;
    }
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

pub fn instruction_pointer_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).elr_el1 as usize;
    }
}

pub fn explicit_resume_ip_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).x1 as usize;
    }
}

pub fn argument0_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).x0 as usize;
    }
}

pub fn argument2_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).x2 as usize;
    }
}

pub fn argument3_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).x3 as usize;
    }
}

pub fn argument4_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).x4 as usize;
    }
}

pub fn stack_pointer_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).sp as usize;
    }
}

pub fn status_flags_from_frame(frame: *TrapFrame): usize {
    unchecked {
        return (*frame).spsr_el1 as usize;
    }
}

pub fn set_resume_state_in_frame(frame: *TrapFrame, instruction_pointer: usize, stack_pointer: usize, status_flags: usize): void {
    unchecked {
        (*frame).elr_el1 = instruction_pointer as c_ulong;
        (*frame).sp = stack_pointer as c_ulong;
        (*frame).spsr_el1 = status_flags as c_ulong;
    }
}

pub fn set_syscall_result_in_frame(frame: *TrapFrame, error: usize, value0: usize, value1: usize): void {
    unchecked {
        (*frame).x0 = error as c_ulong;
        (*frame).x1 = value0 as c_ulong;
        (*frame).x2 = value1 as c_ulong;
    }
}

pub fn verify_layout(): bool {
    if trap_frame_size != 288 {
        return false;
    }
    if trap_frame_align != 8 {
        return false;
    }
    if trap_frame_x0_offset != 0 {
        return false;
    }
    if trap_frame_x2_offset != 16 {
        return false;
    }
    if trap_frame_x4_offset != 32 {
        return false;
    }
    if trap_frame_x6_offset != 48 {
        return false;
    }
    if trap_frame_x8_offset != 64 {
        return false;
    }
    if trap_frame_x10_offset != 80 {
        return false;
    }
    if trap_frame_x12_offset != 96 {
        return false;
    }
    if trap_frame_x14_offset != 112 {
        return false;
    }
    if trap_frame_x16_offset != 128 {
        return false;
    }
    if trap_frame_x18_offset != 144 {
        return false;
    }
    if trap_frame_x20_offset != 160 {
        return false;
    }
    if trap_frame_x22_offset != 176 {
        return false;
    }
    if trap_frame_x24_offset != 192 {
        return false;
    }
    if trap_frame_x26_offset != 208 {
        return false;
    }
    if trap_frame_x28_offset != 224 {
        return false;
    }
    if trap_frame_x30_offset != 240 {
        return false;
    }
    if trap_frame_sp_offset != 248 {
        return false;
    }
    if trap_frame_elr_el1_offset != 256 {
        return false;
    }
    if trap_frame_spsr_el1_offset != 264 {
        return false;
    }
    if trap_frame_esr_el1_offset != 272 {
        return false;
    }
    if trap_frame_far_el1_offset != 280 {
        return false;
    }
    return true;
}
