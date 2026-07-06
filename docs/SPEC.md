# Cory Specification

Status: draft  
Project: Cory  
Pronunciation: Sai-core  
Repository: neucine/cory

See `docs/ARCHITECTURE.md` for the shorter source-layout and boot-flow map.

## Purpose

Cory is a Cyna-native capability kernel substrate.

Its immediate purpose is to prove that Cyna can implement serious low-level
systems software: freestanding boot, traps/exceptions, memory management,
virtual memory, scheduling, IPC, capabilities, and userspace service
orchestration.

Its long-term product direction is a camera and imaging operating substrate for
Raspberry Pi Compute Module 5 based hardware.

Cory is not a general-purpose operating system. It is the privileged substrate
below userspace services and OS personalities. Camera policy, filesystem policy,
display policy, and application behavior belong above the kernel.

## Direction

Cory grows bottom-up. Each layer must leave behind:

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

Cory is not:

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

Cory Kernel Core
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
- Timer and interrupt ownership is a platform contract, not a generic
  architecture schema. AArch64 QEMU `virt` currently gives Cory a direct EL1
  virtual timer plus GICv2 path. RISC-V QEMU `virt -bios none` starts through
  Cory's M-mode shim, so timer delivery must first define the machine-timer to
  S-mode handoff before common scheduler code can consume ticks there.
- Platform memory layout must include both RAM and boot-critical MMIO ranges.
  Current QEMU platforms publish platform device MMIO ranges so VM activation
  can keep panic logging and interrupt-controller access reachable after
  identity translation is enabled.
- `extern c` declarations are a C ABI boundary, not an ordinary Cyna boundary.
  Use C ABI carrier types such as `c_ulong`, `c_size_t`, pointers, and
  C-layout structs in the declaration, then convert to kernel-native types such
  as `usize` inside Cyna code after the call returns.
- Assembly symbols called through `extern c` must obey the target C ABI:
  return scalar values in the ABI return register, preserve callee-saved
  registers, and use the target ABI return instruction.

Portability is a first-class requirement because Cory has two tracks:

| Track | Target | Purpose |
|---|---|---|
| Product | AArch64 / Raspberry Pi CM5 | future camera and imaging hardware |
| Research | RISC-V64 / QEMU + SiFive | architecture validation and Cyna backend pressure |

Both QEMU targets should keep boot checks working. Platform parity bugs are
valuable because they reveal hidden assumptions in Cyna, the linker, runtime
builtins, or Cory's architecture split.

## Privilege-State Model

Cory has one privileged kernel contract per architecture:

| Architecture | Kernel contract | Current entry path |
|---|---|---|
| AArch64 | EL1 | QEMU may enter at EL1 or EL2; `arch/aarch64/start.S` normalizes EL2 to EL1 before calling Cyna |
| RISC-V64 | S-mode | QEMU `virt -bios none` enters in M-mode; `arch/riscv64/start.S` uses M-mode only for PMP/delegation setup, then `mret`s to S-mode before calling Cyna |

Common Cyna kernel code starts after this normalization. It should not branch on
raw architecture privilege state. Architecture code owns the transition into the
kernel contract and must leave behind small, documented entry labels:

- AArch64: `cory_aarch64_el1_entry` is the first normalized EL1 entry point.
- RISC-V64: `cory_riscv64_s_entry` is the first S-mode kernel entry point.

The current RISC-V path intentionally assumes a machine-mode firmware contract
equivalent to QEMU `-bios none`: Cory owns the M-mode setup long enough to open
PMP and delegate basic traps. A future firmware/SBI boot path should be a
separate platform entry path, not an implicit change to common RISC-V code.

Current privilege-mode scope:

- AArch64 configures EL2 enough to enter EL1 with a stack and direct exception
  vector setup.
- RISC-V64 configures one permissive PMP range, delegates the currently needed
  synchronous exceptions and supervisor interrupts, and enters S-mode.
- Timer counter access exists on both QEMU targets. AArch64 also has masked
  virtual deadline programming plus opt-in GICv2 virtual timer IRQ delivery.
- RISC-V timer interrupt-controller setup is deliberately not treated as the
  same shape as AArch64 GICv2. The next RISC-V timer slice should decide and
  test one ownership path: either keep the current `-bios none` M-mode shim as
  Cory-owned firmware for machine timer handoff, or add a separate SBI-style
  platform entry. SBI integration, user-mode entry, and normal trap-return
  dispatch are not implemented yet.

