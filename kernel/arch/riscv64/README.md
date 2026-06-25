# RISC-V64

CPU architecture support for 64-bit RISC-V targets.

Initial responsibilities:

- trap entry and return
- privilege mode setup
- page table primitives
- context switch primitives
- timer and interrupt controller interfaces
- atomics and memory model validation

SiFive HiFive Unmatched specific code belongs in
`kernel/platform/sifive_unmatched`.

