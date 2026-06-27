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
    b.eq cycor_aarch64_el1_entry
    cmp x0, #2
    b.eq cycor_aarch64_enter_el1_from_el2

1:
    wfe
    b 1b

.type cycor_aarch64_enter_el1_from_el2, %function
cycor_aarch64_enter_el1_from_el2:
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

    ldr x0, =cycor_aarch64_el1_entry
    msr elr_el2, x0

    mov x0, #0x3c5
    msr spsr_el2, x0
    isb
    eret

.global cycor_aarch64_el1_entry
.type cycor_aarch64_el1_entry, %function
cycor_aarch64_el1_entry:
    ldr x0, =__stack_top
    mov sp, x0
    bl cycor_kernel_entry

1:
    wfe
    b 1b
