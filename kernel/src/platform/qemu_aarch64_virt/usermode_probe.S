.section .text.usermodeprobe, "ax"
.balign 4096

.global cory_usermode_probe_entry_addr
.type cory_usermode_probe_entry_addr, %function
cory_usermode_probe_entry_addr:
    // C ABI: c_ulong cory_usermode_probe_entry_addr(void)
    adrp x0, cory_usermode_probe_entry
    add x0, x0, :lo12:cory_usermode_probe_entry
    ret

.global cory_usermode_probe_kernel_stack_top
.type cory_usermode_probe_kernel_stack_top, %function
cory_usermode_probe_kernel_stack_top:
    // C ABI: c_ulong cory_usermode_probe_kernel_stack_top(void)
    mov x0, sp
    ret

.global cory_usermode_probe_entry
.type cory_usermode_probe_entry, %function
cory_usermode_probe_entry:
    brk #0x321
1:
    b 1b
