# Cycor Specification

Status: draft  
Project: Cycor  
Pronunciation: Sai-core  
Repository: neucine/cycor

## Purpose

Cycor is a Cyna-native capability kernel substrate.

Its immediate purpose is to prove that Cyna can implement serious low-level
systems software: freestanding boot, traps/exceptions, memory management,
virtual memory, scheduling, IPC, capabilities, and userspace service
orchestration.

Its long-term product direction is a camera and imaging operating substrate for
Raspberry Pi Compute Module 5 based hardware.

Cycor is not a general-purpose operating system. It is the privileged substrate
below userspace services and OS personalities. Camera policy, filesystem policy,
display policy, and application behavior belong above the kernel.

## Direction

Cycor grows bottom-up. Each layer must leave behind:

- a small working implementation
- a selftest, boot check, or integration check
- names and comments clear enough to explain ownership and lifecycle
- a spec decision when the concept is not obvious from code

Current build direction:

```text
boot correctness
    -> privilege-mode ownership
    -> memory foundation
    -> virtual memory
    -> kernel objects and capabilities
    -> threads/scheduler
    -> userspace/syscalls
    -> IPC/events
    -> shared buffers
    -> service manager
    -> userspace driver hosts
    -> fake imaging pipeline
```

Near-term work is not camera policy, not POSIX, and not userspace services. The
near-term work is to own the machine cleanly:

- enter the intended privileged kernel mode on each architecture
- establish physical memory, pre-VM heap, and memory-map invariants
- add virtual memory and address-space primitives
- introduce typed kernel objects and capability tables

When choosing the next task, prefer the earliest incomplete layer. Do not add
higher-level policy to compensate for a missing lower-level mechanism.

## Non-Goals

Cycor is not:

- a Linux replacement
- a POSIX-first OS
- a Unix clone
- a desktop OS
- a general server OS
- a mobile OS
- a gaming OS
- a full hardware compatibility project
- a monolithic camera firmware blob

Compatibility layers may exist later. The native model is capability-based,
typed, async-oriented, service-oriented, and observable.

## Kernel Shape

The kernel provides irreducible machine mechanisms:

- enter and control the intended privileged mode
- map memory
- isolate address spaces
- schedule execution
- check capabilities
- send messages
- deliver events
- route interrupts
- control MMIO and device access
- account resources
- expose trace data

Everything else is policy above the kernel.

The privileged core should contain only mechanisms that require privileged
execution:

- architecture boot and privilege transition
- trap/exception handling
- physical memory manager
- virtual memory manager
- address spaces
- kernel object table
- capability table
- threads/tasks
- scheduler primitives
- IPC primitives
- timers
- interrupt dispatch
- device/MMIO/IOMMU control
- resource accounting hooks
- trace hooks

The privileged core should not contain:

- filesystem policy
- network stack policy
- display server
- camera application
- sensor pipeline policy
- ISP policy
- storage format policy
- power policy
- user/session model
- POSIX compatibility policy

## Layer Architecture

```text
Applications / Product Services
    Camera App
    Gallery App
    Settings App
    Diagnostics App

Imaging Services
    Capture Service
    Sensor Service
    ISP Service
    Preview Service
    Storage Writer
    Display Service

General System Services
    Init / Service Manager
    Driver Manager
    Filesystem Service
    Log / Trace Service
    Resource Manager
    Security Policy Service

Cycor Kernel Core
    Kernel Objects
    Capabilities
    Address Spaces
    Threads / Tasks
    Scheduler
    IPC
    Shared Memory
    Events / Wait Sets
    Timers
    Interrupt Routing
    Device Isolation
    Resource Accounting

Architecture + Platform Layer
    CPU privilege entry
    traps/exceptions
    timer/interrupt controller glue
    UART/MMIO descriptions
    board memory layout

Hardware
```

## Architecture and Platform Portability

`arch` is CPU architecture. `platform` is board, SoC, or virtual machine.

```text
kernel/
  arch/
    aarch64/
    riscv64/

  platform/
    qemu_aarch64_virt/
    qemu_riscv64_virt/
    raspberrypi_cm5/
    sifive_unmatched/
```

Rules:

- Do not put Raspberry Pi specific code under `arch/aarch64`.
- Do not put QEMU `virt` specifics under generic architecture code.
- Do not put SiFive specific code under `arch/riscv64`.
- Architecture code owns CPU privilege level, traps, register save/restore,
  page-table format, atomics, barriers, and context switch mechanics.
