# Cory Architecture

Pronunciation: Core-ry

This document is the short reader path for the current codebase. The longer
design record remains in `docs/SPEC.md`.

## Layer Map

```text
platform/<board>/main.cy
    owns board entry glue, UART setup, platform memory layout, timer/GIC glue,
    and MMU register activation

arch/<cpu>/
    owns privilege-mode normalization, traps/exceptions, page-table encoding,
    CPU registers, IRQ masking, timer register access, and architecture context
    storage descriptors

bootstrap.cy
    owns common kernel bring-up order after platform logging is alive

memory/
    owns boot allocation, physical frames, heap policy, memory maps, VM plans,
    page-table vocabulary, and capability-authorized address-space metadata

collections/
    owns bounded freestanding helpers for repeated kernel table patterns

object/
    owns kernel object identity, object lifetime, and capability authority

task/
    owns process/thread identity, execution-container metadata, and
    process-local capability spaces, and metadata-only scheduling decisions

selftest.cy
    thin facade for boot-time contract checks

memory/selftest.cy, object/selftest.cy, task/selftest.cy, arch/selftest.cy
    own subsystem checks that keep both QEMU targets honest
```

## Naming Rules

- `bootstrap.cy` is common kernel bring-up orchestration.
- `memory/boot.cy` is only the early boot allocator.
- `arch/*` must not contain QEMU board constants.
- `platform/*` may depend on one architecture, but common kernel code should
  not depend on a concrete platform module.
- `platform/*/main.cy` is the current composition point. It may import concrete
  platform modules, concrete architecture modules, and common kernel modules in
  order to wire one boot image together.
- Common kernel modules should receive platform and architecture facts as plain
  values or narrow calls. Do not add a common abstraction layer until two target
  paths need the same boundary and the local call sites show the shape.
- Cyna-to-Cyna calls should use normal imports. `extern c` and `export c` are
  only for ABI crossings with assembly, linker-provided symbols, runtime
  callbacks, or intentionally exported probe entrypoints.
- `object/*` is authority infrastructure. Concrete resources such as address
  spaces, processes, channels, events, and shared buffers should connect to it
  instead of each inventing separate lifetime or rights rules. Kernel object
  and capability IDs are bounded slotmap keys.
- `collections/slot_map.cy` owns the bounded slotmap handle vocabulary used by
  fixed kernel tables. Current users keep payload arrays local and share the
  packed index/generation key rules.
- `memory/address_space.cy` uses bounded slotmap keys for address-space IDs,
  while object and capability IDs record the authority backing each address
  space.
- `task/capability_space.cy` is a process-local handle table over global
  capabilities. Removing a local slot does not release the global capability;
  released global capabilities are treated as stale local handles and cleared
  on lookup. Owner rows are selected by decoding the bounded process key's
  slot index and validating the exact owner key generation, not by treating
  process IDs as dense integers.
- `task/process.cy` uses bounded slotmap keys for process IDs. The first
  process key still maps cleanly onto capability-space owner index 0. Process
  descriptors store both their global capability IDs and process-local
  capability slots. Active processes cannot be released; inactive process
  teardown clears the owner row, releases the process root capability, releases
  the duplicated address-space capability, and releases the backing object.
- `task/thread.cy` installs each thread's root capability into its owning
  process capability space. Thread IDs are bounded slotmap keys, so thread
  liveness, lookup, and public handles share one vocabulary.
- `task/context.cy` stores common thread-context descriptors behind bounded
  slotmap keys. The descriptor records its own context key plus the
  architecture-specific context key owned by `arch/*/context.cy`. Thread
  lookups use the decoded thread slot index and then validate the exact thread
  key generation before returning a context.
- `kernel/selftest.cy` should stay a small facade. Put new checks beside the
  subsystem they exercise.
- Architecture descriptor modules that are imported by common cross-arch tests
  must not export assembler symbols; keep asm ABI exports in target-specific
  modules.
- Architecture context modules own fixed descriptor tables for saved-register
  storage. Common task context code stores only the arch id and descriptor
  handle.
- Cyna gaps found while exercising slotmaps were reproduced and fixed
  upstream; this kernel now uses module-global bounded slotmaps on both QEMU
  targets.

## Current Boot Flow

```text
arch start assembly
    -> normalize privilege mode
    -> platform main.cy
        -> zero BSS
        -> initialize UART console
        -> initialize trap/exception vectors
        -> verify platform timer counter/deadline support
        -> bootstrap.prepare_memory(...)
            -> initialize boot allocator
            -> initialize physical pages
            -> initialize pre-VM heap
            -> build memory map
            -> build VM mapping requests
            -> allocate and populate bootstrap page tables
            -> create kernel address-space metadata
            -> create kernel process metadata
            -> create kernel thread metadata
            -> allocate architecture context metadata
            -> attach kernel thread context metadata
            -> initialize scheduler current-thread metadata and policy state
            -> run object/capability selftests
            -> enable virtual heap addressing
        -> platform VM activation
        -> target-local scheduler/timer finish work
```

Platform code performs the final MMU register switch because the activation
symbols and registers are architecture-specific. Common bootstrap code prepares
the architecture-neutral plan and verifies it through selftests.

The only real address space created during bootstrap is the kernel address
space. User-shaped address spaces currently appear only as unrooted policy
fixtures in selftests; real userspace address spaces arrive with process and
loader work.

## ABI Boundaries