This model matters for portability: if a platform starts at a different
privilege level, the platform or architecture entry code must adapt before Cyna
common kernel code runs.

## Trap-State Model

Cory separates panic diagnostics from recoverable trap frames.

The current boot-stage vectors are panic-only. They capture a diagnostic frame
and call into Cyna with C ABI carrier values:

| Architecture | Diagnostic frame |
|---|---|
| AArch64 | `ESR_EL1`, `ELR_EL1`, `FAR_EL1`, `SPSR_EL1` |
| RISC-V64 | `scause`, `sepc`, `stval`, `sstatus` |

Diagnostic frames explain why the kernel stopped. They are not enough to resume
execution, schedule a thread, handle a syscall, or return to userspace.

Recoverable traps require a full architecture trap frame:

- AArch64: `x0..x30`, interrupted `sp`, `ELR_EL1`, `SPSR_EL1`, `ESR_EL1`,
  `FAR_EL1`
- RISC-V64: integer registers `x1..x31` using ABI names, plus `sepc`,
  `sstatus`, `scause`, `stval`

Architecture assembly owns the raw save/restore order. Architecture Cyna modules
own the named frame shape. Platform code may print diagnostics, but common
kernel code should eventually receive typed trap frames rather than raw CSR or
system-register dumps.

Current implementation status:

- AArch64 and RISC-V64 vectors save full integer trap frames on the active stack.
- The saved frame layout is a C ABI contract between architecture assembly and
  the architecture `trap_frame.cy` module.
- Cyna receives a pointer to the saved frame and derives the current diagnostic
  output from that frame.
- AArch64 vector slots now dispatch synchronous exceptions and IRQs to distinct
  Cyna entrypoints while preserving the same trap-frame layout.
- Opt-in restore probes validate register restore and trap return on both
  targets. Syscall dispatch, page-fault recovery, normal trap-return dispatch,
  and user-mode return are not implemented yet.

Cyna pressure point:

- Cory uses Cyna's `comptime` C ABI metadata operator to publish
  `TrapFrame.size`, `TrapFrame.align`, and `TrapFrame.field.name.offset`
  constants from each architecture trap-frame module.
- Cory uses Cyna's `export asm const` declarations in those same modules to
  emit the `TF_*` constants consumed by architecture assembly. This makes the
  Cyna `cstruct` the source of truth for trap-frame offsets.
- Each architecture `trap_frame.cy` module has a boot-time `verify_layout`
  guard. This catches drift in the Cyna `cstruct` field layout before exception
  vectors are installed.
- RISC-V64 reserves 288 bytes in assembly for trap-stack alignment, while the
  C ABI `TrapFrame` payload is 280 bytes. The final 8 bytes are stack padding,
  not Cyna-visible struct storage.
- Remaining Cyna gap: static assertions are not available yet, so Cory still
  keeps a boot-time `verify_layout` guard for human-readable diagnostics.

Normal boot must never depend on deliberately taking a trap. Diagnostic trap
coverage lives in opt-in QEMU probe images generated by `tools/check.sh` from
the target manifests:

- `tools/check.sh trap-aarch64` builds an AArch64 image that executes `brk`
- `tools/check.sh trap-riscv64` builds a RISC-V64 image that executes `ebreak`

Those images are expected to print the diagnostic frame and then panic.

## Privilege-Mode Decision

Cory should run the kernel in the normal OS privilege level for each
architecture:

- AArch64 kernel mode: EL1
- RISC-V kernel mode: S-mode

Current status:

- AArch64 QEMU direct boot detects the current exception level, keeps EL1
  entry direct, drops EL2 entry to EL1, and asserts that platform exception
  setup runs at EL1.
- RISC-V QEMU direct boot with `-bios none` enters an M-mode shim, grants
  S-mode access to RAM through PMP, delegates common traps/interrupts, and then
  enters the kernel in S-mode before installing the S-mode trap vector.

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
- switches allocation results to the mapped architecture-canonical heap virtual
  range after bootstrap page tables are populated
- grows in virtual mode by allocating physical pages and mapping them into the
  active heap virtual range
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
- module: `kernel.memory.vm`
- page-table geometry module: `kernel.memory.page_table`
- architecture providers: `kernel.arch.aarch64.page_table`,
  `kernel.arch.riscv64.page_table`
