# Cycor

**Cycor** is pronounced **Sai-core**.

Cycor is a Cyna-native capability kernel substrate designed to demonstrate Cyna's systems-programming capabilities and eventually serve as the operating substrate for Raspberry Pi Compute Module 5 based camera and imaging hardware.

Cycor is not a Linux replacement, Unix clone, desktop OS, or general-purpose server OS. It is a small kernel substrate for controlled hardware, product-specific OS personalities, and imaging-oriented systems.

## Project identity

```text
Neucine  — ecosystem / organization
Cyna     — systems programming language
Cycor    — Cyna-native kernel substrate
```

## Canonical specification

The full project specification is in [`SPEC.md`](SPEC.md).

For the early phase of the project, `SPEC.md` is the single source of truth. Sections can be split into separate docs later when the design becomes too large to edit comfortably.

## Repository layout

```text
abi/          Kernel/userspace ABI notes and service protocols
docs/         Implementation-facing notes derived from the spec
kernel/       Privileged substrate, split by core, architecture, and platform
tools/        Host-side development tools and QEMU helpers
userspace/   Init, service management, drivers, and product services
```

The architecture/platform split is intentional:

```text
kernel/arch/aarch64/                  CPU architecture support
kernel/arch/riscv64/                  CPU architecture support
kernel/platform/qemu_aarch64_virt/    AArch64 QEMU virt platform
kernel/platform/raspberrypi_cm5/      Raspberry Pi CM5 platform
kernel/platform/qemu_riscv64_virt/    RISC-V64 QEMU virt platform
kernel/platform/sifive_unmatched/     SiFive HiFive Unmatched platform
```

Board-specific code should stay out of `kernel/arch`.

## Initial target platforms

Cycor has two hardware tracks:

```text
Product track:  AArch64 / Raspberry Pi Compute Module 5
Research track: RISC-V64 / SiFive HiFive Unmatched
```

Initial development starts in QEMU:

```text
qemu-system-aarch64 -machine virt
qemu-system-riscv64 -machine virt
```

x86_64 support is optional and may be added later, but it is not the first target.

## MVP

The first meaningful Cycor demo is not a shell.

It is a fake camera pipeline:

```text
FakeSensor -> FakeISP -> Preview -> StorageWriter
```

The pipeline should run across isolated userspace services, communicate through capability-based IPC, move frame-like data using `SharedBuffer` objects, and report end-to-end latency through the trace system.

## Build and scaffold commands

```text
make check
make tree
make cyna-version
make toolchain-doctor
make check-cyna
make emit-aarch64-obj
make build-aarch64
```

The default Cyna compiler is:

```text
~/.cyna/0.1.8/bin/cyna
```

Override it with:

```text
make build-aarch64 CYNA=/path/to/cyna
```

QEMU run targets are placeholders until early serial logging is implemented:

```text
make qemu-aarch64
make qemu-riscv64
```
