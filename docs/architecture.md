# Architecture Notes

Cycor is a kernel substrate. The kernel owns machine mechanisms, while userspace
services own policy.

Core boundaries:

- `kernel/arch`: CPU architecture code only.
- `kernel/platform`: board, SoC, and virtual machine integration.
- `kernel/core`: architecture-independent privileged mechanisms.
- `userspace`: init, service management, drivers, and product services.
- `abi`: kernel/userspace contracts and service protocols.

Do not place Raspberry Pi specific code under `kernel/arch/aarch64`, and do not
place SiFive specific code under `kernel/arch/riscv64`.