- Platform code owns memory layout, UART base addresses, interrupt controller
  instances, timers, device tree or board descriptors, and boot-device quirks.
- Common kernel code must depend on architecture/platform traits or small Cyna
  modules, not on concrete QEMU constants.

Portability is a first-class requirement because Cycor has two tracks:

| Track | Target | Purpose |
|---|---|---|
| Product | AArch64 / Raspberry Pi CM5 | future camera and imaging hardware |
| Research | RISC-V64 / QEMU + SiFive | architecture validation and Cyna backend pressure |

Both QEMU targets should keep boot checks working. Platform parity bugs are
valuable because they reveal hidden assumptions in Cyna, the linker, runtime
builtins, or Cycor's architecture split.

## Privilege-Mode Decision

Cycor should run the kernel in the normal OS privilege level for each
architecture:

- AArch64 kernel mode: EL1
- RISC-V kernel mode: S-mode

Current status:

- AArch64 QEMU direct boot enters Cycor and writes `VBAR_EL1`, but Cycor does
  not yet explicitly detect EL or drop from EL2/EL3 to EL1.
- RISC-V QEMU direct boot with `-bios none` enters Cycor and writes `mtvec`, so
  Cycor is currently effectively running in M-mode.

Required direction:

```text
AArch64:
  _start
    read CurrentEL
    if EL3: configure SCR_EL3, SPSR_EL3, ELR_EL3, eret
    if EL2: configure HCR_EL2/CNTHCTL_EL2, SPSR_EL2, ELR_EL2, eret
    if EL1: continue
  el1_entry
    set stack
    set VBAR_EL1
    call common kernel entry

RISC-V:
  _start in M-mode
    set temporary M-mode stack
    delegate S-mode traps/interrupts
    configure PMP for kernel RAM access
    set mepc = s_mode_entry
    set mstatus.MPP = S
    mret
  s_mode_entry
    set S-mode stack
    set stvec
    call common kernel entry
```

This must be completed before virtual memory, timers, interrupts, and userspace
become serious.

## Memory Architecture

Memory has a strict allocator hierarchy:

```text
boot bump allocator
    -> physical page allocator
        -> pre-VM kernel heap
            -> future VM-backed kernel heap
```

### Boot Bump Allocator

Decision:

- module: `kernel.memory.boot`
- role: fixed-range allocator for early metadata
- granularity: bytes
- free/reuse: none
- lifetime: from `_start` until physical allocator initialization completes

The boot allocator starts at the page-aligned kernel end and ends at the
platform RAM limit. The physical allocator reserves its bitmap through the boot
allocator, snapshots the consumed range, then freezes the boot allocator.

### Physical Page Allocator

Decision:

- module: `kernel.memory.phys`
- role: physical frame ownership
- granularity: page
- free/reuse: yes
- policy: first-fit bitmap for now

The physical allocator owns frame availability. It does not know kernel object
sizes. It should not become a fine-grained object allocator.

The handoff rule is page-granular: every page touched by the kernel image, boot
allocations, or physical allocator metadata is reserved. The first reusable page
after boot allocations is `align_up(boot.next, page_size)`, with no hidden
padding.

### Kernel Heap

Decision:

- module: `kernel.memory.heap`
- import alias: `heap`
- concept name: kernel heap
- current implementation: pre-VM page-backed bump suballocator
- future implementation: VM-backed reusable fine-grained allocator

The module path already identifies the heap as kernel-owned. Avoid the redundant
local name `kheap`.

The heap is the kernel object allocation policy, not the physical frame
allocator. It requests pages from `phys`, then serves smaller aligned
allocations inside those committed pages.

Current pre-VM policy:

- returns identity-mapped addresses
- lazily commits pages from `phys`
- keeps committed pages physically contiguous so the memory map can describe
  them with one `pre_vm_heap` region
- does not reuse deallocated allocations yet
- requires nonzero power-of-two alignment
- tracks requested bytes separately from used bytes
- exposes status codes for failed allocation diagnostics

Future VM-backed policy:

- reserve a kernel virtual heap range
- map arbitrary physical frames into that range
- replace bump-only allocation with free lists, slabs, or another reusable
  fine-grained policy
- preserve the external heap API where practical

### Memory Map

Decision:

- module: `kernel.memory.map`
- role: canonical explanation of RAM ownership during bring-up
- storage: fixed table, no heap dependency
- construction: collect owned regions, sort by address, fill gaps as `free_ram`

