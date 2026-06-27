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
    mrs x0, esr_el1
    mrs x1, elr_el1
    mrs x2, far_el1
    mrs x3, spsr_el1
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
