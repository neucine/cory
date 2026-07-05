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

    # Route common synchronous exceptions and supervisor interrupts to S-mode.
    # Machine-level timer/interrupt-controller ownership is still future work,
    # so these masks should evolve with the interrupt design rather than being
    # treated as a finished platform policy.
    li t0, 0xffff
    csrw medeleg, t0
    li t0, 0x222
    csrw mideleg, t0

    # Allow the S-mode kernel to read the architectural time counter. Timer
    # interrupt programming is still separate future work.
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

.global cory_riscv64_flush_kernel_tlb
.type cory_riscv64_flush_kernel_tlb, @function
cory_riscv64_flush_kernel_tlb:
    sfence.vma zero, zero
    ret

.global cory_riscv64_time_value
.type cory_riscv64_time_value, @function
cory_riscv64_time_value:
    # C ABI: c_ulong cory_riscv64_time_value(void)
    rdtime a0
    ret
