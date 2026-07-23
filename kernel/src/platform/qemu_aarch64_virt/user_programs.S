.section .text.normal_user, "ax"
.balign 4096

.macro CORY_USER_SYSCALL number, resume
    adr x1, \resume
    brk #\number
.endm

.macro CORY_USER_BUFFER out, label, header, scratch
    adr \out, \label
    adr \scratch, \header
    sub \out, \out, \scratch
    mov \scratch, #0x1000
    add \out, \out, \scratch
.endm

.global cory_normal_user_image_header
.type cory_normal_user_image_header, %object
cory_normal_user_image_header:
    .quad CORY_USER_IMAGE_MAGIC
    .quad CORY_USER_IMAGE_VERSION
    .quad CORY_USER_IMAGE_HEADER_SIZE
    .quad CORY_USER_IMAGE_HEADER_SIZE
    .quad 4096
    .quad 1

.global cory_normal_user_entry
.type cory_normal_user_entry, %function
cory_normal_user_entry:
    CORY_USER_SYSCALL CORY_SYSCALL_YIELD, 1f
1:
    CORY_USER_BUFFER x0, .Lnormal_user_debug_message, cory_normal_user_image_header, x3
    mov x2, #31
    CORY_USER_SYSCALL CORY_SYSCALL_DEBUG_WRITE, 2f
2:
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_CURRENT, 3f
3:
    CORY_USER_BUFFER x0, .Lnormal_user_current_message, cory_normal_user_image_header, x3
    mov x2, #30
    CORY_USER_SYSCALL CORY_SYSCALL_DEBUG_WRITE, 4f
4:
    mov x0, #1
    CORY_USER_SYSCALL CORY_SYSCALL_PROGRAM_INSPECT, 5f
5:
    mov x4, x1
    mov x0, #1
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_SPAWN, 6f
6:
    mov x0, x4
    mov x2, #1
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_WAIT, 7f
7:
    CORY_USER_BUFFER x0, .Lnormal_user_wait_message, cory_normal_user_image_header, x3
    mov x2, #33
    CORY_USER_SYSCALL CORY_SYSCALL_DEBUG_WRITE, 8f
8:
    mov x0, #2
    CORY_USER_SYSCALL CORY_SYSCALL_PROGRAM_INSPECT, 9f
9:
    mov x4, x1
    mov x0, #2
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_SPAWN, 10f
10:
    mov x0, x4
    mov x2, #1
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_WAIT, 11f
11:
    CORY_USER_BUFFER x0, .Lnormal_user_shell_wait_message, cory_normal_user_image_header, x3
    mov x2, #33
    CORY_USER_SYSCALL CORY_SYSCALL_DEBUG_WRITE, 12f
12:
    mov x0, #0
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_EXIT, 13f
13:
    b 13b

.Lnormal_user_debug_message:
    .ascii "userspace: debug write aarch64\n"

.Lnormal_user_current_message:
    .ascii "userspace: current ok aarch64\n"

.Lnormal_user_wait_message:
    .ascii "userspace: child wait ok aarch64\n"

.Lnormal_user_shell_wait_message:
    .ascii "userspace: shell wait ok aarch64\n"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_shell_user_image_header
.type cory_normal_shell_user_image_header, %object
cory_normal_shell_user_image_header:
    .quad CORY_USER_IMAGE_MAGIC
    .quad CORY_USER_IMAGE_VERSION
    .quad CORY_USER_IMAGE_HEADER_SIZE
    .quad CORY_USER_IMAGE_HEADER_SIZE
    .quad 4096
    .quad 1

.global cory_normal_shell_entry
.type cory_normal_shell_entry, %function
cory_normal_shell_entry:
    sub sp, sp, #64
.Lnormal_shell_prompt:
    CORY_USER_BUFFER x0, .Lnormal_shell_prompt_message, cory_normal_shell_user_image_header, x3
    mov x2, #6
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, 9f
9:
    mov x5, sp
    mov x0, x5
    mov x2, #32
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_READ, .Lnormal_shell_read_return
.Lnormal_shell_read_return:
    mov x6, #0
