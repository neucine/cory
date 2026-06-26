.section .text._start, "ax"
.global _start
.type _start, @function

_start:
    la sp, __stack_top
    call cycor_kernel_entry

1:
    wfi
    j 1b
