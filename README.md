# Cory

**Cory** is a tiny [Cyna](https://cyna.dev)-native kernel substrate for controlled hardware,
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

Cory now reaches a small interactive userspace on both QEMU targets. The normal
boot path initializes kernel memory, page tables, objects, capabilities,
process/thread metadata, scheduler state, traps, timers, and user address-space
handoff, then starts an init program that launches a shell.

User programs are written in Cyna under `user/`, built into the small Cory user
image format, packed into an initramfs image, and mounted by the kernel at
boot. The current filesystem exposes `/bin` and `/etc`, with `/bin` containing
the first command programs:

```text
cat
echo
ls
ps
selftest
shell
```

The shell is intentionally tiny, but it proves a real path through user/kernel
boundaries: debug output, current process/thread lookup, process spawn,
wait/reap, filesystem reads, directory listing, argument passing, and process
exit all cross through decoded syscalls on both architectures.

Still intentionally missing:

- long-running scheduler workloads
- a standard executable format such as ELF
- IPC
- shared buffers
- the camera pipeline demo

That gap is the point of the next phase: grow the kernel upward only after the
authority and scheduling foundations are real enough to carry it.

## Design Shape

Cory is organized around a few firm boundaries:

```text
kernel/               Kernel project, manifests, source, and build outputs
kernel/src/           Platform-neutral kernel source
kernel/src/arch/      CPU architecture entry, traps, contexts, and page tables
kernel/src/memory/    Physical memory, heap, VM, page tables, address spaces
kernel/src/object/    Kernel object identity and capability authority
kernel/src/task/      Processes, threads, contexts, scheduling metadata
kernel/src/platform/  Board startup, memory maps, console, timers, interrupts
kernel/src/tests/     Kernel selftests and opt-in QEMU probe entrypoints
user/                 User program project sources, manifests, and startup stubs
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

The check runner builds user programs, packs the initramfs, builds the kernel,
boots QEMU, sends a short shell script, and verifies the expected serial output:

```sh
tools/dev.sh normal
tools/dev.sh all
```

For manual builds, build the user programs/initramfs first or use the check
runner once to generate them:

```sh
cyna version
cyna check kernel/cyna.toml --build aarch64
cyna build kernel/cyna.toml --build aarch64
cyna check kernel/cyna.toml --build riscv64
cyna build kernel/cyna.toml --build riscv64
```

Expected normal outputs:

```text
kernel/build/cory-aarch64
kernel/build/cory-aarch64.elf
kernel/build/cory-aarch64.bin
kernel/build/cory-riscv64
kernel/build/cory-riscv64.elf
kernel/build/cory-riscv64.bin
```

Boot the normal images manually:

```sh
qemu-system-aarch64 -machine virt -cpu cortex-a53 -display none -serial stdio -monitor none -kernel kernel/build/cory-aarch64.elf
qemu-system-riscv64 -machine virt -display none -serial stdio -monitor none -bios none -kernel kernel/build/cory-riscv64.elf
```

Or use the developer runner to launch an existing image:

```sh
tools/dev.sh run-aarch64
tools/dev.sh run-riscv64
```

To rebuild the selected target before launching QEMU:

```sh
tools/dev.sh build-run-aarch64
tools/dev.sh build-run-riscv64
```

Use `Ctrl-c` to quit these interactive QEMU runs.

Use a different compiler binary with:

```sh
CYNA=/path/to/cyna tools/dev.sh all
```

## Probe Images

Cory keeps deliberate fault and restore experiments out of normal boot. The
check runner builds temporary opt-in manifests for those probe images, boots
them under QEMU, and checks for expected output.

Available probe groups:

```text
tools/dev.sh traps       # deliberate trap capture on both targets
tools/dev.sh restore     # exception return with eret/sret on both targets
tools/dev.sh sched       # trap-driven scheduler handoff on both targets
tools/dev.sh timerirq    # timer interrupt delivery on both targets
tools/dev.sh timerdiag   # AArch64 diagnostic tick policy
tools/dev.sh timersched  # timer-driven scheduler handoff on both targets
tools/dev.sh normalsched # AArch64 normal IRQ scheduler path
tools/dev.sh userret     # probe-only user-mode exception return
```

For a full list of individual commands, run:

```sh
tools/dev.sh
```

## Reading Path

Start here:

1. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the current codebase
2. [`docs/SPEC.md`](docs/SPEC.md) for the design intent
3. [`tools/dev.sh`](tools/dev.sh) for the executable validation matrix
4. `kernel/src/platform/*/main.cy` for each target's boot composition

## GitHub Language Stats

GitHub Linguist does not have first-class Cyna support yet, and `.cy` is
currently claimed by Cycript in Linguist's language database. This repository
uses `.gitattributes` to mark `.cy` files as Cyna while excluding them from
GitHub language percentages until Cyna is supported upstream.
