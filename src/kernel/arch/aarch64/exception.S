.section .text.exception, "ax"
.balign 2048
.global cory_arch_exception_vectors
.type cory_arch_exception_vectors, %function

.macro vector_slot
    b cory_arch_exception_vector_entry
    .balign 128
.endm

cory_arch_exception_vectors:
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot
    vector_slot

.type cory_arch_exception_vector_entry, %function
cory_arch_exception_vector_entry:
    // TF_* constants are generated from arch/aarch64/trap_frame.cy via
    // `export asm const`, so the Cyna cstruct owns the frame layout.
    sub sp, sp, #TF_SIZE
    stp x0, x1, [sp, #TF_X0]
    stp x2, x3, [sp, #TF_X2]
    stp x4, x5, [sp, #TF_X4]
    stp x6, x7, [sp, #TF_X6]
    stp x8, x9, [sp, #TF_X8]
    stp x10, x11, [sp, #TF_X10]
    stp x12, x13, [sp, #TF_X12]
    stp x14, x15, [sp, #TF_X14]
    stp x16, x17, [sp, #TF_X16]
    stp x18, x19, [sp, #TF_X18]
    stp x20, x21, [sp, #TF_X20]
    stp x22, x23, [sp, #TF_X22]
    stp x24, x25, [sp, #TF_X24]
    stp x26, x27, [sp, #TF_X26]
    stp x28, x29, [sp, #TF_X28]
    str x30, [sp, #TF_X30]
    add x0, sp, #TF_SIZE
    str x0, [sp, #TF_SP]
    mrs x0, elr_el1
    str x0, [sp, #TF_ELR_EL1]
    mrs x0, spsr_el1
    str x0, [sp, #TF_SPSR_EL1]
    mrs x0, esr_el1
    str x0, [sp, #TF_ESR_EL1]
    mrs x0, far_el1
    str x0, [sp, #TF_FAR_EL1]
    mov x0, sp
    bl cory_arch_exception_entry
1:
    wfe
    b 1b

.global cory_arch_exception_init
.type cory_arch_exception_init, %function
cory_arch_exception_init:
    adrp x0, cory_arch_exception_vectors
    add x0, x0, :lo12:cory_arch_exception_vectors
    msr vbar_el1, x0
    isb
    ret

.global cory_arch_abi_probe_value
.type cory_arch_abi_probe_value, %function
cory_arch_abi_probe_value:
    // C ABI: c_ulong cory_arch_abi_probe_value(void)
    // Returns a fixed scalar in x0 so Cyna can verify extern c return lowering.
    movz x0, #0xffee
    movk x0, #0xc0, lsl #16
    ret

.global cory_arch_current_el
.type cory_arch_current_el, %function
cory_arch_current_el:
    // C ABI: c_ulong cory_arch_current_el(void)
    mrs x0, CurrentEL
    lsr x0, x0, #2
    ret

.global cory_arch_trigger_test_trap
.type cory_arch_trigger_test_trap, %function
cory_arch_trigger_test_trap:
    // C ABI: void cory_arch_trigger_test_trap(void)
    // Opt-in trap-test entry point. Normal boot manifests do not call it.
    brk #0
    ret
