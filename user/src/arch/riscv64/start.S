.section .text.cory_user_image_header, "ax"
.balign 4096
.global cory_user_image_header
.type cory_user_image_header, @object
cory_user_image_header:
    .quad 0x43594e41494d4731
    .quad 1
    .quad 48
    .quad cory_user_start - cory_user_image_header
    .quad 4096
    .quad 1

.section .text.cory_user_start, "ax"
.global cory_user_start
.type cory_user_start, @function
cory_user_start:
    call cory_user_main
    li a2, 0
    call cory_user_exit
1:
    j 1b

.global cory_user_debug_write
.type cory_user_debug_write, @function
cory_user_debug_write:
    mv a3, a1
    mv a2, a0
    li a0, 3
    la a1, 2f
    .word 0x00000073
2:
    ret

.global cory_user_exit
.type cory_user_exit, @function
cory_user_exit:
    mv a2, a0
    li a0, 4
    la a1, 3f
    .word 0x00000073
3:
    j 3b
