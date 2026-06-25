.section .text._start, "ax"
.global _start
.type _start, %function

_start:
    ldr x0, =__stack_top
    mov sp, x0
    bl cyna_entry

1:
    wfe
    b 1b