.Lnormal_shell_trim_loop:
    ldrb w7, [x5, x6]
    cmp x7, #10
    b.eq .Lnormal_shell_dispatch
    add x6, x6, #1
    cmp x6, x1
    b.lt .Lnormal_shell_trim_loop
.Lnormal_shell_dispatch:
    mov x8, x6
    mov x0, x5
    mov x2, x8
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_echo_newline
.Lnormal_shell_echo_newline:
    CORY_USER_BUFFER x0, .Lnormal_shell_newline_message, cory_normal_shell_user_image_header, x3
    mov x2, #1
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_after_echo
.Lnormal_shell_after_echo:
    mov x6, x8
    cmp x6, #4
    b.ne .Lnormal_shell_check_echo
    ldrb w7, [x5]
    cmp x7, #104
    b.ne .Lnormal_shell_check_exit
    ldrb w7, [x5, #1]
    cmp x7, #101
    b.ne .Lnormal_shell_check_exit
    ldrb w7, [x5, #2]
    cmp x7, #108
    b.ne .Lnormal_shell_check_exit
    ldrb w7, [x5, #3]
    cmp x7, #112
    b.ne .Lnormal_shell_check_exit
    CORY_USER_BUFFER x0, .Lnormal_shell_help_message, cory_normal_shell_user_image_header, x3
    mov x2, #34
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_after_help
.Lnormal_shell_after_help:
    b .Lnormal_shell_prompt
.Lnormal_shell_check_exit:
    ldrb w7, [x5]
    cmp x7, #101
    b.ne .Lnormal_shell_unknown
    ldrb w7, [x5, #1]
    cmp x7, #120
    b.ne .Lnormal_shell_unknown
    ldrb w7, [x5, #2]
    cmp x7, #105
    b.ne .Lnormal_shell_unknown
    ldrb w7, [x5, #3]
    cmp x7, #116
    b.ne .Lnormal_shell_unknown
    CORY_USER_BUFFER x0, .Lnormal_shell_exit_message, cory_normal_shell_user_image_header, x3
    mov x2, #12
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_exit
.Lnormal_shell_check_echo:
    cmp x6, #5
    b.lt .Lnormal_shell_unknown
    ldrb w7, [x5]
    cmp x7, #101
    b.ne .Lnormal_shell_unknown
    ldrb w7, [x5, #1]
    cmp x7, #99
    b.ne .Lnormal_shell_unknown
    ldrb w7, [x5, #2]
    cmp x7, #104
    b.ne .Lnormal_shell_unknown
    ldrb w7, [x5, #3]
    cmp x7, #111
    b.ne .Lnormal_shell_unknown
    ldrb w7, [x5, #4]
    cmp x7, #32
    b.ne .Lnormal_shell_unknown
    add x0, x5, #5
    sub x2, x6, #5
    cbz x2, .Lnormal_shell_echo_command_newline
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_echo_command_newline
.Lnormal_shell_echo_command_newline:
    CORY_USER_BUFFER x0, .Lnormal_shell_newline_message, cory_normal_shell_user_image_header, x3
    mov x2, #1
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_after_help
.Lnormal_shell_unknown:
    CORY_USER_BUFFER x0, .Lnormal_shell_unknown_message, cory_normal_shell_user_image_header, x3
    mov x2, #23
    CORY_USER_SYSCALL CORY_SYSCALL_CONSOLE_WRITE, .Lnormal_shell_after_unknown
.Lnormal_shell_after_unknown:
    b .Lnormal_shell_prompt
.Lnormal_shell_exit:
    mov x0, #0
    CORY_USER_SYSCALL CORY_SYSCALL_PROCESS_EXIT, 15f
15:
    b 15b

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
.type cory_normal_child_user_image_header, %object
cory_normal_child_user_image_header:
    .incbin "user/build/cory-user-child-aarch64.bin"
