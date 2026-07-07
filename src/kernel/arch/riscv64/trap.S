.section .text.trap, "ax"
.balign 4
.global cory_arch_trap_vector
.type cory_arch_trap_vector, @function

cory_arch_trap_vector:
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
    call cory_arch_trap_entry
1:
    wfi
    j 1b

.global cory_arch_trap_restore_from_frame
.type cory_arch_trap_restore_from_frame, @function
cory_arch_trap_restore_from_frame:
    # C ABI: noreturn void cory_arch_trap_restore_from_frame(TrapFrame *frame)
    # Restores the saved supervisor trap return state and resumes with sret.
    # This is intentionally not wired into the panic-only vector path yet.
    mv t0, a0
    ld t1, TF_SEPC(t0)
    csrw sepc, t1
    ld t1, TF_SSTATUS(t0)
    csrw sstatus, t1
    ld t1, TF_SP(t0)
    mv sp, t1
    ld ra, TF_RA(t0)
    ld gp, TF_GP(t0)
    ld tp, TF_TP(t0)
    ld t1, TF_T1(t0)
    ld t2, TF_T2(t0)
    ld s0, TF_S0(t0)
    ld s1, TF_S1(t0)
    ld a0, TF_A0(t0)
    ld a1, TF_A1(t0)
    ld a2, TF_A2(t0)
    ld a3, TF_A3(t0)
    ld a4, TF_A4(t0)
    ld a5, TF_A5(t0)
    ld a6, TF_A6(t0)
    ld a7, TF_A7(t0)
    ld s2, TF_S2(t0)
    ld s3, TF_S3(t0)
    ld s4, TF_S4(t0)
    ld s5, TF_S5(t0)
    ld s6, TF_S6(t0)
    ld s7, TF_S7(t0)
    ld s8, TF_S8(t0)
    ld s9, TF_S9(t0)
    ld s10, TF_S10(t0)
    ld s11, TF_S11(t0)
    ld t3, TF_T3(t0)
    ld t4, TF_T4(t0)
    ld t5, TF_T5(t0)
    ld t6, TF_T6(t0)
    ld t0, TF_T0(t0)
    sret

.global cory_arch_trap_init
.type cory_arch_trap_init, @function
cory_arch_trap_init:
    la t0, cory_arch_trap_vector
    csrw stvec, t0
    ret

.global cory_arch_abi_probe_value
.type cory_arch_abi_probe_value, @function
cory_arch_abi_probe_value:
    # C ABI: c_ulong cory_arch_abi_probe_value(void)
    # Returns a fixed scalar in a0 so Cyna can verify extern c return lowering.
    li a0, 12648430
    ret

.global cory_arch_trigger_test_trap
.type cory_arch_trigger_test_trap, @function
cory_arch_trigger_test_trap:
    # C ABI: void cory_arch_trigger_test_trap(void)
    # Opt-in trap-test entry point. Normal boot entries do not call it.
    ebreak
    ret

.global cory_arch_yield_trap
.type cory_arch_yield_trap, @function
cory_arch_yield_trap:
    # C ABI: void cory_arch_yield_trap(void)
    li a0, 1
    ebreak
    ret

.global cory_arch_block_trap
.type cory_arch_block_trap, @function
cory_arch_block_trap:
    # C ABI: void cory_arch_block_trap(void)
    li a0, 2
    ebreak
    ret
