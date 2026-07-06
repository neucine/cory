# Cory

**Cory** is pronounced **Core-ry**.

Cory is a Cyna-native capability kernel substrate designed to demonstrate Cyna's systems-programming capabilities and eventually serve as the operating substrate for Raspberry Pi Compute Module 5 based camera and imaging hardware.

Cory is not a Linux replacement, Unix clone, desktop OS, or general-purpose server OS. It is a small kernel substrate for controlled hardware, product-specific OS personalities, and imaging-oriented systems.

## Project identity

```text
Neucine  — ecosystem / organization
Cyna     — systems programming language
Cory     — Cyna-native kernel substrate, pronounced Core-ry
```

## Canonical specification

The full project specification is in [`docs/SPEC.md`](docs/SPEC.md).
For a shorter reader path through the current implementation, see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

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
src/kernel/memory/    Physical memory, heap, VM, page tables, address spaces
src/kernel/object/    Kernel object identity and capability authority
src/kernel/platform/  Kernel-owned platform startup, memory maps, console, and linker scripts
src/user/             Userspace source, intentionally empty until needed
```

`docs/SPEC.md` remains the place for planned structure. Source directories should
exist when there is real code for that boundary.

## Initial target platforms

Cory has two hardware tracks:

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

The first meaningful Cory demo is not a shell.

It is a fake camera pipeline:

```text
FakeSensor -> FakeISP -> Preview -> StorageWriter
```

The pipeline should run across isolated userspace services, communicate through capability-based IPC, move frame-like data using `SharedBuffer` objects, and report end-to-end latency through the trace system.

## Current progress

Cory currently boots both QEMU targets into kernel selftests:

- AArch64 `virt` starts at EL1, or drops EL2 to EL1 before common kernel entry.
- RISC-V64 `virt` uses a small M-mode shim and enters the kernel in S-mode.
- Both targets initialize trap vectors, capture full trap frames, and expose
  resume-state helpers.
- AArch64 separates synchronous exception and IRQ vector callbacks while
  preserving one trap-frame layout; normal boot enables scheduler tick mode and
  resumes a normal kernel worker from a periodic timer IRQ.
- Memory bootstrap, bootstrap page tables, physical pages, heap, address-space
  metadata, kernel object IDs, capabilities, process metadata, thread metadata,
  and scheduler metadata all have boot-time selftests.
- Opt-in probes validate deliberate traps, trap-frame restore with `eret`/`sret`,
  and a trap-driven scheduler handoff on both targets. AArch64 also validates a
  dry-run diagnostic tick, a timer-IRQ-driven scheduler handoff, and the normal
  IRQ handler's scheduler tick branch in opt-in probes.
- Timer groundwork exists on both targets; AArch64 also proves masked deadline
  programming, configures the virtual timer IRQ route, enables periodic
  scheduler tick delivery, and validates virtual timer IRQ delivery through QEMU
  `virt` GICv2 INTID 27.

Still intentionally missing: a long-running scheduler loop, userspace entry,
syscalls, IPC, and shared buffers.

## Build

```text
cyna version
cyna check .
cyna build .
cyna check cyna.riscv64.toml
cyna build cyna.riscv64.toml
```

Expected outputs:

```text
build/cory
build/cory.elf
build/cory.bin
build/cory-riscv64
build/cory-riscv64.elf
build/cory-riscv64.bin
```

The current kernel entries write to the QEMU `virt` UART, initialize exception
or trap vectors, verify readable timer counters plus masked AArch64 deadline
programming, configure the AArch64 timer IRQ route, enable periodic scheduler
tick mode, run common bootstrap selftests through memory, VM, address spaces,
and object/capability contracts, print `memory: physical pages ready`, then
resume a normal AArch64 kernel worker from a timer-driven scheduler tick.
When QEMU is available, run:

```text
qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory.elf
qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-riscv64.elf
```

The common check/build/QEMU flows are wrapped by:

```text
tools/check.sh normal
tools/check.sh traps
tools/check.sh restore
tools/check.sh sched
tools/check.sh timerirq
tools/check.sh timerdiag
tools/check.sh timersched
tools/check.sh normalsched
tools/check.sh all
```

Use `CYNA=/path/to/cyna tools/check.sh all` to test with a different compiler
binary.

## Trap diagnostic probes

Normal boot must not deliberately panic. Trap diagnostics are tested through
separate opt-in probe images. `tools/check.sh` generates their temporary Cyna
manifests from the target manifests:

```text
tools/check.sh trap-aarch64
tools/check.sh trap-riscv64
```

These images intentionally execute `brk` on AArch64 or `ebreak` on RISC-V64,
print captured architecture trap state, then panic.

## Restore diagnostic probes

Restore probes validate the exception-return paths in opt-in images:

```text
tools/check.sh restore-aarch64
tools/check.sh restore-riscv64
```

They trigger `brk` or `ebreak`, advance the saved return PC, restore from the
trap frame, print a `restoretest: resumed ...` line, then intentionally panic.
Normal boot and trap diagnostic images still use the panic-only trap path.

## Trap scheduling probe

Scheduler probes validate the first integrated trap scheduling handoff in
opt-in images:

```text
tools/check.sh sched-aarch64
tools/check.sh sched-riscv64
```

They create a ready kernel thread, trigger `brk` or `ebreak` from the current
thread, save the interrupted trap frame, schedule the ready thread, write that
thread's saved resume state into the trap frame, restore with `eret` or `sret`,
print `schedtest: thread b resumed`, then intentionally panic.

## Timer IRQ probe

The AArch64 timer IRQ probe validates virtual timer delivery through the QEMU
`virt` GICv2 path:

```text
tools/check.sh timerirq-aarch64
```

It configures the virtual timer PPI, unmasks IRQs, receives INTID 27, disarms
the timer, prints `timerirqtest: received virtual timer irq`, then intentionally
panics. Normal boot uses the same timer IRQ class for periodic scheduler ticks.

## Diagnostic tick probe

The AArch64 diagnostic tick probe validates the dry-run tick policy mode:

```text
tools/check.sh timerdiag-aarch64
```

It enables tick delivery in diagnostic mode, receives INTID 27, disarms and EOIs
the timer interrupt, prints `timerdiagtest: diagnostic tick`, then intentionally
panics. It does not schedule.

## Timer scheduling probe

The AArch64 timer scheduling probe validates the first timer-driven
schedule-and-restore handoff in an opt-in image:

```text
tools/check.sh timersched-aarch64
```

It creates a ready kernel thread, programs the virtual timer, receives INTID 27,
disarms and EOIs the timer interrupt, schedules the ready thread from the saved
trap frame, restores with `eret`, prints `timerschedtest: thread b resumed`,
then intentionally panics.

## Normal IRQ scheduler probe

The AArch64 normal IRQ scheduler probe validates the scheduler branch in the
normal platform IRQ handler:

```text
tools/check.sh normalsched-aarch64
```

It creates a ready kernel thread, enables scheduler tick delivery, receives the
virtual timer IRQ through `exception.cy`, schedules from the saved trap frame,
prints `tick: scheduler tick` and `normalschedtest: thread b resumed`, then
intentionally panics. Normal boot enables the same periodic scheduler tick mode,
and now queues a normal kernel worker that resumes from that path.