- platform activation bridges: `kernel.platform.*.vm_activation`
- address labels: `PhysAddr` and `VirtAddr`
- current implementation: naming, rights, bootstrap mapping requests, and
  architecture page-table geometry, leaf-entry encoding contracts, bootstrap
  page-table storage allocation, platform device MMIO identity mapping, and
  platform-owned identity-map activation

`PhysAddr` and `VirtAddr` are semantic labels over `usize` for now. They make
mapping code readable, but Cyna does not yet enforce them as distinct machine
types. Code that crosses the VM boundary should still use conversion helpers
such as `identity_virtual_for_phys` instead of casual casts.

Page-table geometry is a common contract, but descriptor encodings and control
registers stay architecture-local. Common VM code may depend on:

- page size
- page offset bits
- table level count
- index bits per level
- entries per table
- entry size
- supported virtual and physical address bits

The current providers are:

- AArch64 EL1, 4 KiB granule, 4 levels, 48-bit virtual addresses, 40-bit
  physical addresses for the QEMU `cortex-a53` platform model
- RISC-V64 Sv39, 4 KiB pages, 3 levels, 39-bit virtual addresses

Architecture modules also expose leaf-entry encoders for bootstrap mappings.
These encoders translate common VM rights into architecture descriptor bits and
round-trip the physical page address for selftests:

- AArch64 encodes 4 KiB EL1 level-3 page descriptors.
- RISC-V64 encodes Sv39 leaf PTEs.

VM allocates a contiguous physical range for bootstrap page-table storage from
`phys`. The range is registered back into the canonical memory map as
`bootstrap_page_tables`, then VM mapping requests are rebuilt so the page-table
storage itself is identity-mapped. The current allocation is a deterministic
upper bound: it does not share intermediate tables between mapping requests
yet. That trades memory efficiency for a simple ownership contract while real
multi-level population is still under construction.

VM also zeros the reserved table pages and exposes bounded raw entry
read/write helpers for bootstrap population. Architecture modules encode
non-leaf table descriptors:

- AArch64 encodes next-table descriptors.
- RISC-V64 encodes valid non-leaf PTEs with R/W/X clear.

Architecture modules now populate the zeroed bootstrap table storage from the
VM mapping requests. VM owns the portable walk primitives:

- calculate the table index for each virtual-address level
- allocate child table pages from the reserved table range
- read and write raw entries inside bounded table pages

Architecture modules own descriptor encoding and lookup:

- write non-leaf descriptors when a child table is allocated
- write leaf descriptors for each page in every bootstrap mapping request
- encode platform device MMIO with architecture-appropriate memory attributes
  where the page-table format carries them
- walk the populated tables in selftests to verify representative identity
  translations

This is full bootstrap table population for the current identity-map requests.

Architecture modules publish the register values required by activation:

- AArch64: shared `TTBR0_EL1`/`TTBR1_EL1` root address, `MAIR_EL1`
  normal/device attributes, `TCR_EL1` 4 KiB 48-bit lower/upper VA / 40-bit PA
  translation settings, and `SCTLR_EL1` enable bits.
- RISC-V64: `satp` value for Sv39 with the root page-table physical page
  number.

Platform modules own the final activation bridge because the assembly shim
symbol is target-local. Shared page-table modules must stay pure enough to be
imported by cross-architecture selftests without forcing the other
architecture's assembly symbol into the current link. The platform activation
bridge writes exactly the architecture-published values, runs the
architecture-required barriers/fences, and then keeps executing through the
already-populated identity map.

AArch64 bootstrap leaves default to EL1-only access. The descriptor bit that
allows EL0 access must only be set for future user mappings; setting it on
kernel/MMIO leaves can combine with `SCTLR_EL1.PAN` and fault EL1 data access
after translation is enabled. The activation shim also clears `SCTLR_EL1.WXN`
while the temporary `kernel_image` mapping is RWX. WXN should be restored when
section-level W^X mappings exist.

VM bootstrap mapping requests are generated from the canonical memory map:

- one request per non-`free_ram` region
- identity requests use virtual address equals physical address
- one additional `kernel_heap_virtual` request maps committed heap pages into
  the architecture-canonical high-half heap range
- start and end must be page-aligned
- platform device MMIO is represented as `device_mmio`
- kernel image temporarily maps read/write/execute
- boot allocator, physical page bitmap, pre-VM heap, MMIO, and stack map
  read/write
