.section .text.exception, "ax"
.balign 2048
.global cycor_arch_exception_vectors
.type cycor_arch_exception_vectors, %function

.macro vector_slot
    b cycor_arch_exception_vector_entry
    .balign 128
.endm

cycor_arch_exception_vectors:
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

.type cycor_arch_exception_vector_entry, %function
cycor_arch_exception_vector_entry:
    sub sp, sp, #288
    stp x0, x1, [sp, #0]
    stp x2, x3, [sp, #16]
    stp x4, x5, [sp, #32]
    stp x6, x7, [sp, #48]
    stp x8, x9, [sp, #64]
    stp x10, x11, [sp, #80]
    stp x12, x13, [sp, #96]
    stp x14, x15, [sp, #112]
    stp x16, x17, [sp, #128]
    stp x18, x19, [sp, #144]
    stp x20, x21, [sp, #160]
    stp x22, x23, [sp, #176]
    stp x24, x25, [sp, #192]
    stp x26, x27, [sp, #208]
    stp x28, x29, [sp, #224]
    str x30, [sp, #240]
    add x0, sp, #288
    str x0, [sp, #248]
    mrs x0, elr_el1
    str x0, [sp, #256]
    mrs x0, spsr_el1
    str x0, [sp, #264]
    mrs x0, esr_el1
    str x0, [sp, #272]
    mrs x0, far_el1
    str x0, [sp, #280]
    mov x0, sp
    bl cycor_arch_exception_entry
1:
    wfe
    b 1b

.global cycor_arch_exception_init
.type cycor_arch_exception_init, %function
cycor_arch_exception_init:
    adrp x0, cycor_arch_exception_vectors
    add x0, x0, :lo12:cycor_arch_exception_vectors
    msr vbar_el1, x0
    isb
    ret

.global cycor_arch_abi_probe_value
.type cycor_arch_abi_probe_value, %function
cycor_arch_abi_probe_value:
    // C ABI: c_ulong cycor_arch_abi_probe_value(void)
    // Returns a fixed scalar in x0 so Cyna can verify extern c return lowering.
    movz x0, #0xffee
    movk x0, #0xc0, lsl #16
    ret

.global cycor_arch_current_el
.type cycor_arch_current_el, %function
cycor_arch_current_el:
    // C ABI: c_ulong cycor_arch_current_el(void)
    mrs x0, CurrentEL
    lsr x0, x0, #2
    ret

.global cycor_arch_trigger_test_trap
.type cycor_arch_trigger_test_trap, %function
cycor_arch_trigger_test_trap:
    // C ABI: void cycor_arch_trigger_test_trap(void)
    // Opt-in trap-test entry point. Normal boot manifests do not call it.
    brk #0
    ret
