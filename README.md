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

The full project specification is in [`docs/SPEC.md`](docs/SPEC.md).

For the early phase of the project, `docs/SPEC.md` is the single source of truth. Sections can be split into separate docs later when the design becomes too large to edit comfortably.

## GitHub language stats

GitHub Linguist does not have first-class Cyna support yet, and `.cy` is
currently claimed by Cycript in Linguist's language database. This repository
uses `.gitattributes` to mark `.cy` files as Cyna while excluding them from
GitHub language percentages until Cyna is supported upstream.

## Repository layout

```text
src/kernel/           Platform-neutral kernel source
src/kernel/arch/      CPU architecture entry and exception/trap assembly
src/kernel/platform/  Kernel-owned platform startup, memory maps, console, and linker scripts
src/user/             Userspace source, intentionally empty until needed
```

`docs/SPEC.md` remains the place for planned structure. Source directories should
exist when there is real code for that boundary.

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

## Build

```text
~/.cyna/0.1.8/bin/cyna version
~/.cyna/0.1.8/bin/cyna check src/kernel/platform/qemu_aarch64_virt/main.cy
~/.cyna/0.1.8/bin/cyna build .
~/.cyna/0.1.8/bin/cyna check src/kernel/platform/qemu_riscv64_virt/main.cy
~/.cyna/0.1.8/bin/cyna build cyna.riscv64.toml
```

Expected outputs:

```text
build/cycor
build/cycor.elf
build/cycor.bin
build/cycor-riscv64
build/cycor-riscv64.elf
build/cycor-riscv64.bin
```

The current kernel entries write to the QEMU `virt` UART, initialize exception
or trap vectors, run the boot allocator self-test, and then halt. When QEMU is
available, run:

```text
qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cycor.elf
qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cycor-riscv64.elf
```