- bootstrap page-table storage maps read/write
- no bootstrap mapping request may set user access

These requests are now consumed by architecture page-table population code.
They remain the source-of-truth policy data for the bootstrap identity map and
the first kernel heap virtual alias.

The current `kernel_image` memory-map range covers text, rodata, data, bss, and
the bootstrap stack because the linker does not yet publish section-level
boundaries. It is therefore temporarily mapped RWX. This is a deliberate
bootstrap compromise, not the intended final W^X policy; once section-level
regions exist, text should become RX and mutable data/stack should remain RW.

The bootstrap VM plan is intentionally conservative:

- identity-map every memory-map region where `needs_identity_mapping(kind)` is
  true
- keep the kernel image, boot allocator range, physical page bitmap, pre-VM
  heap, MMIO, and stack reachable by their current addresses
- reserve a named architecture-canonical kernel heap virtual range for later
  heap migration
- map committed pre-VM heap pages at the start of that virtual range while
  preserving their identity mapping during bootstrap
- keep physical frame ownership in `phys`; VM consumes frames but does not own
  the free/used policy
- the initial AArch64 kernel virtual range starts at `0xffff800000000000`;
  RISC-V Sv39 uses its own sign-extended upper-half base

Near-term VM goals:

- define physical-address and virtual-address naming conventions: done
- identity-map the kernel image and all non-`free_ram` memory-map regions:
  encoded and activated for the bootstrap map
- establish a kernel virtual range for future heap migration: architecture-canonical and mapped for committed heap pages
- define page-table geometry per architecture: done
- encode architecture leaf entries for bootstrap mapping rights: done
- allocate bootstrap page-table storage from physical memory: done
- zero page-table storage and verify non-leaf descriptor encoding: done
- populate bootstrap identity page tables from VM mapping requests: done
- activate bootstrap identity mappings on both QEMU targets: done
- add page map/unmap operations with explicit rights: done for bootstrap tables
- prepare user/kernel address separation: range and rights contracts done

## Kernel Object and Capability Model

Cory's native authority model is capability-based.

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
The realistic board target remains Raspberry Pi CM5, so abstractions should be
shaped by board facts we can eventually boot: UART, memory map, interrupt
controller, architectural timer, firmware entry contract, and MMIO reachability
after VM activation. QEMU targets are executable pressure tests, not the schema
source for every future board.

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
- AArch64 has an EL2-to-EL1 entry path and asserts EL1 before exception setup.
- RISC-V has an M-mode shim that enters the kernel in S-mode.
- Physical allocation, pre-VM heap, memory-map ownership, and heap diagnostics
  exist.
- Bootstrap VM and address-space metadata exist for both QEMU targets.
- Address-space records use bounded slotmap IDs and have backing kernel object
  identity plus explicit capabilities.
- Address-space mapping policy APIs check capabilities before accepting map
  requests.
- Boot selftests are split into memory, object, and architecture modules behind
  a small `kernel.selftest` facade.
- A bounded kernel slotmap helper defines packed index/generation handles for
  fixed tables without hidden allocation. Current variants cover 8, 16, and
  32 entries.
- Kernel process metadata exists, uses bounded slotmap process IDs, and is
  backed by kernel object identity, process capabilities, and a duplicated
  kernel address-space capability.
- Kernel process capability spaces exist as fixed local tables that point to
  global capabilities. Local slots can be removed, and stale slots whose global
  capability was released are invalidated on lookup. Owner rows decode the
  bounded process handle slot index and validate the owner key generation.
- Kernel thread metadata exists, is created through process-local authority,
  and installs a thread handle into the owning process capability space.
- A fixed scheduler run queue and round-robin scheduler decision primitive exist
  for ready-thread metadata; normal timer-driven context switching is not
  implemented yet.
- Portable thread context metadata exists and stores architecture-owned context
  handles. Architecture context records now carry initial resume-state storage
  for instruction pointer, stack pointer, and status flags; the normal
  timer-driven switching path is not implemented yet.
- Architecture context descriptors are importable by common cross-arch tests
  without pulling in target-specific assembler exports.
- Target-specific trap-frame helpers expose resume-state fields from real
  exception/trap frames and are validated by the opt-in trap probes.
- Portable thread context save updates both common context metadata and the
  architecture-owned resume-state record. Target-specific trap-context wrappers
  can save resume state directly from real trap frames.
