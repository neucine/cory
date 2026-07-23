.section .text.usermodeprobe, "ax"
.balign 4096

.global cory_usermode_probe_entry_addr
.type cory_usermode_probe_entry_addr, @function
cory_usermode_probe_entry_addr:
    # C ABI: c_ulong cory_usermode_probe_entry_addr(void)
    la a0, cory_usermode_probe_entry
    ret

.global cory_usermode_probe_entry
.type cory_usermode_probe_entry, @function
cory_usermode_probe_entry:
    ecall
1:
    j 1b
