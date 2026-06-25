# Cyna Toolchain

Cycor expects Cyna to be available from the local distribution installed under
`~/.cyna`.

Default compiler:

```text
~/.cyna/0.1.8/bin/cyna
```

The root `cyna.toml` currently targets the Tier 0 AArch64 QEMU `virt` bring-up:

```text
aarch64-none-elf
```

Build commands:

```text
make cyna-version
make toolchain-doctor
make check-cyna
make emit-aarch64-obj
make build-aarch64
```

Override the compiler path when needed:

```text
make build-aarch64 CYNA=/path/to/cyna
```

Expected outputs:

```text
build/cycor.o
build/cycor
build/cycor.elf
build/cycor.bin
```

Current local note:

The installed 0.1.8 Cyna compiler can semantically check the kernel entry and
emit an AArch64 object file. Full ELF/BIN linking depends on the bundled
`ld.lld`; if `make toolchain-doctor` reports a missing `liblldELF.dylib`, repair
or reinstall the local Cyna LLVM bundle before using `make build-aarch64`.