- Scheduler has a save-aware handoff primitive that records the outgoing
  running thread's resume state before selecting the next ready thread; actual
  architecture restore/switch assembly is still future work.
- Target-specific trap-context wrappers can drive that save-aware scheduler
  handoff from an architecture trap frame without exposing trap-frame layout to
  common scheduler code.
- Portable resume-state reads expose the selected thread's saved instruction
  pointer, stack pointer, and status flags for the future restore path.
- Target-specific trap-frame writers can copy a selected thread's resume state
  back into an architecture trap frame.
- Target restore-return assembly entry points exist for AArch64 `eret` and
  RISC-V64 `sret`, behind target-local trap-context wrappers. They are validated
  by opt-in probes but are not wired into normal trap handling yet.
- Opt-in restore probes validate the AArch64 `eret` and RISC-V64 `sret` paths by
  resuming after deliberate traps, then panicking intentionally.
- Opt-in scheduler probes validate the first integrated trap scheduling handoff
  on both AArch64 and RISC-V64: save interrupted frame, select a ready kernel
  thread, write selected resume state, restore with `eret` or `sret`, then
  panic intentionally.
- Target-local trap-context modules expose a reusable schedule-and-restore path
  for timer/interrupt handlers; normal trap handlers remain panic-only.
- The reusable trap scheduling path records target-local failure status for
  schedule failure and missing resume state.
- Platform timer groundwork exists for both QEMU targets: AArch64 reads
  `cntfrq_el0`/`cntvct_el0` and programs masked virtual timer deadlines through
  `cntv_tval_el0`/`cntv_ctl_el0`, RISC-V64 grants S-mode `time` access through
  `mcounteren`, and normal boot checks prove the counters are readable.
- RISC-V64 timer delivery is still counter-only. The current `-bios none`
  M-mode shim delegates supervisor interrupts but does not yet provide a
  machine-timer handoff, CLINT programming policy, or SBI-style timer call.
- AArch64 platform interrupt glue centralizes IRQ mask/unmask, GICv2
  acknowledge/EOI, virtual timer IRQ setup, and timer IRQ completion. Normal
  boot exports a panic-only IRQ entrypoint, configures the virtual timer IRQ
  route, and leaves IRQs masked.
- AArch64 tick delivery policy exists as explicit platform state. Normal boot
  initializes delivery disabled; opt-in probes exercise diagnostic delivery and
  scheduler consumption separately.
- An opt-in AArch64 timer IRQ probe configures the QEMU `virt` GICv2 virtual
  timer PPI through that interrupt module, unmasks IRQs, receives INTID 27,
  disarms the timer, and panics intentionally. Normal boot still leaves timer
  IRQs disabled.
- An opt-in AArch64 diagnostic tick probe enables dry-run tick delivery,
  receives INTID 27, completes the timer IRQ, and panics intentionally without
  scheduling.
- An opt-in AArch64 timer scheduling probe configures the virtual timer PPI,
  receives INTID 27, disarms and EOIs the interrupt, schedules a ready kernel
  thread from the saved trap frame, and restores with `eret`. Normal boot still
  leaves timer-driven preemption disabled.
- Current next kernel slice: specify and probe the RISC-V64 timer ownership
  path without forcing it into the AArch64 GIC/tick shape.
- Cyna gaps identified by kernel slotmap work were reproduced and fixed
  upstream: mutable references to module globals work for this path, and
  freestanding aggregate lowering has memory helper support.
- Kernel object IDs and capability IDs use bounded slotmap handles; fixed
  object/capability tables, basic capability rights checks, and capability
  duplication exist.
- Scheduler, userspace, IPC, and shared buffers are not implemented.

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
- basic exception/trap vector with diagnostic state capture
- opt-in deliberate trap probes for both QEMU targets
- boot selftests
- RISC-V M-mode shim enters S-mode before common kernel entry
- AArch64 EL2 entry drops to EL1 before common kernel entry

Still incomplete:

- AArch64 EL3 entry path and fuller EL2 policy
- fuller RISC-V trap/interrupt delegation policy
- normal-handler integration for recoverable kernel traps and future user traps

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
- report `ESR_EL1`, `ELR_EL1`, `FAR_EL1`, and `SPSR_EL1` on unhandled
  exceptions before panic
- document register ownership before common kernel entry

RISC-V deliverables:

