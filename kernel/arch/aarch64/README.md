# AArch64

CPU architecture support for 64-bit Arm targets.

Initial responsibilities:

- reset and early entry conventions
- exception vector setup
- EL transition policy
- MMU and page table primitives
- context switch primitives
- generic timer access

Raspberry Pi CM5 specific code belongs in `kernel/platform/raspberrypi_cm5`.

