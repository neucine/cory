.section .text._start, "ax"
.global _start
.type _start, @function

_start:
    # QEMU virt with -bios none enters the kernel in M-mode. Cory uses M-mode
    # only as a bootstrap ownership stage: open physical memory through PMP,
    # delegate the traps/interrupts we currently understand, then mret into the
    # supervisor kernel entry. Cyna code runs after cory_riscv64_s_entry and is
    # therefore expected to be S-mode kernel code.
    la sp, __m_stack_top

    # Give S-mode access to the full physical address space. This is an early
    # identity-memory policy for bring-up; virtual memory will replace this with
    # explicit mappings and tighter access once page tables exist.
    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x0f
    csrw pmpcfg0, t0

    la t0, cory_riscv64_m_trap_vector
    csrw mtvec, t0

    # Route common synchronous exceptions and supervisor interrupts to S-mode.
    # The machine timer itself cannot be delegated on this target, so the M-mode
    # trap vector below converts MTIP into a delegated supervisor timer interrupt.
    li t0, 0xffff
    csrw medeleg, t0
    li t0, 0x222
    csrw mideleg, t0
    li t0, (1 << 7)
    csrs mie, t0

    # Allow the S-mode kernel to read the architectural time counter. Timer
    # interrupt delivery is owned by the M-mode shim in this file.
    li t0, (1 << 1)
    csrw mcounteren, t0

    la t0, cory_riscv64_s_entry
    csrw mepc, t0

    csrr t0, mstatus
    li t1, ~(3 << 11)
    and t0, t0, t1
    li t1, (1 << 11)
    or t0, t0, t1
    csrw mstatus, t0
    mret

.global cory_riscv64_s_entry
.type cory_riscv64_s_entry, @function
cory_riscv64_s_entry:
    # First instruction after the M-mode to S-mode transition. Keep the Cyna
    # entry point below this label so common kernel code has one privilege-mode
    # contract per architecture.
    la sp, __stack_top
    call cory_kernel_entry

1:
    wfi
    j 1b

.global cory_riscv64_activate_identity_vm
.type cory_riscv64_activate_identity_vm, @function
cory_riscv64_activate_identity_vm:
    # C ABI:
    #   a0 = satp value
    sfence.vma zero, zero
    csrw satp, a0
    sfence.vma zero, zero
    ret

.global cory_riscv64_switch_satp
.type cory_riscv64_switch_satp, @function
cory_riscv64_switch_satp:
    # C ABI:
    #   a0 = satp value
    sfence.vma zero, zero
    csrw satp, a0
    sfence.vma zero, zero
    ret

.weak cory_switch_thread_address_space
.type cory_switch_thread_address_space, @function
cory_switch_thread_address_space:
    # Default no-op for probes that do not install process address spaces.
    ret

.global cory_riscv64_flush_kernel_tlb
.type cory_riscv64_flush_kernel_tlb, @function
cory_riscv64_flush_kernel_tlb:
    sfence.vma zero, zero
    ret

.global cory_riscv64_irq_mask
.type cory_riscv64_irq_mask, @function
cory_riscv64_irq_mask:
    li t0, (1 << 1)
    csrc sstatus, t0
    ret

.global cory_riscv64_irq_unmask
.type cory_riscv64_irq_unmask, @function
cory_riscv64_irq_unmask:
    li t0, (1 << 1)
    csrs sstatus, t0
    ret

.global cory_riscv64_user_access_begin
.type cory_riscv64_user_access_begin, @function
cory_riscv64_user_access_begin:
    li t0, (1 << 18)
    csrs sstatus, t0
    ret

.global cory_riscv64_user_access_end
.type cory_riscv64_user_access_end, @function
cory_riscv64_user_access_end:
    li t0, (1 << 18)
    csrc sstatus, t0
    ret

.global cory_riscv64_time_value
.type cory_riscv64_time_value, @function
cory_riscv64_time_value:
    # C ABI: c_ulong cory_riscv64_time_value(void)
    rdtime a0
    ret

.global cory_riscv64_supervisor_timer_irq_enable
.type cory_riscv64_supervisor_timer_irq_enable, @function
cory_riscv64_supervisor_timer_irq_enable:
    li t0, (1 << 5)
    csrs sie, t0
    ret

.global cory_riscv64_supervisor_timer_irq_disable
.type cory_riscv64_supervisor_timer_irq_disable, @function
cory_riscv64_supervisor_timer_irq_disable:
    li t0, (1 << 5)
    csrc sie, t0
    ret

.global cory_riscv64_machine_timer_program
.type cory_riscv64_machine_timer_program, @function
cory_riscv64_machine_timer_program:
    # C ABI: void cory_riscv64_machine_timer_program(c_ulong delta)
    rdtime t0
    add t0, t0, a0
    li t1, 0x02004000
    sd t0, 0(t1)
    ret

.global cory_riscv64_machine_timer_clear
.type cory_riscv64_machine_timer_clear, @function
cory_riscv64_machine_timer_clear:
    # C ABI: void cory_riscv64_machine_timer_clear(void)
    li t0, (1 << 5)
    csrc sip, t0
    li t0, 0x02004000
    li t1, -1
    sd t1, 0(t0)
    ret

.type cory_riscv64_m_trap_vector, @function
cory_riscv64_m_trap_vector:
    # QEMU virt -bios none delivers the CLINT timer as machine timer interrupt.
    # Keep M-mode as a narrow shim: disarm MTIMECMP, pend STIP, and return to
    # the interrupted S-mode context so the normal supervisor trap path owns the
    # kernel-visible interrupt.
    addi sp, sp, -24
    sd t0, 0(sp)
    sd t1, 8(sp)
    sd t2, 16(sp)

    csrr t0, mcause
    li t1, 1
    slli t1, t1, 63
    li t2, 7
    or t1, t1, t2
    bne t0, t1, 2f

    li t0, 0x02004000
    li t1, -1
    sd t1, 0(t0)
    li t0, (1 << 5)
    csrs mip, t0

    ld t0, 0(sp)
    ld t1, 8(sp)
    ld t2, 16(sp)
    addi sp, sp, 24
    mret

2:
    wfi
    j 2b