Region kinds:

- `free_ram`
- `kernel_image`
- `boot_allocator`
- `physical_page_bitmap`
- `pre_vm_heap`
- `device_mmio`
- `kernel_stack`

Regions must be ordered and non-overlapping. VM setup must preserve identity
mappings for every non-`free_ram` region until a later subsystem explicitly
migrates or releases it.

### Virtual Memory

Decision:

- VM is the next memory layer after physical allocation and pre-VM heap.
- VM owns mappings, not physical frame availability and not fine-grained heap
  policy.
- Address spaces are kernel objects and should arrive before userspace.

Near-term VM goals:

- define physical-address and virtual-address naming conventions
- identity-map the kernel image and all non-`free_ram` memory-map regions
- establish a kernel virtual range for future heap migration
- add page map/unmap operations with explicit rights
- prepare user/kernel address separation

## Kernel Object and Capability Model

Cycor's native authority model is capability-based.

A capability answers:

```text
which object?
which rights?
can this authority be delegated?
can it be duplicated?
can it be revoked?
```

Initial kernel object candidates:

- `KernelObject`
- `Capability`
- `Process`
- `Thread`
- `AddressSpace`
- `MemoryRegion`
- `SharedBuffer`
- `Channel`
- `Event`
- `WaitSet`
- `Timer`
- `Interrupt`
- `Device`

Initial rights:

- `Read`
- `Write`
- `Execute`
- `Map`
- `Send`
- `Receive`
- `Signal`
- `Inspect`
- `Manage`
- `Configure`
- `Transfer`
- `Duplicate`
- `Revoke`

Rules:

- A process cannot access a protected object without a capability.
- Rights are checked in the kernel.
- Capabilities may be transferred through IPC if allowed.
- Capabilities may be duplicated if allowed.
- Capabilities may be revoked if revocation authority exists.
- Capability tables are per-process or per-protection-domain.
- Kernel-created root capabilities are distributed by the initial system
  service.

Do not implement complex userspace services before object identity and
capability tables exist.

## IPC and Event Model

Decision:

- native IPC is async-first
- blocking APIs may later be wrappers over async primitives
- IPC is the main way to delegate authority
- large data moves through `SharedBuffer`, not copied IPC payloads

Core objects:

- `Channel`
- `Message`
- `Event`
- `WaitSet`
- `Timer`
- `SharedBuffer`

A message may contain:

- small inline payload
- transferred capabilities
- shared buffer references
- event/fence handles
- protocol-specific metadata

Wait sets allow a service to wait on multiple sources:

- channel message
- event signal
- timer expiry
- interrupt event
- process exit
- buffer fence

## SharedBuffer Model

`SharedBuffer` is a first-class kernel object for moving large data across
isolated services without copying.

The kernel should know:

- buffer size
- owner
- mappings
- rights
- lifetime
- accounting
- synchronization state

The kernel should not know:

- RAW format
- JPEG
- DNG
- demosaic
- color science
- camera exposure policy

SharedBuffer becomes important after address spaces, capabilities, IPC, and
events exist. Do not build it first just because the product direction is
imaging.

## Scheduler Model

Initial scheduler decision:

- simple round-robin or simple priority scheduler
- thread states
- sleep/wakeup
- timer support
- basic preemption
- thread exit

Future camera-oriented scheduling classes may include:

- `capture-critical`
- `preview-realtime`
- `ui-interactive`
- `storage-throughput`
- `background`
- `maintenance`

Policy should remain outside the kernel where possible. The kernel exposes
mechanisms such as priority, timers, budget accounting, preemption controls, and
trace hooks.

## Device and Driver Model

Decision:

- drivers should run in isolated userspace driver hosts where practical
- kernel owns device access control, MMIO mapping, interrupt routing, DMA
  buffer authority, and fault reporting
- userspace driver hosts own device policy and recovery behavior

Kernel responsibilities:

- validate device access
- control MMIO mapping
- route interrupts as events
- enforce IOMMU/device isolation where available
- track device ownership
- revoke device capabilities
- report device faults

Driver host responsibilities:

- own a device capability
- map MMIO only through kernel-approved mappings
- receive interrupts as events
- allocate/map DMA buffers
- communicate with clients through channels
- restart after failure where possible

Initial QEMU device targets:

- UART
- generic timer
- interrupt controller
- virtio-console
- virtio-block
- virtio-net later
- framebuffer later

