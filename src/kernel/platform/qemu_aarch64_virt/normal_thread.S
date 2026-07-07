.section .text.normal_thread, "ax"
.balign 4

.weak cory_normal_thread_a
.type cory_normal_thread_a, %function
cory_normal_thread_a:
    wfe
    b cory_normal_thread_a

.weak cory_normal_thread_b
.type cory_normal_thread_b, %function
cory_normal_thread_b:
    wfe
    b cory_normal_thread_b

.global cory_normal_thread_a_entry_addr
.type cory_normal_thread_a_entry_addr, %function
cory_normal_thread_a_entry_addr:
    // C ABI: c_ulong cory_normal_thread_a_entry_addr(void)
    adrp x0, cory_normal_thread_a
    add x0, x0, :lo12:cory_normal_thread_a
    ret

.global cory_normal_thread_a_stack_top
.type cory_normal_thread_a_stack_top, %function
cory_normal_thread_a_stack_top:
    // C ABI: c_ulong cory_normal_thread_a_stack_top(void)
    adrp x0, __normal_thread_a_stack_top
    add x0, x0, :lo12:__normal_thread_a_stack_top
    ret

.global cory_normal_thread_b_entry_addr
.type cory_normal_thread_b_entry_addr, %function
cory_normal_thread_b_entry_addr:
    // C ABI: c_ulong cory_normal_thread_b_entry_addr(void)
    adrp x0, cory_normal_thread_b
    add x0, x0, :lo12:cory_normal_thread_b
    ret

.global cory_normal_thread_b_stack_top
.type cory_normal_thread_b_stack_top, %function
cory_normal_thread_b_stack_top:
    // C ABI: c_ulong cory_normal_thread_b_stack_top(void)
    adrp x0, __normal_thread_b_stack_top
    add x0, x0, :lo12:__normal_thread_b_stack_top
    ret

.section .bss.normal_thread_stack, "aw", %nobits
.balign 16
__normal_thread_a_stack_bottom:
    .skip 0x2000
__normal_thread_a_stack_top:
.balign 16
__normal_thread_b_stack_bottom:
    .skip 0x2000
__normal_thread_b_stack_top:
