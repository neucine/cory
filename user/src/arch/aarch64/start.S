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

.global cory_user_yield
.type cory_user_yield, %function
cory_user_yield:
    adr x1, 7f
    brk #1
7:
    mov x0, x1
    ret

.global cory_user_debug_write
.type cory_user_debug_write, %function
cory_user_debug_write:
    mov x2, x1
    adr x1, 2f
    brk #3
2:
    mov x0, x1
    ret

.global cory_user_console_read
.type cory_user_console_read, %function
cory_user_console_read:
    mov x2, x1
    adr x1, 4f
    brk #9
4:
    mov x0, x1
    ret

.global cory_user_console_write
.type cory_user_console_write, %function
cory_user_console_write:
    mov x2, x1
    adr x1, 5f
    brk #10
5:
    mov x0, x1
    ret

.global cory_user_process_list
.type cory_user_process_list, %function
cory_user_process_list:
    adr x1, 6f
    brk #11
6:
    mov x0, x1
    ret

.global cory_user_process_current
.type cory_user_process_current, %function
cory_user_process_current:
    adr x1, 8f
    brk #6
8:
    mov x0, x1
    ret

.global cory_user_program_inspect
.type cory_user_program_inspect, %function
cory_user_program_inspect:
    adr x1, 9f
    brk #8
9:
    mov x0, x1
    ret

.global cory_user_process_spawn
.type cory_user_process_spawn, %function
cory_user_process_spawn:
    mov x3, x2
    mov x2, x1
    adr x1, 10f
    brk #7
10:
    mov x0, x1
    ret

.global cory_user_process_spawn_path
.type cory_user_process_spawn_path, %function
cory_user_process_spawn_path:
    mov x4, x3
    mov x3, x2
    mov x2, x1
    adr x1, 20f
    brk #20
20:
    mov x0, x1
    ret

.global cory_user_program_find
.type cory_user_program_find, %function
cory_user_program_find:
    mov x2, x1
    adr x1, 13f
    brk #13
13:
    mov x0, x1
    ret

.global cory_user_program_find_path
.type cory_user_program_find_path, %function
cory_user_program_find_path:
    mov x2, x1
    adr x1, 19f
    brk #19
19:
    mov x0, x1
    ret

.global cory_user_process_arg_read
.type cory_user_process_arg_read, %function
cory_user_process_arg_read:
    mov x2, x1
    adr x1, 12f
    brk #12
12:
    mov x0, x1
    ret

.global cory_user_fs_list
.type cory_user_fs_list, %function
cory_user_fs_list:
    mov x3, x2
    mov x2, x1
    adr x1, 14f
    brk #14
14:
    mov x0, x1
    ret

.global cory_user_fs_read
.type cory_user_fs_read, %function
cory_user_fs_read:
    mov x3, x2
    mov x2, x1
    adr x1, 15f
    brk #15
15:
    mov x0, x1
    ret

.global cory_user_fs_open
.type cory_user_fs_open, %function
cory_user_fs_open:
    mov x2, x1
    adr x1, 16f
    brk #16
16:
    mov x0, x1
    ret

.global cory_user_fs_fd_read
.type cory_user_fs_fd_read, %function
cory_user_fs_fd_read:
    mov x3, x2
    mov x2, x1
    adr x1, 17f
    brk #17
17:
    mov x0, x1
    ret

.global cory_user_fs_close
.type cory_user_fs_close, %function
cory_user_fs_close:
    adr x1, 18f
    brk #18
18:
    mov x0, x1
    ret

.global cory_user_process_wait
.type cory_user_process_wait, %function
cory_user_process_wait:
    mov x2, x1
    adr x1, 11f
    brk #5
11:
    mov x0, x1
    ret

.global cory_user_exit
.type cory_user_exit, %function
cory_user_exit:
    adr x1, 3f
    brk #4
3:
    b 3b
