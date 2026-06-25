# Cycor Platform Strategy

## 1. Summary

Cycor has two first-class hardware tracks:

```text
Product track:  AArch64 / Raspberry Pi Compute Module 5
Research track: RISC-V64 / SiFive HiFive Unmatched
```

Initial development starts in QEMU for fast iteration.

## 2. Product track: AArch64 / Raspberry Pi CM5

This is the main product path.

Reasons:

- future camera hardware is CM5-based
- AArch64 aligns with the embedded/imaging product direction
- CM5 supports practical camera/display carrier-board experimentation
- CM5 can lead toward custom camera hardware later

Initial CM5 goals:

- serial boot
- early logging
- exception handling
- timer
- interrupt controller
- memory management
- simple device access
- storage/display/input later

Non-initial CM5 goals:

- MIPI CSI control
- ISP control
- full camera stack
- production storage pipeline
- production display pipeline

These should wait until the kernel substrate is stable.

## 3. Research track: RISC-V64 / SiFive HiFive Unmatched

This is the architecture validation path.

Reasons:

- validates clean architecture/platform separation
- validates Cyna freestanding RISC-V64 support
- pressures the syscall ABI to be architecture-neutral
- prevents AArch64-specific assumptions
- gives a real non-ARM board for kernel experiments

Initial RISC-V goals:

- QEMU `virt` boot
- serial logging
- trap handling
- timer
- interrupt controller
- physical/virtual memory
- basic scheduler

Later goals:

- SiFive HiFive Unmatched serial boot
- board-specific interrupt/device support
- storage/network experiments

## 4. Target matrix

| Tier | Target | Purpose |
|---|---|---|
| 0 | AArch64 QEMU `virt` | primary bring-up |
| 0 | RISC-V64 QEMU `virt` | architecture validation |
| 1 | Raspberry Pi CM5 | product board bring-up |
| 1 | SiFive HiFive Unmatched | research board bring-up |
| 2 | CM5 camera carrier | imaging prototype |
| 3 | custom camera hardware | future product direction |

## 5. Recommended implementation order

1. AArch64 QEMU `virt`
2. RISC-V64 QEMU `virt`
3. common kernel core
4. Raspberry Pi CM5 serial boot
5. SiFive Unmatched serial boot
6. fake camera pipeline
7. CM5 storage/display/input
8. CM5 camera-oriented services
9. CM5 camera hardware pipeline
