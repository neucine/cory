# Cycor Architecture

## 1. Layer model

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

## 2. Kernel/service split

The kernel owns machine mechanisms.

Userspace services own policy.

Examples:

| Area | Kernel mechanism | Userspace policy |
|---|---|---|
| Memory | pages, mappings, address spaces | allocator strategies, buffer pools |
| Scheduling | priorities, timers, wakeups, accounting | capture priority, UI boost, background limits |
| Storage | block device access, DMA buffers | filesystem format, file layout, write policy |
| Camera | device access, interrupts, buffers | exposure, frame routing, ISP graph, preview policy |
| Security | capabilities and rights checks | service policy, app permission grants |
| Observability | trace hooks and object metadata | trace UI, diagnostics, frame reports |

## 3. Architecture/platform split

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

## 4. First-class kernel concepts

- object
- capability
- address space
- process
- thread
- memory region
- shared buffer
- channel
- event
- wait set
- timer
- interrupt
- device
- trace record

## 5. Native programming model

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
