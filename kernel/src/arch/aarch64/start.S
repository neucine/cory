.section .text._start, "ax"
.global _start
.type _start, %function

_start:
    // QEMU may enter at EL1 or EL2 depending on machine options. Normalize to
    // EL1 before calling Cyna code so exception setup and later VM code have
    // one privilege contract.
    mrs x0, CurrentEL
    lsr x0, x0, #2
    cmp x0, #1
    b.eq cory_aarch64_el1_entry
    cmp x0, #2
    b.eq cory_aarch64_enter_el1_from_el2

1:
    wfe
    b 1b

.type cory_aarch64_enter_el1_from_el2, %function
cory_aarch64_enter_el1_from_el2:
    ldr x0, =__stack_top
    msr sp_el1, x0

    // Run the lower exception level as AArch64, expose the physical counter to
    // EL1, and avoid trapping FP/SIMD access while the kernel is still simple.
    mov x0, #(1 << 31)
    msr hcr_el2, x0

    mov x0, #3
    msr cnthctl_el2, x0
    msr cntvoff_el2, xzr

    msr cptr_el2, xzr

    ldr x0, =cory_aarch64_el1_entry
    msr elr_el2, x0

    mov x0, #0x3c5
    msr spsr_el2, x0
    isb
    eret

.global cory_aarch64_el1_entry
.type cory_aarch64_el1_entry, %function
cory_aarch64_el1_entry:
    // First instruction in the normalized EL1 kernel contract. Whether QEMU
    // entered at EL1 directly or at EL2 and returned with eret, Cyna code starts
    // below this label and should not need to branch on CurrentEL.
    ldr x0, =__stack_top
    mov sp, x0

    // Cyna/LLVM may use FP/SIMD registers for aggregate constants and copies.
    // Enable EL1 access before the first compiled instruction can touch a Q
    // register; EL2 trapping is already disabled above for the EL2 entry path.
    mrs x0, cpacr_el1
    mov x1, #(3 << 20)
    orr x0, x0, x1
    msr cpacr_el1, x0
    isb

    bl cory_kernel_entry

1:
    wfe
    b 1b

.global cory_aarch64_activate_identity_vm
.type cory_aarch64_activate_identity_vm, %function
cory_aarch64_activate_identity_vm:
    // C ABI:
    //   x0 = TTBR0_EL1/TTBR1_EL1 root table address
    //   x1 = MAIR_EL1 value
    //   x2 = TCR_EL1 value
    //   x3 = SCTLR_EL1 bits to set
    dsb sy
    msr mair_el1, x1
    msr tcr_el1, x2
    msr ttbr0_el1, x0
    msr ttbr1_el1, x0
    isb
    tlbi vmalle1
    dsb ish
    isb
    mrs x4, sctlr_el1
    // The current linker exposes one kernel_image range that is temporarily
    // RWX. Clear WXN for this bootstrap phase; section-level W^X mappings will
    // allow enabling it later.
    mov x7, #(1 << 19)
    bic x4, x4, x7
    orr x4, x4, x3
    msr sctlr_el1, x4
    isb
    ret

.global cory_aarch64_switch_ttbr0
.type cory_aarch64_switch_ttbr0, %function
cory_aarch64_switch_ttbr0:
    // C ABI:
    //   x0 = TTBR0_EL1 root table address
    dsb sy
    msr ttbr0_el1, x0
    isb
    tlbi vmalle1
    dsb ish
    isb
    ret

.weak cory_switch_thread_address_space
.type cory_switch_thread_address_space, %function
cory_switch_thread_address_space:
    // Default no-op for probes that do not install process address spaces.
    ret

.global cory_aarch64_flush_kernel_tlb
.type cory_aarch64_flush_kernel_tlb, %function
cory_aarch64_flush_kernel_tlb:
    dsb ishst
    tlbi vmalle1
    dsb ish
    isb
    ret

.global cory_aarch64_counter_frequency
.type cory_aarch64_counter_frequency, %function
cory_aarch64_counter_frequency:
    // C ABI: c_ulong cory_aarch64_counter_frequency(void)
    mrs x0, cntfrq_el0
    ret

.global cory_aarch64_counter_value
.type cory_aarch64_counter_value, %function
cory_aarch64_counter_value:
    // C ABI: c_ulong cory_aarch64_counter_value(void)
    isb
    mrs x0, cntvct_el0
    ret

.global cory_aarch64_timer_tval_write
.type cory_aarch64_timer_tval_write, %function
cory_aarch64_timer_tval_write:
    // C ABI: void cory_aarch64_timer_tval_write(c_ulong ticks)
    msr cntv_tval_el0, x0
    isb
    ret

.global cory_aarch64_timer_ctl_read
.type cory_aarch64_timer_ctl_read, %function
cory_aarch64_timer_ctl_read:
    // C ABI: c_ulong cory_aarch64_timer_ctl_read(void)
    mrs x0, cntv_ctl_el0
    ret

.global cory_aarch64_timer_ctl_write
.type cory_aarch64_timer_ctl_write, %function
cory_aarch64_timer_ctl_write:
    // C ABI: void cory_aarch64_timer_ctl_write(c_ulong value)
    msr cntv_ctl_el0, x0
    isb
    ret

.global cory_aarch64_irq_mask
.type cory_aarch64_irq_mask, %function
cory_aarch64_irq_mask:
    // C ABI: void cory_aarch64_irq_mask(void)
    msr daifset, #2
    isb
    ret

.global cory_aarch64_irq_unmask
.type cory_aarch64_irq_unmask, %function
cory_aarch64_irq_unmask:
    // C ABI: void cory_aarch64_irq_unmask(void)
    msr daifclr, #2
    isb
    ret
