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

## 2. Mission

### 2.1 Language demonstration mission

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

### 2.2 Imaging hardware mission

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

## 3. Non-goals

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

## 4. Design principles

### 4.1 Kernel as substrate

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

### 4.2 Small privileged core

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

### 4.3 Capability-first security

Every protected object should be accessed through a capability.

A process should not acquire authority through ambient global names by default. Authority should be explicit, transferable, inspectable, and revocable where possible.

### 4.4 Async-first IPC

Blocking APIs are not the native model. Cycor should use channels, events, wait sets, timers, and shared buffers as its primary service communication model.

Blocking APIs can be wrappers over async primitives.

### 4.5 Userspace drivers by default

Drivers should run in isolated userspace driver hosts where practical.

The kernel should provide:

- device capabilities
- controlled MMIO mapping
- interrupt delivery as events
- DMA buffer management
- device fault reporting
- capability revocation
- driver restart support

### 4.6 Observability from day one

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

## 5. Core kernel object model

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

## 6. Capability model

A capability grants typed rights over a kernel object.

Conceptual shape:

```text
Capability<ObjectType, Rights>
```

Example rights:

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

Example capabilities:

```text
Capability<Process, Signal | Inspect>
Capability<Thread, Manage>
Capability<MemoryRegion, Map | Read | Write>
Capability<Channel, Send>
Capability<Device, Configure>
Capability<SharedBuffer, Read | Write | Map>
```

Rules:

- no protected object access without a capability
- rights are checked by the kernel
- capabilities may be transferred through IPC when allowed
- capabilities may be duplicated only when allowed
- capabilities may be revoked when revocation authority exists
- native Cyna APIs should expose capability rights ergonomically where possible

## 7. IPC model

IPC should be message-based and capability-aware.

Core IPC concepts:

- `Channel`
- `Message`
- capability transfer
- shared buffer attachment
- event notification
- `WaitSet`

A message may contain:

- small inline payload
- references to shared buffers
- transferred capabilities
- event or fence handles

Large payloads should not be copied through IPC. They should use `SharedBuffer`.

Example:

```text
Capture Service -> ISP Service:
    message: ProcessFrame
    buffer: Capability<SharedBuffer, Read | Write>
    fence: Capability<Event, Signal>
```

## 8. SharedBuffer model

`SharedBuffer` is a first-class kernel object because imaging workloads require high-throughput zero-copy movement.

The kernel should support:

- buffer allocation
- mapping into address spaces
- rights-restricted access
- DMA suitability flags
- cache coherency controls
- physical contiguity constraints when needed
- producer/consumer ownership
- lifetime tracking
- event/fence synchronization
- resource accounting

Future camera flow:

```text
Sensor DMA
    -> RAW SharedBuffer
    -> ISP Service
    -> Preview SharedBuffer
    -> Display Service

Sensor DMA
    -> RAW SharedBuffer
    -> Encoder / Writer Service
    -> Storage Service
```

The kernel should not understand RAW, JPEG, DNG, demosaic, or color science. It should only provide safe, efficient buffer ownership and transfer.

## 9. Scheduler model

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

## 10. Device and driver model

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

## 11. Platform strategy

Cycor has two hardware tracks.

### Product track: AArch64 / Raspberry Pi CM5

This is the main product direction.

Target:

- Raspberry Pi Compute Module 5
- camera/imaging carrier board
- later custom camera hardware

Bring-up order:

1. AArch64 QEMU `virt`
2. Raspberry Pi CM5 serial boot
3. CM5 timer/interrupt/memory stability
4. CM5 storage/display/input
5. CM5 camera-oriented services
6. CM5 camera pipeline prototype

Do not make the first milestone depend on MIPI CSI or ISP control.

### Research track: RISC-V64 / SiFive HiFive Unmatched

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

### Optional later target

x86_64 may be added later for portability, but it is not a first target.

## 12. MVP

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

## 13. Success criteria

Cycor is successful at the first milestone if:

- it boots in QEMU
- it is mostly written in Cyna
- it runs at least one userspace service
- capabilities restrict service authority
- IPC can transfer capabilities
- `SharedBuffer` can move frame-like data without copying
- fake imaging services can form a pipeline
- trace output can explain frame latency
- the design gives useful feedback to Cyna

## 14. Hard constraints

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
