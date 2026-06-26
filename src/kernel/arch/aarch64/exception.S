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