- split `_start` into M-mode shim and S-mode kernel entry
- configure trap/interrupt delegation
- configure PMP for kernel RAM access
- enter S-mode with `mret`
- set `stvec` for S-mode traps
- report `scause`, `sepc`, `stval`, and `sstatus` on unhandled traps before
  panic
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
- VM address labels, rights bits, bootstrap plan, and identity mapping requests
- page-table geometry contract for AArch64 and RISC-V64
- page-table leaf-entry encoding contract for AArch64 and RISC-V64
- bootstrap page-table storage allocation and memory-map ownership
- page-table zeroing and non-leaf descriptor contract
- bootstrap identity page-table population and lookup selftests
- platform device MMIO identity mapping contract
- architecture MMU activation register-value contract
- bootstrap page map/unmap operations with explicit rights
- heap diagnostics
- AArch64/RISC-V boot checks

Next:

- grow VM support from bootstrap tables into per-address-space page-table
  ownership
- connect kernel object identity to address-space and future process/thread
  handles

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
- kernel address-space bootstrap: fixed-table metadata with backing kernel
  object identity, explicit capabilities, and capability-authorized map checks
- user address-space policy fixture: selftest-only, unrooted metadata for
  validating future user mapping boundaries

### Phase 4.5 — Kernel Collections

Goal:

```text
Factor repeated bounded-table patterns without adding hidden allocation.
```

Deliverables:

- bounded slotmap key vocabulary: fixed 8-entry, 16-entry, and 32-entry
  index/generation handles done
- local collection selftests for key packing: done
- arch context descriptor tables use slotmap key rules: done
- address-space metadata uses fixed 8-entry slotmap key rules: done
- portable thread context metadata uses slotmap liveness and count rules: done
- process metadata uses fixed 8-entry slotmap key rules: done
- object metadata uses fixed 32-entry slotmap key rules: done
- capability metadata uses fixed 32-entry slotmap key rules: done
- direct bounded-table helper usable with module-global storage: done

### Phase 5 — Kernel Objects and Capabilities

Goal:

```text
Represent object identity, lifetime, and authority.
```

Deliverables:

- kernel object IDs: fixed 32-entry slotmap keys done
- object table: initial fixed table with slotmap liveness done
- capability IDs: fixed 32-entry slotmap keys done
- capability table: initial fixed table with slotmap liveness done
- rights checks: initial checks done
- capability duplication: initial narrowing duplicate done
- capability transfer draft
- object lifetime/refcount model: initial retain/release done
- address-space object identity: done
- address-space capabilities: done
- capability-authorized address-space map checks: done
- kernel process object identity and root capability: done
- process-local capability table: fixed table, slot removal, stale-handle
  invalidation, and owner-key generation validation done
- process teardown: clears owner capability rows and releases process-owned
  capabilities plus backing object done
- thread root handle in owning process capability table: done
- revocation draft

### Phase 6 — Threads, Timers, and Scheduler

Goal:

```text
Run multiple execution contexts.
```

Deliverables:

- kernel process metadata: initial fixed table with slotmap process IDs done
- thread object: initial metadata-only table done
- portable thread context metadata: initial table done
- architecture-owned context storage: initial fixed tables and resume-state
  fields done
- scheduler run queue: initial fixed queue done
- scheduler decision primitive: round-robin metadata transition done
- scheduler save-aware handoff primitive: done
- opt-in trap-frame restore probes: done for AArch64 and RISC-V64
- opt-in trap-driven scheduler handoff probes: done for AArch64 and RISC-V64
- timer interrupt: AArch64 diagnostic delivery and opt-in scheduler handoff done
- context switch: diagnostic trap-frame restore exists; normal scheduling path
  not done
- scheduler loop
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
Demonstrate Cory's product direction without real camera hardware.
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

64-bit Arm architecture. Cory's primary product architecture because Raspberry
Pi CM5 is Arm-based.

### RISC-V64

64-bit RISC-V architecture. Cory's research architecture for portability and
Cyna backend validation.

### Cyna

The systems programming language in the Neucine ecosystem. Cory is intended to
be written primarily in Cyna.

### C ABI Carrier Type

A type that Cyna permits directly at an `extern c` or `export c` boundary, such
as `c_int`, `c_ulong`, `c_size_t`, `cstr`, raw pointers, and C-layout structs.
Kernel-native types such as `usize` should stay inside Cory's Cyna modules
unless Cyna explicitly makes them C ABI boundary types.

### Cory

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
