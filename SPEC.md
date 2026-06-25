# Cycor Specification

Status: draft  
Project: Cycor  
Pronunciation: Sai-core  
Repository: neucine/cycor

## 1. Definition

Cycor is a Cyna-native capability kernel substrate.

Its immediate purpose is to demonstrate that Cyna can implement serious low-level systems software safely and ergonomically.

Its long-term purpose is to become the operating substrate for Raspberry Pi Compute Module 5 based camera and imaging hardware.

Cycor should be understood as a kernel substrate, not a general-purpose operating system. Product behavior should be built above the kernel through userspace services and OS personalities.

## 2. Project identity

```text
Neucine  — ecosystem / organization
Cyna     — systems programming language
Cycor    — Cyna-native kernel substrate
```

Cycor is pronounced **Sai-core**.

## 3. Mission

### 3.1 Language demonstration mission

Cycor should demonstrate Cyna in domains that stress a systems language:

- freestanding code generation
- explicit memory layout
- alignment and ABI control
- physical memory management
- virtual memory management
- exception/trap handling
- interrupt routing
- thread context switching
- safe wrappers around unsafe hardware access
- deterministic allocation
- object lifetime management
- capability ownership
- async IPC
- zero-copy buffer transfer
- userspace service orchestration

The kernel should act as a design pressure test for Cyna. If implementing Cycor reveals friction in Cyna's ownership model, allocator model, unsafe boundary model, async model, or FFI model, that feedback should be treated as valuable language-design input.

### 3.2 Imaging hardware mission

Cycor should grow toward a camera/imaging operating substrate.

The future system should support:

- sensor service
- ISP service
- capture service
- preview service
- storage writer
- display service
- input service
- power and thermal service
- diagnostics service

The kernel should enable these services through isolation, scheduling primitives, IPC, events, shared buffers, device capabilities, and observability.

The kernel should not embed camera policy directly.

## 4. Non-goals

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

Compatibility layers may exist later, but the native architecture is capability-based, typed, async-oriented, and service-oriented.

## 5. Design principles

### 5.1 Kernel as substrate

The kernel should provide irreducible machine mechanisms:

- isolate execution
- map memory
- schedule execution
- check capabilities
- send messages
- deliver events
- route interrupts
- control device access
- account resources
- expose trace data

Everything else should be policy above the kernel.

### 5.2 Small privileged core

The privileged core should contain only mechanisms that require privileged execution:

- physical memory manager
- virtual memory manager
- address spaces
- threads/tasks
- scheduler primitives
- IPC
- capability tables
- kernel object lifecycle
- timers
- exception/trap handling
- interrupt dispatch
- device/MMIO/IOMMU control
- resource accounting hooks
- trace hooks

The following should be outside the core:

- filesystem policy
- network stack policy
- display server
- camera application
- sensor pipeline policy
- ISP policy
- storage format policy
- power policy
- user/session model
- POSIX compatibility

### 5.3 Capability-first security

Every protected object should be accessed through a capability.

A process should not acquire authority through ambient global names by default. Authority should be explicit, transferable, inspectable, and revocable where possible.

### 5.4 Async-first IPC

Blocking APIs are not the native model. Cycor should use channels, events, wait sets, timers, and shared buffers as its primary service communication model.

Blocking APIs can be wrappers over async primitives.

### 5.5 Userspace drivers by default

Drivers should run in isolated userspace driver hosts where practical.

The kernel should provide:

- device capabilities
- controlled MMIO mapping
- interrupt delivery as events
- DMA buffer management
- device fault reporting
- capability revocation
- driver restart support

### 5.6 Observability from day one

Cycor must be diagnosable.

The system should answer:

- who created this object?
- who owns this capability?
- which process consumed CPU?
- which service held this buffer?
- why did this event wake?
- which IPC path introduced latency?
- which driver caused an interrupt storm?
- why did a frame miss its deadline?

This is essential for future camera work.

## 6. Architecture

### 6.1 Layer model

```text
Applications / Product Services
    ├── Camera App
    ├── Gallery App
    ├── Settings App
    └── Diagnostics App

Imaging Services
    ├── Capture Service
    ├── Sensor Service
    ├── ISP Service
    ├── Preview Service
    ├── Storage Writer
    └── Display Service

General System Services
    ├── Init / Service Manager
    ├── Driver Manager
    ├── Filesystem Service
    ├── Log / Trace Service
    ├── Resource Manager
    └── Security Policy Service

Cycor Kernel Core
    ├── Kernel Objects
    ├── Capabilities
    ├── Address Spaces
    ├── Threads / Tasks
    ├── Scheduler
    ├── IPC
    ├── Shared Memory
    ├── Events / Wait Sets
    ├── Timers
    ├── Interrupt Routing
    ├── Device Isolation
    └── Resource Accounting

Hardware
```

