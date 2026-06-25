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
src/kernel/   Kernel source
src/user/     Userspace source, intentionally empty until needed
```

Do not add architecture, platform, ABI, service, or subsystem directories before
there is real code for that boundary. `SPEC.md` remains the place for planned
structure.

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
~/.cyna/0.1.8/bin/cyna check src/kernel/main.cy
~/.cyna/0.1.8/bin/cyna build .
```

Expected outputs:

```text
build/cycor
build/cycor.elf
build/cycor.bin
```

The current kernel entry writes to the AArch64 QEMU `virt` PL011 UART and then
halts. When QEMU is available, run:

```text
qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cycor.elf
```