## Platform Strategy

Product track:

- AArch64
- Raspberry Pi Compute Module 5
- future CM5 camera/display/storage experiments

Research track:

- RISC-V64
- QEMU `virt`
- SiFive HiFive Unmatched later
- architecture validation and Cyna backend pressure

Bring-up order:

1. AArch64 QEMU `virt`
2. RISC-V64 QEMU `virt`
3. explicit privilege-mode ownership on both
4. Raspberry Pi CM5 serial boot
5. CM5 timer/interrupt/memory stability
6. SiFive board bring-up if useful
7. CM5 storage/display/input
8. CM5 camera-oriented services

Do not make early milestones depend on MIPI CSI or ISP control.

## Imaging Direction

The product direction is camera and imaging hardware, but the kernel must not
become a camera application.

Future service architecture:

```text
Camera App
    -> Capture Service
        -> Sensor Service
        -> ISP Service
        -> Preview Service
        -> Storage Writer
        -> Display Service
```

The first meaningful imaging demo should be a fake camera pipeline across
isolated userspace services:

```text
FakeSensor -> FakeISP -> Preview
                       -> StorageWriter
```

The fake pipeline should demonstrate:

- isolated services
- capability-limited access
- `SharedBuffer` frame movement
- async events
- trace records
- no large IPC copies
- dropped-frame accounting

This demo belongs after userspace, IPC, capabilities, events, and shared buffers
exist.

## MVP

The MVP is not a shell.

The MVP is a fake camera pipeline running across isolated userspace services:

```text
FakeSensor -> FakeISP -> Preview -> StorageWriter
```

MVP components:

- bootable AArch64 QEMU kernel
- bootable RISC-V64 QEMU kernel for parity
- architecture privilege-mode ownership
- physical memory manager
- virtual memory manager
- kernel heap
- process/thread objects
- basic scheduler
- syscall entry
- capability table
- channel IPC
- event/waitset
- shared buffer object
- userspace init
- service manager
- fake sensor service
- fake ISP service
- fake preview service
- fake storage writer
- trace/log service

MVP success criteria:

- kernel boots in QEMU
- userspace init runs
- services run in isolated processes
- capabilities restrict access between services
- IPC transfers capabilities
- `SharedBuffer` moves frame-like data without large copies
- fake camera pipeline emits latency traces
- the system shows why a frame was delayed, dropped, or completed

## Roadmap

The roadmap is the execution order for kernel work. Earlier incomplete phases
take priority over later features unless a later experiment explicitly validates
an earlier design.

Current status:

- QEMU AArch64 boots and reaches kernel selftests.
- QEMU RISC-V64 boots and reaches kernel selftests.
- Both QEMU targets still rely on convenient direct kernel entry.
- Physical allocation, pre-VM heap, memory-map ownership, and heap diagnostics
  exist.
- VM is not implemented.
- Kernel objects, capabilities, scheduler, userspace, IPC, and shared buffers
  are not implemented.

### Phase 0 — Specification and Repo Shape

Goal:

```text
Make direction and decisions explicit enough to guide implementation.
```

Done when:

- spec explains architecture and kernel shape
- spec records subsystem decisions
- spec records portability model
- roadmap points to the next layer

### Phase 1 — QEMU Boot and Platform Parity

Goal:

```text
Boot both first-class QEMU targets and keep them green.
```

Targets:

- `qemu-system-aarch64 -machine virt`
- `qemu-system-riscv64 -machine virt`

Done:

- direct QEMU kernel entry
- serial logging
- panic path
- basic exception/trap vector
- boot selftests

Still incomplete:

- explicit AArch64 EL transition
- explicit RISC-V M-mode to S-mode transition

### Phase 2 — Privilege-Mode Ownership

Goal:

```text
Enter and own the intended kernel privilege mode on each architecture.
```

AArch64 deliverables:

- read `CurrentEL`
- transition EL3/EL2 to EL1 when required
- set EL1 stack
- set `VBAR_EL1`
- document register ownership before common kernel entry

RISC-V deliverables:

- split `_start` into M-mode shim and S-mode kernel entry
- configure trap/interrupt delegation
- configure PMP for kernel RAM access
- enter S-mode with `mret`
- set `stvec` for S-mode traps
- document M-mode responsibilities left behind

### Phase 3 — Memory Foundation

Goal:

```text
Provide memory primitives strong enough for VM and kernel objects.
```

Done:

