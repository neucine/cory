.section .text.normal_thread, "ax"
.balign 4

.weak cory_normal_thread_a
.type cory_normal_thread_a, @function
cory_normal_thread_a:
    wfi
    j cory_normal_thread_a

.weak cory_normal_thread_b
.type cory_normal_thread_b, @function
cory_normal_thread_b:
    wfi
    j cory_normal_thread_b

.global cory_normal_thread_a_entry_addr
.type cory_normal_thread_a_entry_addr, @function
cory_normal_thread_a_entry_addr:
    # C ABI: c_ulong cory_normal_thread_a_entry_addr(void)
    la a0, cory_normal_thread_a
    ret

.global cory_normal_thread_a_stack_top
.type cory_normal_thread_a_stack_top, @function
cory_normal_thread_a_stack_top:
    # C ABI: c_ulong cory_normal_thread_a_stack_top(void)
    la a0, __normal_thread_a_stack_top
    ret

.global cory_normal_thread_b_entry_addr
.type cory_normal_thread_b_entry_addr, @function
cory_normal_thread_b_entry_addr:
    # C ABI: c_ulong cory_normal_thread_b_entry_addr(void)
    la a0, cory_normal_thread_b
    ret

.global cory_normal_thread_b_stack_top
.type cory_normal_thread_b_stack_top, @function
cory_normal_thread_b_stack_top:
    # C ABI: c_ulong cory_normal_thread_b_stack_top(void)
    la a0, __normal_thread_b_stack_top
    ret

.global cory_normal_user_image_addr
.type cory_normal_user_image_addr, @function
cory_normal_user_image_addr:
    # C ABI: c_ulong cory_normal_user_image_addr(void)
    la a0, cory_normal_user_image_header
    ret

.global cory_normal_child_user_image_addr
.type cory_normal_child_user_image_addr, @function
cory_normal_child_user_image_addr:
    # C ABI: c_ulong cory_normal_child_user_image_addr(void)
    la a0, cory_normal_child_user_image_header
    ret

.global cory_normal_shell_user_image_addr
.type cory_normal_shell_user_image_addr, @function
cory_normal_shell_user_image_addr:
    # C ABI: c_ulong cory_normal_shell_user_image_addr(void)
    la a0, cory_normal_shell_user_image_header
    ret

.section .bss.normal_thread_stack, "aw", @nobits
.balign 16
__normal_thread_a_stack_bottom:
    .skip 0x2000
__normal_thread_a_stack_top:
.balign 16
__normal_thread_b_stack_bottom:
    .skip 0x2000
__normal_thread_b_stack_top:
