.section .text.normal_user, "ax"
.balign 4096

.macro CORY_USER_SYSCALL number, resume
    li a0, \number
    la a1, \resume
    .word 0x00000073
.endm

.macro CORY_USER_BUFFER out, label, header, scratch
    la \out, \label
    la \scratch, \header
    sub \out, \out, \scratch
    li \scratch, 0x1000
    add \out, \out, \scratch
.endm

.global cory_normal_user_image_header
.type cory_normal_user_image_header, @object
cory_normal_user_image_header:
    .quad CORY_USER_IMAGE_MAGIC
    .quad CORY_USER_IMAGE_VERSION
    .quad CORY_USER_IMAGE_HEADER_SIZE
    .quad CORY_USER_IMAGE_HEADER_SIZE
    .quad 4096
    .quad 1

.global cory_normal_user_entry
.type cory_normal_user_entry, @function
cory_normal_user_entry:
    CORY_USER_SYSCALL CORY_SYSCALL_YIELD, 1f
1:
    CORY_USER_BUFFER a2, .Lnormal_user_debug_message, cory_normal_user_image_header, a4
    li a3, 31
    CORY_USER_SYSCALL CORY_SYSCALL_DEBUG_WRITE, 2f
2:
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_CURRENT, 3f
3:
    CORY_USER_BUFFER a2, .Lnormal_user_current_message, cory_normal_user_image_header, a4
    li a3, 30
    CORY_USER_SYSCALL CORY_SYSCALL_DEBUG_WRITE, 4f
4:
    li a2, 1
    CORY_USER_SYSCALL CORY_SYSCALL_PROGRAM_INSPECT, 5f
5:
    mv s2, a1
    li a2, 1
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_SPAWN, 6f
6:
    mv a2, s2
    li a3, 1
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_WAIT, 7f
7:
    CORY_USER_BUFFER a2, .Lnormal_user_wait_message, cory_normal_user_image_header, a4
    li a3, 33
    CORY_USER_SYSCALL CORY_SYSCALL_DEBUG_WRITE, 8f
8:
    li a2, 2
    CORY_USER_SYSCALL CORY_SYSCALL_PROGRAM_INSPECT, 9f
9:
    mv s2, a1
    li a2, 2
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_SPAWN, 10f
10:
    mv a2, s2
    li a3, 1
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_WAIT, 11f
11:
    CORY_USER_BUFFER a2, .Lnormal_user_shell_wait_message, cory_normal_user_image_header, a4
    li a3, 33
    CORY_USER_SYSCALL CORY_SYSCALL_DEBUG_WRITE, 12f
12:
    li a2, 0
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_EXIT, 13f
13:
    j 13b

.Lnormal_user_debug_message:
    .ascii "userspace: debug write riscv64\n"

.Lnormal_user_current_message:
    .ascii "userspace: current ok riscv64\n"

.Lnormal_user_wait_message:
    .ascii "userspace: child wait ok riscv64\n"

.Lnormal_user_shell_wait_message:
    .ascii "userspace: shell wait ok riscv64\n"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_shell_user_image_header
.type cory_normal_shell_user_image_header, @object
cory_normal_shell_user_image_header:
    .quad CORY_USER_IMAGE_MAGIC
    .quad CORY_USER_IMAGE_VERSION
    .quad CORY_USER_IMAGE_HEADER_SIZE
    .quad CORY_USER_IMAGE_HEADER_SIZE
    .quad 4096
    .quad 1

.global cory_normal_shell_entry
.type cory_normal_shell_entry, @function
cory_normal_shell_entry:
    addi sp, sp, -64
.Lnormal_shell_prompt:
    CORY_USER_BUFFER a2, .Lnormal_shell_prompt_message, cory_normal_shell_user_image_header, a4
    li a3, 6
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, 9f
9:
    mv s3, sp
    mv a2, s3
    li a3, 32
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_READ, .Lnormal_shell_read_return
.Lnormal_shell_read_return:
    li s4, 0