Most kernel calls are ordinary Cyna module calls. The C ABI is deliberately
small and should stay visible at the edge where a Cyna function name must match
an assembler, linker, or runtime symbol.

Current ABI groups:

- Linker symbols: `__bss_start`, `__bss_end`, and `__kernel_end` are imported by
  common early boot code because the linker script owns those addresses.
- Entry symbols: architecture start assembly calls exported platform
  `cory_kernel_entry` functions. Test images also export their own
  `cory_kernel_entry`.
- Platform console hook: common `kernel/console.cy` imports
  `cory_console_putc`, while each platform exports it and maps it to its UART.
  This is the one current platform hook used directly by common code.
- Heap mapping hook: common heap code imports `cory_heap_map_virtual_page`.
  Each platform main exports it because the mapping needs the linked page-table
  implementation and the target TLB flush symbol.
- Trap and restore symbols: architecture assembly saves target trap frames and
  calls exported Cyna trap entrypoints. Cyna trap context code calls
  architecture restore assembly when resuming a frame.
- CPU register helpers: platform timer, interrupt, exception, and VM activation
  modules import small architecture assembly helpers for registers that Cyna
  should not encode directly.
- Probe-only symbols: scheduler and trap tests export or import extra ABI
  entrypoints such as deliberate trap triggers, probe thread entries, and stack
  helpers. These should not set the production boundary.

When a new boundary is needed, prefer this order:

1. Use a normal Cyna import if both sides are Cyna and target-local.
2. Pass data into common code if the common code only needs facts such as memory
   layout, page-table spec, or architecture id.
3. Add a tiny common contract only after repeated targets need the same shape.
4. Use `extern c`/`export c` only when symbol linkage or the target ABI is the
   actual contract.

## Current Progress

The implementation is through the first recoverable-trap and timer-interrupt
proofs, plus normal scheduler-tick resume paths on both QEMU targets:

- Both QEMU targets boot, initialize vectors, activate bootstrap identity
  mappings, and run memory/object/task/arch selftests.
- Trap-frame layout is owned by target `cstruct` definitions and verified at
  boot before vectors are installed.
- AArch64 vector slots dispatch synchronous exceptions and IRQs to distinct
  Cyna entrypoints while preserving the same saved trap-frame layout.
- AArch64 and RISC-V64 opt-in restore probes resume from deliberate traps using
  `eret` and `sret`.
- AArch64 and RISC-V64 opt-in scheduler probes save an interrupted trap frame,
  select a ready thread, write selected resume state, and restore into that
  thread.
- AArch64 normal boot proves readable counters and masked virtual timer
  deadline programming, then configures the virtual timer IRQ route and enables
  periodic scheduler tick mode. RISC-V64 normal boot proves S-mode `time`
  readability, configures the Cory-owned M-mode timer shim, and enables
  supervisor timer delivery. Both targets queue a normal kernel worker, resume
  it from a timer-driven scheduler tick after memory-ready, let that worker
  voluntarily yield through a synchronous trap, resume it again, and then block
  it through a second trap that immediately schedules another runnable thread.
- The AArch64 platform interrupt module owns IRQ mask/unmask, GICv2
  acknowledge/EOI, and virtual timer IRQ completion helpers.
- The AArch64 tick policy module owns timer tick delivery state. Normal boot
  enables scheduler delivery; an empty run queue can still record an idle
  scheduler tick and restore the interrupted frame without switching.
- Normal AArch64 boot exports an explicit IRQ entrypoint that handles diagnostic
  timer ticks, can hand enabled scheduler ticks to the target-local
  schedule-and-restore path, and remains panic-only for unexpected IRQs.
- The AArch64 timer IRQ probe configures QEMU `virt` GICv2 through the
  interrupt module, receives virtual timer INTID 27, disarms the timer, and EOIs
  the interrupt.
- The RISC-V64 timer IRQ probe keeps machine timer ownership in the Cory M-mode
  shim. The shim programs QEMU `virt` CLINT `mtimecmp`, converts MTIP into a
  delegated supervisor timer interrupt, and lets the S-mode trap path complete
  it.
- The AArch64 diagnostic tick probe enables dry-run tick delivery, receives
  INTID 27, completes the timer IRQ, and does not schedule.
- AArch64 and RISC-V64 timer scheduling probes receive a target timer interrupt,
  complete it, then use the target-local schedule-and-restore path to resume a
  ready thread.
- The AArch64 normal IRQ scheduler probe routes the same scheduler tick through
  the normal platform IRQ entrypoint instead of a probe-specific IRQ handler.
- RISC-V64 normal boot now routes the same timer delivery through its normal
  trap entrypoint and resumes one normal kernel worker.

The important boundary: normal boot on both QEMU targets can run with scheduler
tick mode enabled, resume one normal kernel worker, switch away from that worker
through a voluntary yield trap, resume it again, and switch away through a block
trap that marks the worker blocked. There is still no long-running scheduler
workload or userspace policy.

## Subsystem Direction

Near-term work should make existing layers easier to reason about before moving
up to scheduler/userspace:

- keep normal synchronous trap handling panic-only until recoverable trap
  dispatch has a real caller
- decide whether the next slice should grow a second normal worker or start a
  syscall-shaped dispatch table for yield/block operations
- keep RISC-V timer delivery in the current Cory-owned M-mode shim unless a
  later SBI-style platform entry justifies a separate target
- keep QEMU AArch64 and RISC-V64 boot checks green after every slice

The first userspace and IPC work should wait until object identity and
capability tables are real enough that authority is not bolted on afterward.
