# Targets

First-class targets:

| Tier | Target | Directory |
|---|---|---|
| 0 | AArch64 QEMU `virt` | `kernel/platform/qemu_aarch64_virt` |
| 0 | RISC-V64 QEMU `virt` | `kernel/platform/qemu_riscv64_virt` |
| 1 | Raspberry Pi CM5 | `kernel/platform/raspberrypi_cm5` |
| 1 | SiFive HiFive Unmatched | `kernel/platform/sifive_unmatched` |

Architecture-specific code belongs in `kernel/arch`.
Platform-specific code belongs in `kernel/platform`.

