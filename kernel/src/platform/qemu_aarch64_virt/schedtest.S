.section .text.schedtest, "ax"
.balign 4

.global cory_schedtest_current_sp
.type cory_schedtest_current_sp, %function
cory_schedtest_current_sp:
    // C ABI: c_ulong cory_schedtest_current_sp(void)
    mov x0, sp
    ret

.global cory_schedtest_thread_b_entry_addr
.type cory_schedtest_thread_b_entry_addr, %function
cory_schedtest_thread_b_entry_addr:
    // C ABI: c_ulong cory_schedtest_thread_b_entry_addr(void)
    adrp x0, cory_schedtest_thread_b
    add x0, x0, :lo12:cory_schedtest_thread_b
    ret
