.section .text.trap, "ax"
.balign 4
.global cycor_arch_trap_vector
.type cycor_arch_trap_vector, @function

cycor_arch_trap_vector:
    addi sp, sp, -288
    sd ra, 0(sp)
    sd gp, 16(sp)
    sd tp, 24(sp)
    sd t0, 32(sp)
    sd t1, 40(sp)
    sd t2, 48(sp)
    addi t0, sp, 288
    sd t0, 8(sp)
    sd s0, 56(sp)
    sd s1, 64(sp)
    sd a0, 72(sp)
    sd a1, 80(sp)
    sd a2, 88(sp)
    sd a3, 96(sp)
    sd a4, 104(sp)
    sd a5, 112(sp)
    sd a6, 120(sp)
    sd a7, 128(sp)
    sd s2, 136(sp)
    sd s3, 144(sp)
    sd s4, 152(sp)
    sd s5, 160(sp)
    sd s6, 168(sp)
    sd s7, 176(sp)
    sd s8, 184(sp)
    sd s9, 192(sp)
    sd s10, 200(sp)
    sd s11, 208(sp)
    sd t3, 216(sp)
    sd t4, 224(sp)
    sd t5, 232(sp)
    sd t6, 240(sp)
    csrr t0, sepc
    sd t0, 248(sp)
    csrr t0, sstatus
    sd t0, 256(sp)
    csrr t0, scause
    sd t0, 264(sp)
    csrr t0, stval
    sd t0, 272(sp)
    mv a0, sp
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
