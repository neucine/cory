.section .text.trap, "ax"
.balign 4
.global cycor_arch_trap_vector
.type cycor_arch_trap_vector, @function

cycor_arch_trap_vector:
    csrr a0, scause
    csrr a1, sepc
    csrr a2, stval
    csrr a3, sstatus
    call cycor_arch_trap_entry
1:
    wfi
    j 1b

.global cycor_arch_trap_init
.type cycor_arch_trap_init, @function
cycor_arch_trap_init:
    la t0, cycor_arch_trap_vector
    csrw stvec, t0
    ret

.global cycor_arch_abi_probe_value
.type cycor_arch_abi_probe_value, @function
cycor_arch_abi_probe_value:
    # C ABI: c_ulong cycor_arch_abi_probe_value(void)
    # Returns a fixed scalar in a0 so Cyna can verify extern c return lowering.
    li a0, 12648430
    ret

.global cycor_arch_trigger_test_trap
.type cycor_arch_trigger_test_trap, @function
cycor_arch_trigger_test_trap:
    # C ABI: void cycor_arch_trigger_test_trap(void)
    # Opt-in trap-test entry point. Normal boot manifests do not call it.
    ebreak
    ret
