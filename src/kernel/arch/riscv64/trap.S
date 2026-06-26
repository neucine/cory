.section .text.trap, "ax"
.balign 4
.global cycor_arch_trap_vector
.type cycor_arch_trap_vector, @function

cycor_arch_trap_vector:
    call cycor_arch_trap_entry
1:
    wfi
    j 1b

.global cycor_arch_trap_init
.type cycor_arch_trap_init, @function
cycor_arch_trap_init:
    la t0, cycor_arch_trap_vector
    csrw mtvec, t0
    ret
