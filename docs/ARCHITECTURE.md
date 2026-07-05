# Cory Architecture

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
        -> bootstrap.finish_after_memory_ready(...)
```

Platform code performs the final MMU register switch because the activation
symbols and registers are architecture-specific. Common bootstrap code prepares
the architecture-neutral plan and verifies it through selftests.

The only real address space created during bootstrap is the kernel address
space. User-shaped address spaces currently appear only as unrooted policy
fixtures in selftests; real userspace address spaces arrive with process and
loader work.

## Current Progress

The implementation is through the first recoverable-trap and timer-interrupt
proofs, but not yet through normal preemption:

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
  deadline programming, then configures the virtual timer IRQ route while IRQs
  remain masked. RISC-V64 normal boot proves S-mode `time` readability.
- The AArch64 platform interrupt module owns IRQ mask/unmask, GICv2
  acknowledge/EOI, and virtual timer IRQ completion helpers.
- The AArch64 tick policy module owns timer tick delivery state. Normal boot
  defaults delivery to disabled; opt-in probes exercise diagnostic delivery and
  scheduler consumption separately.
- Normal AArch64 boot exports an explicit panic-only IRQ entrypoint.
- The AArch64 timer IRQ probe configures QEMU `virt` GICv2 through the
  interrupt module, receives virtual timer INTID 27, disarms the timer, and EOIs
  the interrupt.
- The AArch64 diagnostic tick probe enables dry-run tick delivery, receives
  INTID 27, completes the timer IRQ, and does not schedule.
- The AArch64 timer scheduling probe receives virtual timer INTID 27, disarms
  and EOIs it, then uses the target-local schedule-and-restore path to resume a
  ready thread.

The important boundary: timer-driven scheduling is still diagnostic-only.
Normal boot configures the AArch64 timer IRQ route, but does not unmask IRQs and
keeps tick delivery disabled.

## Subsystem Direction

Near-term work should make existing layers easier to reason about before moving
up to scheduler/userspace:

- keep normal boot panic-only until interrupt scheduling is boring in probes
- decide whether normal boot should first unmask only diagnostic ticks or wait
  for scheduler policy
- add the matching RISC-V timer interrupt path after the AArch64 path is stable
- keep QEMU AArch64 and RISC-V64 boot checks green after every slice

The first userspace and IPC work should wait until object identity and
capability tables are real enough that authority is not bolted on afterward.
