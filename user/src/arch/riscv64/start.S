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

.global cory_user_yield
.type cory_user_yield, @function
cory_user_yield:
    li a0, 1
    la a1, 7f
    .word 0x00000073
7:
    mv a0, a1
    ret

.global cory_user_debug_write
.type cory_user_debug_write, @function
cory_user_debug_write:
    mv a3, a1
    mv a2, a0
    li a0, 3
    la a1, 2f
    .word 0x00000073
2:
    mv a0, a1
    ret

.global cory_user_console_read
.type cory_user_console_read, @function
cory_user_console_read:
    mv a3, a1
    mv a2, a0
    li a0, 9
    la a1, 4f
    .word 0x00000073
4:
    mv a0, a1
    ret

.global cory_user_console_write
.type cory_user_console_write, @function
cory_user_console_write:
    mv a3, a1
    mv a2, a0
    li a0, 10
    la a1, 5f
    .word 0x00000073
5:
    mv a0, a1
    ret

.global cory_user_process_list
.type cory_user_process_list, @function
cory_user_process_list:
    li a0, 11
    la a1, 6f
    .word 0x00000073
6:
    mv a0, a1
    ret

.global cory_user_process_current
.type cory_user_process_current, @function
cory_user_process_current:
    li a0, 6
    la a1, 8f
    .word 0x00000073
8:
    mv a0, a1
    ret

.global cory_user_program_inspect
.type cory_user_program_inspect, @function
cory_user_program_inspect:
    mv a2, a0
    li a0, 8
    la a1, 9f
    .word 0x00000073
9:
    mv a0, a1
    ret

.global cory_user_process_spawn
.type cory_user_process_spawn, @function
cory_user_process_spawn:
    mv a4, a2
    mv a3, a1
    mv a2, a0
    li a0, 7
    la a1, 10f
    .word 0x00000073
10:
    mv a0, a1
    ret

.global cory_user_process_arg_read
.type cory_user_process_arg_read, @function
cory_user_process_arg_read:
    mv a3, a1
    mv a2, a0
    li a0, 12
    la a1, 12f
    .word 0x00000073
12:
    mv a0, a1
    ret

.global cory_user_process_wait
.type cory_user_process_wait, @function
cory_user_process_wait:
    mv a3, a1
    mv a2, a0
    li a0, 5
    la a1, 11f
    .word 0x00000073
11:
    mv a0, a1
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
