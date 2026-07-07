.section .text.normal_thread, "ax"
.balign 4

.weak cory_normal_thread
.type cory_normal_thread, @function
cory_normal_thread:
    wfi
    j cory_normal_thread

.global cory_normal_thread_entry_addr
.type cory_normal_thread_entry_addr, @function
cory_normal_thread_entry_addr:
    # C ABI: c_ulong cory_normal_thread_entry_addr(void)
    la a0, cory_normal_thread
    ret

.global cory_normal_thread_stack_top
.type cory_normal_thread_stack_top, @function
cory_normal_thread_stack_top:
    # C ABI: c_ulong cory_normal_thread_stack_top(void)
    la a0, __normal_thread_stack_top
    ret

.section .bss.normal_thread_stack, "aw", @nobits
.balign 16
__normal_thread_stack_bottom:
    .skip 0x2000
__normal_thread_stack_top:
