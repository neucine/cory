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

fs/
    owns the read-only initramfs-backed filesystem facade and archive reader

syscall/
    owns shared syscall decode, result vocabulary, and error mapping

selftest.cy
    thin facade for boot-time contract checks

tests/*_tests.cy
    own imported boot-time subsystem checks that keep both QEMU targets honest

tests/platform/<board>/*.test.cy
    own opt-in QEMU probe image entrypoints built by path through tools/dev.sh
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
  space. Kernel bootstrap creates the active kernel address space; rooted user
  address spaces can now be represented as inactive metadata with a real root
  table and user mapping policy, before user entry is enabled.
- `memory/user_loader.cy` owns the narrow loader path for populating rooted user
  address spaces. It checks address-space capability authority and user mapping
  policy before dispatching to architecture-local page-table writers.
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
  Inactive user processes can now be created only for rooted user address
  spaces, and they receive duplicated address-space authority with `inspect |
  map` rights rather than kernel `manage` authority.
- `task/thread.cy` installs each thread's root capability into its owning
  process capability space. Thread IDs are bounded slotmap keys, so thread
  liveness, lookup, and public handles share one vocabulary. User-shaped ready
  threads carry nonzero entry and stack metadata.
- `task/context.cy` stores common thread-context descriptors behind bounded
  slotmap keys. The descriptor records its own context key plus the
  architecture-specific context key owned by `arch/*/context.cy`. Thread
  lookups use the decoded thread slot index and then validate the exact thread
  key generation before returning a context. User context attachment seeds
  architecture-owned user-mode status flags from the thread entry/stack
  metadata. Probe images and the normal boot workload can enter those contexts.
- `task/user_entry.cy` owns reusable preparation for a minimal mapped user
  image: it creates a rooted user address space, user process, ready user
  thread, loader-owned code/stack mappings, and architecture context. The
  returned plan records both the bootstrap root and the user root, and mirrors
  kernel-only bootstrap mappings into the user root so probe images or normal
  init can switch the active hardware translation root before returning to user
  mode. Probe callers keep the process inactive; normal boot asks for an active
  init process.
- `task/user_program.cy` owns validated loaded user images. Platform boot reads
  `/bin/*` from initramfs, validates the small Cory image header, prepares each
  image as an inactive ready process, and records it in the catalog.
- `task/user_program_catalog.cy` is the stable program-name/id map used by
  spawn and inspect syscalls. The catalog names the current `/bin` programs
  instead of scattering numeric ids through syscall and platform code.
- `fs.cy` is the kernel filesystem facade. `fs/archive.cy` owns the tiny
  read-only initramfs archive parser so archive layout details do not leak into
  fd-table or syscall-facing code.
- `syscall.cy` owns syscall numbers, decode, request/result types, and shared
  status vocabulary. `syscall/error_map.cy` translates subsystem statuses into
  syscall errors at the syscall boundary.
- `kernel/selftest.cy` should stay a small facade over `tests/*_tests.cy`.
  Imported test modules cannot use `test` as a module-path segment because
  `test` is a Cyna keyword, so shared suites use names such as
  `memory_tests.cy`. Probe entry files that are built directly by path can keep
  the `*.test.cy` suffix.
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

The only active address space created during bootstrap is the kernel address
space. Selftests also create rooted inactive user address spaces, inactive user
processes, and ready user-shaped threads so that the object/capability boundary
is already exercised before loader and user-entry work begins.

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
- Address-space switch helpers: platform VM activation modules import tiny
  architecture symbols for changing AArch64 `TTBR0_EL1` or RISC-V64 `satp` once
  a user root has kernel mappings installed.
- Probe-only symbols: scheduler and trap tests export or import extra ABI
  entrypoints such as deliberate trap triggers, probe thread entries, user-mode
  trap stubs, and stack helpers. These should not set the production boundary.

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
  supervisor timer delivery. Both targets queue two normal kernel workers,
  resume one from a timer-driven scheduler tick after memory-ready, let that
  worker voluntarily yield through a synchronous trap, resume the second worker,
  block that second worker through another trap, then resume the first worker
  and let it yield once more with an empty run queue.
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
- Normal yield/block operations are decoded as target-local scheduler traps.
  AArch64 uses `brk` immediates; RISC-V64 uses an `ebreak` plus a saved argument
  number. The concrete trap encoding still lives in platform exception code,
  which converts target trap state into syscall numbers; `syscall.cy` owns the
  shared request, number-to-operation vocabulary, and decode status that a
  broader syscall surface can grow from. Syscall requests now carry four
  argument slots and an explicit origin, and syscall results have a small
  value/error shape. Cyna user programs call syscalls through the user-side OS
  wrapper instead of open-coding target trap symbols in each command.
- Rooted user address-space metadata, inactive user process metadata, and ready
  user-shaped thread metadata are now represented and selftested. The loader can
  map user pages into rooted user address spaces on both page-table formats,
  rejecting duplicate, kernel-range, kernel-right, and wrong-capability
  attempts. User process creation preserves the address-space capability
  boundary by duplicating only `inspect | map` rights, and user thread creation
  records entry/stack metadata. User-mode context attachment now seeds common
  and architecture-local context state with target-owned user return flags,
  and opt-in user-return probes can restore into one mapped user trap stub and
  catch its trap back in the kernel on both QEMU targets.
- AArch64 restore now distinguishes kernel and EL0 returns by loading `SP_EL0`
  for EL0t status flags. The RISC-V64 trap vector now uses `sscratch` to switch
  from an interrupted user stack to the kernel trap stack before saving the
  frame, so its user-return probe runs with a mapped user stack.
- User-return probe setup is now factored through `task/user_entry.cy` instead
  of duplicated in each platform test. The prepared user root now mirrors
  kernel-only bootstrap mappings, and both user-return probes switch the active
  root to that user root before restoring into user mode. AArch64 switches
  `TTBR0_EL1`; RISC-V64 switches `satp`.
- Normal boot now loads user programs from an embedded initramfs. User binaries
  are Cyna programs built under `user/`, wrapped in the small Cory image header,
  packed into `user/build/initramfs-<arch>.bin`, and exposed by the kernel as
  `/bin/*`. Platform boot reads those files through `fs.cy`, validates each
  `UserImageHeader`, prepares inactive ready processes with `task/user_entry.cy`,
  and records them in `task/user_program_catalog.cy`. Init starts a shell, and
  the shell can spawn `/bin/cat`, `/bin/echo`, `/bin/ls`, `/bin/ps`, and
  `/bin/selftest`.
- User syscalls now cover the current shell workload: debug-write, yield,
  process/thread identity, program inspect/spawn, wait/reap, process exit,
  argument passing, directory listing, and file reads. Debug-write validates a
  bounded user range, reads bytes from the active user mapping, writes them to
  the console, and returns the byte count. RISC-V64 opens `sstatus.SUM` only
  around validated user reads. Process exit stores the exit code, marks process
  and thread state, selects the next runnable thread, switches address-space
  root, and restores that thread.
- The current filesystem is a tiny read-only initramfs-backed tree with `/bin`,
  `/etc`, and `/etc/motd`. It is intentionally not a general filesystem yet;
  it exists to make user-program loading and simple shell commands concrete.
- `memory/user_memory.cy` owns the first user-buffer policy: process/address
  space lookup, overflow checks, user-range checks, a fixed debug-copy limit,
  and bounded byte streaming from user memory. It deliberately does not yet walk
  page tables after the active root has switched to a user root; a later
  kernel-mapped page-table window can make mapping validation stronger.

The important boundary: normal boot on both QEMU targets can now move from
timer-driven kernel scheduling into a small interactive userspace, load command
programs from `/bin`, and return through decoded user traps for file, process,
and console operations. There is still no long-running scheduler workload,
standard executable format, complete syscall ABI, IPC, or writable filesystem.

## Subsystem Direction

Near-term work should make existing layers easier to reason about before moving
up to scheduler/userspace:

- make the syscall and user OS wrapper easier to extend as more commands arrive
- decide how far the current Cory image header should go before a standard
  executable format is worth supporting
- keep RISC-V timer delivery in the current Cory-owned M-mode shim unless a
  later SBI-style platform entry justifies a separate target
- keep QEMU AArch64 and RISC-V64 boot checks green after every slice

The first userspace and IPC work should wait until object identity and
capability tables are real enough that authority is not bolted on afterward.