### 6.2 Kernel/service split

The kernel owns machine mechanisms.

Userspace services own policy.

| Area | Kernel mechanism | Userspace policy |
|---|---|---|
| Memory | pages, mappings, address spaces | allocator strategies, buffer pools |
| Scheduling | priorities, timers, wakeups, accounting | capture priority, UI boost, background limits |
| Storage | block device access, DMA buffers | filesystem format, file layout, write policy |
| Camera | device access, interrupts, buffers | exposure, frame routing, ISP graph, preview policy |
| Security | capabilities and rights checks | service policy, app permission grants |
| Observability | trace hooks and object metadata | trace UI, diagnostics, frame reports |

### 6.3 Architecture/platform split

`arch` is CPU architecture.

`platform` is board, SoC, or virtual machine.

Suggested layout:

```text
kernel/
  arch/
    aarch64/
    riscv64/

  platform/
    qemu_aarch64_virt/
    raspberrypi_cm5/
    qemu_riscv64_virt/
    sifive_unmatched/
```

Do not put Raspberry Pi specific code under `arch/aarch64`.

Do not put SiFive specific code under `arch/riscv64`.

### 6.4 Native programming model

The native Cycor programming model should be:

```text
capability authority
    +
typed kernel objects
    +
async IPC
    +
shared buffers
    +
event/waitset completion
```

The programming model should avoid path-based ambient authority as the native default.

## 7. Core kernel object model

Initial kernel objects:

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

Possible later objects:

- `DmaBuffer`
- `IoQueue`
- `Fence`
- `CpuSet`
- `ResourceBudget`
- `TraceStream`

Camera-specific abstractions should initially live in userspace and be built from generic kernel objects.

Example:

- `FrameBuffer = SharedBuffer + userspace metadata`
- `SensorStream = Device capability + Interrupt event + Channel`
- `IspQueue = Device capability + SharedBuffer + Fence`
- `PreviewFrame = SharedBuffer + Display service protocol`

## 8. Capability model

Capabilities are Cycor's native authority model.

A capability answers:

```text
Which object?
Which rights?
Can this authority be delegated?
Can it be duplicated?
Can it be revoked?
```

Conceptual form:

```text
Capability<ObjectType, Rights>
```

This is a conceptual model. The low-level ABI may represent capabilities as handles, but the native Cyna API should expose typed capability concepts where possible.

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

Examples:

```text
Capability<Channel, Send>
Capability<Channel, Receive>
Capability<SharedBuffer, Read | Map>
Capability<SharedBuffer, Read | Write | Map>
Capability<Device, Configure>
Capability<Process, Inspect | Signal>
Capability<Thread, Manage>
```

Rules:

- A process cannot access a protected object without a capability.
- Rights are checked in the kernel.
- Capabilities may be transferred through IPC if allowed.
- Capabilities may be duplicated if allowed.
- Capabilities may be revoked if revocation authority exists.
- Capability tables are per-process or per-protection-domain.
- Kernel-created root capabilities are distributed by the initial system service.
- Native Cyna APIs should expose capability rights ergonomically where possible.

Camera-oriented services can receive narrow authority:

```text
Sensor Service:
    Device<Sensor>, Interrupt, SharedBuffer allocator

ISP Service:
    Device<ISP>, SharedBuffer read/write, Event signal

Preview Service:
    Display surface, SharedBuffer read

Storage Writer:
    Storage service write, SharedBuffer read

Camera App:
    Capture service command channel
```

No service needs global system authority.

## 9. IPC model

Cycor IPC enables isolated services to cooperate.

The IPC model should support:

- message passing
- capability transfer
- shared buffer references
- async waiting
- event notification
- service restart boundaries

Core objects:

- `Channel`
- `Message`
- `Event`
- `WaitSet`
- `SharedBuffer`

A message may contain:

- small inline payload
- transferred capabilities
- references to shared buffers
- event/fence handles
- protocol-specific metadata

Large data should not be copied through IPC. IPC is the main way to delegate authority.

Example:

```text
ServiceManager -> FakeSensor:
    Capability<Device, Configure>
    Capability<Channel, Send>
    Capability<SharedBufferAllocator, Manage>
```

A wait set allows a service to wait on multiple sources:

- channel message
- event signal
- timer expiry
- interrupt event
- process exit
- buffer fence

Example service loop:

```text
loop:
    event = waitset.next()
    handle(event)
```

Imaging example:

```text
FakeSensor -> FakeISP:
    message: FrameReady
    buffer: Capability<SharedBuffer, Read | Write>
    done: Capability<Event, Signal>

FakeISP -> Preview:
    message: PreviewFrame
    buffer: Capability<SharedBuffer, Read>

FakeISP -> StorageWriter:
    message: StoreFrame
    buffer: Capability<SharedBuffer, Read>
```

