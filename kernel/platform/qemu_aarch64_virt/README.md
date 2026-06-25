# QEMU AArch64 `virt`

Primary Tier 0 bring-up platform.

Initial goals:

- boot into kernel code
- early serial logging
- exception vector setup
- basic memory map
- early allocator
- minimal test harness

Current scaffold:

- `boot/start.S`
- `boot/link.ld`
- root `cyna.toml` target: `aarch64-none-elf`

Build with:

```text
make build-aarch64
```