.Lnormal_shell_trim_loop:
    add t0, s3, s4
    lbu t1, 0(t0)
    li t2, 10
    beq t1, t2, .Lnormal_shell_dispatch
    addi s4, s4, 1
    blt s4, a1, .Lnormal_shell_trim_loop
.Lnormal_shell_dispatch:
    mv s5, s4
    mv a2, s3
    mv a3, s5
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_echo_newline
.Lnormal_shell_echo_newline:
    CORY_USER_BUFFER a2, .Lnormal_shell_newline_message, cory_normal_shell_user_image_header, a4
    li a3, 1
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_after_echo
.Lnormal_shell_after_echo:
    mv s4, s5
    li t2, 4
    bne s4, t2, .Lnormal_shell_check_echo
    lbu t1, 0(s3)
    li t2, 104
    bne t1, t2, .Lnormal_shell_check_exit
    lbu t1, 1(s3)
    li t2, 101
    bne t1, t2, .Lnormal_shell_check_exit
    lbu t1, 2(s3)
    li t2, 108
    bne t1, t2, .Lnormal_shell_check_exit
    lbu t1, 3(s3)
    li t2, 112
    bne t1, t2, .Lnormal_shell_check_exit
    CORY_USER_BUFFER a2, .Lnormal_shell_help_message, cory_normal_shell_user_image_header, a4
    li a3, 34
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_after_help
.Lnormal_shell_after_help:
    j .Lnormal_shell_prompt
.Lnormal_shell_check_exit:
    lbu t1, 0(s3)
    li t2, 101
    bne t1, t2, .Lnormal_shell_unknown
    lbu t1, 1(s3)
    li t2, 120
    bne t1, t2, .Lnormal_shell_unknown
    lbu t1, 2(s3)
    li t2, 105
    bne t1, t2, .Lnormal_shell_unknown
    lbu t1, 3(s3)
    li t2, 116
    bne t1, t2, .Lnormal_shell_unknown
    CORY_USER_BUFFER a2, .Lnormal_shell_exit_message, cory_normal_shell_user_image_header, a4
    li a3, 12
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_exit
.Lnormal_shell_check_echo:
    li t2, 5
    blt s4, t2, .Lnormal_shell_unknown
    lbu t1, 0(s3)
    li t2, 101
    bne t1, t2, .Lnormal_shell_unknown
    lbu t1, 1(s3)
    li t2, 99
    bne t1, t2, .Lnormal_shell_unknown
    lbu t1, 2(s3)
    li t2, 104
    bne t1, t2, .Lnormal_shell_unknown
    lbu t1, 3(s3)
    li t2, 111
    bne t1, t2, .Lnormal_shell_unknown
    lbu t1, 4(s3)
    li t2, 32
    bne t1, t2, .Lnormal_shell_unknown
    addi a2, s3, 5
    addi a3, s4, -5
    beqz a3, .Lnormal_shell_echo_command_newline
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_echo_command_newline
.Lnormal_shell_echo_command_newline:
    CORY_USER_BUFFER a2, .Lnormal_shell_newline_message, cory_normal_shell_user_image_header, a4
    li a3, 1
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_after_help
.Lnormal_shell_unknown:
    CORY_USER_BUFFER a2, .Lnormal_shell_unknown_message, cory_normal_shell_user_image_header, a4
    li a3, 23
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_after_unknown
.Lnormal_shell_after_unknown:
    j .Lnormal_shell_prompt
.Lnormal_shell_exit:
    li a2, 0
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_EXIT, 15f
15:
    j 15b

.Lnormal_shell_prompt_message:
    .ascii "cory> "

.Lnormal_shell_newline_message:
    .ascii "\n"

.Lnormal_shell_help_message:
    .ascii "shell: commands: help, echo, exit\n"

.Lnormal_shell_exit_message:
    .ascii "shell: exit\n"

.Lnormal_shell_unknown_message:
    .ascii "shell: unknown command\n"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_child_user_image_header
.type cory_normal_child_user_image_header, @object
cory_normal_child_user_image_header:
    .incbin "user/build/cory-user-child-riscv64.bin"