## 10. SharedBuffer model

`SharedBuffer` is a first-class Cycor kernel object for moving large data across isolated services without copying.

This is essential for imaging workloads, where frame buffers may be tens or hundreds of megabytes.

The kernel should support:

- allocation
- mapping into address spaces
- rights-restricted access
- explicit ownership or producer/consumer state
- lifetime tracking
- resource accounting
- event/fence synchronization
- DMA-related flags later
- cache coherency controls later
- physical contiguity constraints later

Conceptual operations:

```text
create(size, flags) -> Capability<SharedBuffer, Manage | Map | Read | Write>
map(buffer, address_space, rights) -> Mapping
unmap(mapping)
duplicate(buffer, reduced_rights)
transfer(buffer, target_process)
signal_ready(buffer, event)
```

Possible rights:

- `Read`
- `Write`
- `Map`
- `Transfer`
- `Manage`

Imaging flow:

```text
FakeSensor:
    create SharedBuffer
    fill frame-like data
    send buffer to FakeISP

FakeISP:
    receive buffer
    process buffer
    send derived buffers to Preview and StorageWriter

Preview:
    read preview buffer

StorageWriter:
    read storage buffer
    write to storage service
```

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

## 11. Scheduler model

The initial scheduler should be simple.

Initial target:

- round-robin or simple priority scheduler
- sleep/wakeup
- timer support
- thread states
- basic preemption

Future camera-oriented scheduling classes may include:

- `capture-critical`
- `preview-realtime`
- `ui-interactive`
- `storage-throughput`
- `background`
- `maintenance`

Likely priority intent:

```text
capture-critical > preview-realtime > ui-interactive > storage-throughput > background
```

Policy should remain outside the kernel where possible. The kernel should expose mechanisms:

- priority
- deadline hints
- CPU affinity
- wake events
- budget accounting
- preemption controls
- resource usage measurement

## 12. Device and driver model

Driver hosts should run in userspace.

Driver host responsibilities:

- own a device capability
- map MMIO only through kernel-approved mapping
- receive interrupts as events
- allocate/map DMA buffers
- communicate with clients through channels
- restart after failure where possible

Kernel responsibilities:

- validate device access
- control MMIO mapping
- route interrupts
- enforce IOMMU/device isolation where available
- track device ownership
- revoke device capabilities
- report device faults

Initial QEMU device targets:

- UART
- generic timer
- interrupt controller
- virtio-console
- virtio-block
- virtio-net later
- framebuffer later

## 13. Platform strategy

Cycor has two first-class hardware tracks:

```text
Product track:  AArch64 / Raspberry Pi Compute Module 5
Research track: RISC-V64 / SiFive HiFive Unmatched
```

Initial development starts in QEMU for fast iteration.

### 13.1 Product track: AArch64 / Raspberry Pi CM5

This is the main product path.

Reasons:

- future camera hardware is CM5-based
- AArch64 aligns with the embedded/imaging product direction
- CM5 supports practical camera/display carrier-board experimentation
- CM5 can lead toward custom camera hardware later

Initial CM5 goals:

- serial boot
- early logging
- exception handling
- timer
- interrupt controller
- memory management
- simple device access
- storage/display/input later

Non-initial CM5 goals:

- MIPI CSI control
- ISP control
- full camera stack
- production storage pipeline
- production display pipeline

These should wait until the kernel substrate is stable.

Bring-up order:

1. AArch64 QEMU `virt`
2. Raspberry Pi CM5 serial boot
3. CM5 timer/interrupt/memory stability
4. CM5 storage/display/input
5. CM5 camera-oriented services
6. CM5 camera pipeline prototype

Do not make the first milestone depend on MIPI CSI or ISP control.

### 13.2 Research track: RISC-V64 / SiFive HiFive Unmatched

This validates architecture independence and Cyna's RISC-V backend.

Target:

- RISC-V64 QEMU `virt`
- SiFive HiFive Unmatched board

Purpose:

- test arch/platform separation
- validate Cyna freestanding RISC-V code generation
- validate trap handling
- validate atomics and memory model
- avoid baking ARM-only assumptions into Cycor

Initial RISC-V goals:

- QEMU `virt` boot
- serial logging
- trap handling
- timer
- interrupt controller
- physical/virtual memory
- basic scheduler

Later goals:

- SiFive HiFive Unmatched serial boot
- board-specific interrupt/device support
- storage/network experiments

### 13.3 Target matrix

| Tier | Target | Purpose |
|---|---|---|
| 0 | AArch64 QEMU `virt` | primary bring-up |
| 0 | RISC-V64 QEMU `virt` | architecture validation |
| 1 | Raspberry Pi CM5 | product board bring-up |
| 1 | SiFive HiFive Unmatched | research board bring-up |
| 2 | CM5 camera carrier | imaging prototype |
| 3 | custom camera hardware | future product direction |

