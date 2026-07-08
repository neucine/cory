# Cory

**Cory** is a tiny Cyna-native kernel substrate for controlled hardware,
product-specific operating environments, and imaging systems.

It is pronounced **Core-ry**.

Cory is not trying to become a Linux replacement, a Unix clone, a desktop OS, or
a general-purpose server platform. It is a focused kernel foundation for devices
where the OS personality should be small, explicit, capability-oriented, and
close to the hardware.

The long-term product target is Raspberry Pi Compute Module 5 based camera and
imaging hardware. The first meaningful demo is a camera-shaped pipeline rather
than a shell:

```text
FakeSensor -> FakeISP -> Preview -> StorageWriter
```

That pipeline is intended to run across isolated userspace services, communicate
through capability-based IPC, move frame-like data with shared buffers, and
report end-to-end latency through kernel tracing.

## Why Cory Exists

Cory is a place to prove Cyna as a systems programming language under the kind
of pressure kernels create: freestanding code, explicit memory layout, CPU trap
frames, page tables, interrupt delivery, object authority, and careful
cross-architecture boundaries.

The project is deliberately narrow. A smaller kernel surface makes it possible
to keep hardware policy, authority, scheduling, and data movement understandable
as the imaging stack grows.

```text
Neucine  — ecosystem / organization
Cyna     — systems programming language
Cory     — Cyna-native kernel substrate
```

## What Works Today

Cory currently boots on both initial QEMU targets and exercises real kernel
bring-up paths:

- **AArch64** on `qemu-system-aarch64 -machine virt`
- **RISC-V64** on `qemu-system-riscv64 -machine virt`

Current boot images initialize console output, trap vectors, early memory,
bootstrap page tables, physical pages, heap metadata, address spaces, kernel
objects, capabilities, process metadata, thread metadata, scheduler metadata,
and architecture context storage.

The latest normal boot path on both QEMU targets can enable scheduler tick mode,
resume a normal kernel worker, switch away from that worker through a voluntary
yield trap, resume it again, and then switch away through a block trap that marks
the worker blocked.

Still intentionally missing:

- long-running scheduler workloads
- userspace entry
- syscalls
- IPC
- shared buffers
- the camera pipeline demo

That gap is the point of the next phase: grow the kernel upward only after the
authority and scheduling foundations are real enough to carry it.

## Design Shape

Cory is organized around a few firm boundaries:

```text
src/kernel/           Platform-neutral kernel source
src/kernel/arch/      CPU architecture entry, traps, contexts, and page tables
src/kernel/memory/    Physical memory, heap, VM, page tables, address spaces
src/kernel/object/    Kernel object identity and capability authority
src/kernel/task/      Processes, threads, contexts, scheduling metadata
src/kernel/platform/  Board startup, memory maps, console, timers, interrupts
src/user/             Userspace, intentionally empty until the first service
```

The detailed architecture walk-through lives in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). The canonical design record is
[`docs/SPEC.md`](docs/SPEC.md).

## Target Tracks

Cory has two hardware tracks:

```text
Product track:   AArch64 / Raspberry Pi Compute Module 5
Research track:  RISC-V64 / SiFive HiFive Unmatched
```

Initial development happens in QEMU so both architecture paths can stay honest
while the kernel is still small.

## Build And Run

You need a Cyna compiler and QEMU for the target you want to boot.

```sh
cyna version
cyna check .
cyna build .
cyna check cyna.riscv64.toml
cyna build cyna.riscv64.toml
```

Expected normal outputs:

```text
build/cory
build/cory.elf
build/cory.bin
build/cory-riscv64
build/cory-riscv64.elf
build/cory-riscv64.bin
```

Boot the normal images:

```sh
qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory.elf
qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-riscv64.elf
```

Or use the bundled check runner:

```sh
tools/check.sh normal
tools/check.sh all
```

Use a different compiler binary with:

```sh
CYNA=/path/to/cyna tools/check.sh all
```

## Probe Images

Cory keeps deliberate fault and restore experiments out of normal boot. The
check runner builds temporary opt-in manifests for those probe images, boots
them under QEMU, and checks for expected output.

Available probe groups:

```text
tools/check.sh traps       # deliberate trap capture on both targets
tools/check.sh restore     # exception return with eret/sret on both targets
tools/check.sh sched       # trap-driven scheduler handoff on both targets
tools/check.sh timerirq    # timer interrupt delivery on both targets
tools/check.sh timerdiag   # AArch64 diagnostic tick policy
tools/check.sh timersched  # timer-driven scheduler handoff on both targets
tools/check.sh normalsched # AArch64 normal IRQ scheduler path
```

For a full list of individual commands, run:

```sh
tools/check.sh
```

## Reading Path

Start here:

1. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the current codebase
2. [`docs/SPEC.md`](docs/SPEC.md) for the design intent
3. [`tools/check.sh`](tools/check.sh) for the executable validation matrix
4. `src/kernel/platform/*/main.cy` for each target's boot composition

## GitHub Language Stats

GitHub Linguist does not have first-class Cyna support yet, and `.cy` is
currently claimed by Cycript in Linguist's language database. This repository
uses `.gitattributes` to mark `.cy` files as Cyna while excluding them from
GitHub language percentages until Cyna is supported upstream.
