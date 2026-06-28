.section .text.trap, "ax"
.balign 4
.global cycor_arch_trap_vector
.type cycor_arch_trap_vector, @function

cycor_arch_trap_vector:
    # TF_* constants are generated from arch/riscv64/trap_frame.cy via
    # `export asm const`, so the Cyna cstruct owns the frame layout.
    addi sp, sp, -TF_SIZE
    sd ra, TF_RA(sp)
    sd gp, TF_GP(sp)
    sd tp, TF_TP(sp)
    sd t0, TF_T0(sp)
    sd t1, TF_T1(sp)
    sd t2, TF_T2(sp)
    addi t0, sp, TF_SIZE
    sd t0, TF_SP(sp)
    sd s0, TF_S0(sp)
    sd s1, TF_S1(sp)
    sd a0, TF_A0(sp)
    sd a1, TF_A1(sp)
    sd a2, TF_A2(sp)
    sd a3, TF_A3(sp)
    sd a4, TF_A4(sp)
    sd a5, TF_A5(sp)
    sd a6, TF_A6(sp)
    sd a7, TF_A7(sp)
    sd s2, TF_S2(sp)
    sd s3, TF_S3(sp)
    sd s4, TF_S4(sp)
    sd s5, TF_S5(sp)
    sd s6, TF_S6(sp)
    sd s7, TF_S7(sp)
    sd s8, TF_S8(sp)
    sd s9, TF_S9(sp)
    sd s10, TF_S10(sp)
    sd s11, TF_S11(sp)
    sd t3, TF_T3(sp)
    sd t4, TF_T4(sp)
    sd t5, TF_T5(sp)
    sd t6, TF_T6(sp)
    csrr t0, sepc
    sd t0, TF_SEPC(sp)
    csrr t0, sstatus
    sd t0, TF_SSTATUS(sp)
    csrr t0, scause
    sd t0, TF_SCAUSE(sp)
    csrr t0, stval
    sd t0, TF_STVAL(sp)
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