### 13.4 Optional later target

x86_64 may be added later for portability, but it is not a first target.

## 14. Imaging direction

Cycor's first product direction is camera and imaging hardware based on Raspberry Pi CM5.

The kernel should not become a camera application. It should provide the substrate for an imaging OS.

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

Supporting services:

- Power Service
- Thermal Service
- Input Service
- Settings Service
- Gallery Service
- Diagnostics Service
- Trace Service

The first meaningful demo should simulate the camera pipeline before real camera hardware is controlled.

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
- zero large IPC copies
- dropped-frame accounting

Future real hardware path:

1. CM5 serial boot
2. timer and interrupt stability
3. memory stability
4. storage path
5. display path
6. input path
7. simulated capture path on real board
8. sensor/CSI research
9. ISP research
10. real camera pipeline

The imaging stack must be able to answer:

- where did frame latency occur?
- which service held the buffer?
- did storage block the pipeline?
- did preview miss a deadline?
- did thermal policy affect capture?
- did a driver or interrupt storm cause jitter?
- how many copies occurred?
- how many frames were dropped?

## 15. MVP

The MVP is not a shell.

The MVP is a fake camera pipeline running across isolated userspace services:

```text
FakeSensor -> FakeISP -> Preview -> StorageWriter
```

MVP components:

- bootable AArch64 QEMU kernel
- early logging
- physical memory manager
- virtual memory manager
- basic scheduler
- syscall entry
- process/thread objects
- capability table
- channel IPC
- shared buffer object
- event/waitset
- userspace init
- service manager
- fake sensor service
- fake ISP service
- fake preview service
- fake storage writer
- trace/log service

Example output:

```text
[frame 1024] sensor produced buffer=84 size=48MB
[frame 1024] isp completed in 4.2ms
[frame 1024] preview displayed
[frame 1024] storage write completed in 7.6ms
[frame 1024] end-to-end latency 13.1ms
[frame 1024] copies=0 dropped=0
```

MVP success criteria:

- kernel boots in QEMU
- userspace init runs
- services run in isolated processes
- capabilities restrict access between services
- IPC transfers capabilities
- `SharedBuffer` moves frame-like data without copies
- fake camera pipeline emits latency traces
- the system shows why a frame was delayed, dropped, or completed

## 16. Roadmap

### Phase 0 — Repository and specification

Goal:

```text
Define the project before writing too much kernel code.
```

Deliverables:

- `README.md`
- `SPEC.md`

### Phase 1 — AArch64 QEMU boot

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

### Phase 2 — RISC-V64 QEMU boot

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

### Phase 3 — Memory foundation

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

### Phase 4 — Kernel objects and capabilities

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

### Phase 5 — Threads and scheduler

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

### Phase 6 — Userspace and syscalls

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

### Phase 7 — IPC and events

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

### Phase 8 — SharedBuffer

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

### Phase 9 — Service manager

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

### Phase 10 — Userspace driver host

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

### Phase 11 — Fake camera pipeline

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

Success:

- frame-like buffers use `SharedBuffer`
- no large IPC copies
- services are isolated
- capabilities restrict authority
- trace output reports latency and ownership

## 17. Hard constraints

- native API is capability-based
- native API is async/event-oriented
- no ioctl-style untyped escape hatch
- drivers are userspace by default
- kernel object access always checks rights
- `SharedBuffer` is first-class
- observability is not optional
- POSIX is optional and not foundational
- camera use cases influence the core but do not pollute it
- Cyna ergonomics are part of the success criteria

## 18. Glossary

### AArch64

64-bit Arm architecture. Cycor's primary product architecture because Raspberry Pi CM5 is Arm-based.

### Cyna

The systems programming language in the Neucine ecosystem. Cycor is intended to be written primarily in Cyna.

### Cycor

Pronounced Sai-core. A Cyna-native capability kernel substrate for language demonstration and future camera/imaging hardware.

### Capability

A transferable authority object that grants rights over a kernel object.

### Channel

A message-based IPC object.

### Event

A kernel object that can be signaled and waited on.

### WaitSet

An object allowing a task or service to wait on multiple events, channels, timers, or completions.

### SharedBuffer

A first-class kernel object for zero-copy sharing of large buffers between isolated services.

### Product track

The AArch64 / Raspberry Pi CM5 path intended for future camera and imaging hardware.

### Research track

The RISC-V64 / SiFive HiFive Unmatched path intended for architecture validation and kernel experimentation.

### Service

A userspace component that implements policy or device behavior above the kernel substrate.

### Kernel substrate

The minimal privileged layer that provides machine mechanisms but avoids embedding product policy.
