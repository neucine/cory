.section .text._start, "ax"
.global _start
.type _start, @function

_start:
    la sp, __m_stack_top

    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x0f
    csrw pmpcfg0, t0

    li t0, 0xffff
    csrw medeleg, t0
    li t0, 0x222
    csrw mideleg, t0

    la t0, cycor_riscv64_s_entry
    csrw mepc, t0

    csrr t0, mstatus
    li t1, ~(3 << 11)
    and t0, t0, t1
    li t1, (1 << 11)
    or t0, t0, t1
    csrw mstatus, t0
    mret

.global cycor_riscv64_s_entry
.type cycor_riscv64_s_entry, @function
cycor_riscv64_s_entry:
    la sp, __stack_top
    call cycor_kernel_entry

1:
    wfi
    j 1b