- boot bump allocator
- physical page allocator
- pre-VM heap
- memory map with sorted owned regions
- heap diagnostics
- AArch64/RISC-V boot checks

Next:

- physical-address and virtual-address naming conventions
- page-table abstractions per architecture
- kernel identity mapping from memory map
- kernel virtual heap range
- transition heap from pre-VM physical identity mapping to VM-backed virtual
  mapping

### Phase 4 — Virtual Memory and Address Spaces

Goal:

```text
Map kernel and user memory explicitly.
```

Deliverables:

- page-table creation
- map/unmap operations
- kernel address-space bootstrap
- identity mapping for boot-owned regions
- kernel heap virtual range
- user/kernel memory split
- address-space object draft

### Phase 5 — Kernel Objects and Capabilities

Goal:

```text
Represent object identity, lifetime, and authority.
```

Deliverables:

- kernel object IDs
- object table
- capability table
- rights checks
- capability duplication
- capability transfer draft
- object lifetime/refcount model
- revocation draft

### Phase 6 — Threads, Timers, and Scheduler

Goal:

```text
Run multiple execution contexts.
```

Deliverables:

- thread object
- context switch
- scheduler loop
- timer interrupt
- sleep/wakeup
- basic priority
- thread exit

### Phase 7 — Userspace and Syscalls

Goal:

```text
Run the first userspace process.
```

Deliverables:

- user address space
- executable loader
- syscall entry/exit
- user memory validation
- process object
- init process
- debug output syscall or debug channel

### Phase 8 — IPC and Events

Goal:

```text
Enable service architecture.
```

Deliverables:

- channel object
- message send/receive
- capability transfer over IPC
- event object
- wait set
- timer event
- async wait primitive

### Phase 9 — SharedBuffer

Goal:

```text
Move frame-like data without large copies.
```

Deliverables:

- shared buffer object
- map/unmap into processes
- rights-controlled buffer access
- transfer over IPC
- basic fence/event synchronization
- resource accounting

### Phase 10 — Service Manager and Driver Hosts

Goal:

```text
Start, supervise, and isolate userspace services.
```

Deliverables:

- init service
- service spawning
- capability distribution
- service crash reporting
- restart policy
- device capability
- MMIO mapping
- interrupt event delivery
- virtio driver prototype

### Phase 11 — Fake Imaging Pipeline

Goal:

```text
Demonstrate Cycor's product direction without real camera hardware.
```

Services:

- FakeSensor
- FakeISP
- Preview
- StorageWriter
- TraceService

Success:

- frame-like buffers use `SharedBuffer`
- no large IPC copies
- services are isolated
- capabilities restrict authority
- trace output reports latency, ownership, and drops

## Hard Constraints

- native API is capability-based
- native API is async/event-oriented
- no ioctl-style untyped escape hatch as the native model
- drivers are userspace by default
- kernel object access always checks rights
- `SharedBuffer` is first-class
- observability is not optional
- POSIX is optional and not foundational
- camera use cases influence the core but do not pollute it
- Cyna ergonomics are part of the success criteria

## Glossary

### Architecture

CPU family behavior such as privilege levels, traps, page tables, atomics,
barriers, and context switching.

### Platform

Board, SoC, or virtual machine behavior such as memory layout, UART addresses,
interrupt-controller instance, and boot-device quirks.

### AArch64

64-bit Arm architecture. Cycor's primary product architecture because Raspberry
Pi CM5 is Arm-based.

### RISC-V64

64-bit RISC-V architecture. Cycor's research architecture for portability and
Cyna backend validation.

### Cyna

The systems programming language in the Neucine ecosystem. Cycor is intended to
be written primarily in Cyna.

### Cycor

Pronounced Sai-core. A Cyna-native capability kernel substrate for language
demonstration and future camera/imaging hardware.

### Capability

A transferable authority object that grants rights over a kernel object.

### Channel

A message-based IPC object.

### Event

A kernel object that can be signaled and waited on.

### WaitSet

An object allowing a task or service to wait on multiple events, channels,
timers, or completions.

### SharedBuffer

A first-class kernel object for zero-copy sharing of large buffers between
isolated services.

### Pre-VM Heap

The temporary kernel heap policy used before virtual memory owns heap mappings.
It is backed by physical pages and must be preserved in the memory map as
`pre_vm_heap`.

### Kernel Substrate

The minimal privileged layer that provides machine mechanisms while avoiding
product policy.
