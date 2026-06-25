# Cycor Roadmap

## Phase 0 — Repository and specification

Deliverables:

- `README.md`
- `docs/spec.md`
- `docs/architecture.md`
- `docs/platforms.md`
- `docs/roadmap.md`
- `docs/capabilities.md`
- `docs/ipc.md`
- `docs/shared-buffer.md`
- `docs/imaging.md`
- `docs/glossary.md`

Goal:

```text
Define the project before writing too much kernel code.
```

## Phase 1 — AArch64 QEMU boot

Goal:

```text
Boot into Cycor kernel code on qemu-system-aarch64 -machine virt.
```

Features:

- boot path
- early serial logging
- panic handler
- exception vector setup
- basic memory map
- early allocator
- minimal test harness

## Phase 2 — RISC-V64 QEMU boot

Goal:

```text
Boot into Cycor kernel code on qemu-system-riscv64 -machine virt.
```

Features:

- boot path
- serial logging
- trap handler
- panic handler
- basic memory map
- early allocator
- minimal test harness

## Phase 3 — Memory foundation

Goal:

```text
Manage memory safely enough to support kernel objects and tasks.
```

Features:

- physical page allocator
- virtual memory manager
- kernel heap or slab allocator
- address space abstraction
- page mapping/unmapping
- user/kernel memory separation draft

## Phase 4 — Kernel objects and capabilities

Goal:

```text
Represent authority and object lifetime.
```

Features:

- `KernelObject`
- object IDs
- capability table
- rights checking
- capability duplication
- capability transfer draft
- object refcount/lifetime
- capability revocation draft

## Phase 5 — Threads and scheduler

Goal:

```text
Run multiple execution contexts.
```

Features:

- thread creation
- context switch
- scheduler loop
- timer interrupt
- sleep/wakeup
- basic priority
- thread exit

## Phase 6 — Userspace and syscalls

Goal:

```text
Run the first userspace process.
```

Features:

- user address space
- executable loader
- syscall entry/exit
- user memory validation
- process object
- init process
- debug output syscall or debug channel

## Phase 7 — IPC and events

Goal:

```text
Enable service architecture.
```

Features:

- `Channel`
- message send/receive
- capability transfer over IPC
- `Event`
- `WaitSet`
- `Timer`
- async wait primitive

## Phase 8 — SharedBuffer

Goal:

```text
Move large frame-like data without copies.
```

Features:

- `SharedBuffer` object
- map/unmap into processes
- rights-controlled buffer access
- buffer transfer over IPC
- basic fence/event synchronization
- resource accounting

## Phase 9 — Service manager

Goal:

```text
Start, supervise, and restart userspace services.
```

Features:

- init service
- service spawning
- capability distribution
- service crash reporting
- restart policy
- log/trace service

## Phase 10 — Userspace driver host

Goal:

```text
Prove isolated drivers.
```

Features:

- device capability
- MMIO mapping
- interrupt event delivery
- virtio driver prototype
- driver crash/restart

## Phase 11 — Fake camera pipeline

Goal:

```text
Demonstrate Cycor's imaging direction.
```

Services:

- FakeSensor
- FakeISP
- Preview
- StorageWriter
- TraceService

Pipeline:

```text
FakeSensor -> FakeISP -> Preview
                       -> StorageWriter
```

Success:

- frame-like buffers use `SharedBuffer`
- no large IPC copies
- services are isolated
- capabilities restrict authority
- trace output reports latency and ownership
