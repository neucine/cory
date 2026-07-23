.section .text.cory_user_image_header, "ax"
.balign 4096
.global cory_user_image_header
.type cory_user_image_header, %object
cory_user_image_header:
    .quad 0x43594e41494d4731
    .quad 1
    .quad 48
    .quad cory_user_start - cory_user_image_header
    .quad 4096
    .quad 1

.section .text.cory_user_start, "ax"
.global cory_user_start
.type cory_user_start, %function
cory_user_start:
    bl cory_user_main
    mov x0, #0
    bl cory_user_exit
1:
    b 1b

.global cory_user_debug_write
.type cory_user_debug_write, %function
cory_user_debug_write:
    mov x2, x1
    adr x1, 2f
    brk #3
2:
    ret

.global cory_user_exit
.type cory_user_exit, %function
cory_user_exit:
    adr x1, 3f
    brk #4
3:
    b 3b
