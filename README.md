# Cycor

**Cycor** is pronounced **Sai-core**.

Cycor is a Cyna-native capability kernel substrate designed to demonstrate Cyna's systems-programming capabilities and eventually serve as the operating substrate for Raspberry Pi Compute Module 5 based camera and imaging hardware.

Cycor is not a Linux replacement, Unix clone, desktop OS, or general-purpose server OS. It is a small kernel substrate for controlled hardware, product-specific OS personalities, and imaging-oriented systems.

## Project identity

- **Neucine**: ecosystem / organization
- **Cyna**: systems programming language
- **Cycor**: Cyna-native kernel substrate

Suggested repository:

```text
neucine/cycor
```

## Goals

Cycor has two connected goals.

### 1. Demonstrate Cyna as a systems language

Cycor exists to pressure-test Cyna in serious low-level systems programming:

- bare-metal boot
- memory layout
- physical and virtual memory management
- exceptions, traps, and interrupts
- syscall ABI design
- scheduling
- object lifetime management
- capability ownership
- userspace service boundaries
- driver isolation
- unsafe hardware access
- async IPC
- zero-copy buffer ownership

If Cycor is painful to write in Cyna, that is useful feedback for Cyna.

### 2. Become a camera/imaging hardware substrate

Cycor's long-term hardware direction is Raspberry Pi CM5 based camera and imaging systems.

Future target capabilities include:

- image sensor control
- ISP coordination
- RAW buffer movement
- preview pipeline
- storage pipeline
- display pipeline
- button/input handling
- battery and thermal policy
- fast boot
- low capture latency
- high reliability
- deep diagnostics for frame latency and dropped frames

The kernel itself should not become a camera application. It should provide the primitives needed to build a camera OS above it.

## Non-goals

Cycor is explicitly not:

- a Linux replacement
- a Unix clone
- a POSIX-first OS
- a general desktop OS
- a general server OS
- a gaming OS
- a mobile OS
- a full driver ecosystem
- a compatibility-first kernel
- a monolithic camera firmware blob

POSIX compatibility may be explored later as an optional personality layer, but it must not define the native architecture.

## Core ideas

- Cyna-first implementation
- capability-first security
- small privileged kernel core
- async-first service model
- userspace drivers by default
- shared buffers for zero-copy data movement
- deep tracing and resource accounting
- AArch64 first for Raspberry Pi CM5 product direction
- RISC-V64 second for architecture validation on SiFive HiFive Unmatched
- fake camera pipeline as the first meaningful system demo

## Initial target platforms

Cycor has two hardware tracks.

### Product track

- Architecture: AArch64
- Primary board: Raspberry Pi Compute Module 5
- Purpose: future camera/imaging hardware

### Research track

- Architecture: RISC-V64
- Board: SiFive HiFive Unmatched
- Purpose: architecture validation and kernel experimentation

Initial development starts in QEMU:

- `qemu-system-aarch64 -machine virt`
- `qemu-system-riscv64 -machine virt`

x86_64 support is optional and may be added later, but it is not the first target.

## MVP

The first meaningful Cycor demo is not a shell.

It is a fake camera pipeline:

```text
FakeSensor -> FakeISP -> Preview -> StorageWriter
```

The pipeline should run across isolated userspace services, communicate through capability-based IPC, move frame-like data using `SharedBuffer` objects, and report end-to-end latency through the trace system.

MVP success criteria:

- kernel boots in QEMU
- userspace init runs
- services run in isolated processes
- capabilities restrict access between services
- IPC transfers capabilities
- `SharedBuffer` moves frame-like data without copies
- fake camera pipeline emits latency traces
- the system shows why a frame was delayed, dropped, or completed

## Documentation

Start with:

- [`docs/spec.md`](docs/spec.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/platforms.md`](docs/platforms.md)
- [`docs/roadmap.md`](docs/roadmap.md)
- [`docs/capabilities.md`](docs/capabilities.md)
- [`docs/ipc.md`](docs/ipc.md)
- [`docs/shared-buffer.md`](docs/shared-buffer.md)
- [`docs/imaging.md`](docs/imaging.md)
- [`docs/glossary.md`](docs/glossary.md)
