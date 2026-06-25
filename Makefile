CYNA ?= $(HOME)/.cyna/0.1.8/bin/cyna
CYNA_LLVM_DIR ?= $(HOME)/.cyna/0.1.8/llvm

.PHONY: help check tree cyna-version toolchain-doctor check-cyna emit-aarch64-obj build-aarch64 clean qemu-aarch64 qemu-riscv64

help:
	@echo "Cycor scaffold targets:"
	@echo "  make check        Validate required scaffold files"
	@echo "  make tree         Print scaffold directories"
	@echo "  make cyna-version Print selected Cyna compiler version"
	@echo "  make toolchain-doctor Check local Cyna LLVM bundle"
	@echo "  make check-cyna   Run Cyna semantic check on the kernel entry"
	@echo "  make emit-aarch64-obj Emit the AArch64 kernel object file"
	@echo "  make build-aarch64 Build the AArch64 QEMU kernel stub"
	@echo "  make clean        Remove Cyna build outputs"
	@echo "  make qemu-aarch64 Placeholder for AArch64 QEMU run"
	@echo "  make qemu-riscv64 Placeholder for RISC-V64 QEMU bring-up"

check:
	@test -f README.md
	@test -f SPEC.md
	@test -d kernel/arch/aarch64
	@test -d kernel/arch/riscv64
	@test -d kernel/platform/qemu_aarch64_virt
	@test -d kernel/platform/raspberrypi_cm5
	@test -d kernel/platform/qemu_riscv64_virt
	@test -d kernel/platform/sifive_unmatched
	@test -d userspace/services/fake_sensor
	@test -d userspace/services/fake_isp
	@test -d userspace/services/preview
	@test -d userspace/services/storage_writer
	@test -d userspace/services/trace_service
	@test -f cyna.toml
	@test -f kernel/src/main.cy
	@test -f kernel/platform/qemu_aarch64_virt/boot/start.S
	@test -f kernel/platform/qemu_aarch64_virt/boot/link.ld
	@echo "Scaffold check passed."

tree:
	@find abi docs kernel tools userspace -type d | sort

cyna-version:
	@$(CYNA) version

toolchain-doctor:
	@$(CYNA) version
	@test -x "$(CYNA_LLVM_DIR)/bin/clang"
	@test -x "$(CYNA_LLVM_DIR)/bin/ld.lld"
	@if test ! -f "$(CYNA_LLVM_DIR)/lib/liblldELF.dylib"; then \
		echo "warning: $(CYNA_LLVM_DIR)/bin/ld.lld is missing lib/liblldELF.dylib"; \
		echo "         full ELF/BIN linking will fail until the Cyna LLVM bundle is repaired"; \
	else \
		echo "Cyna LLVM linker bundle looks complete."; \
	fi

check-cyna:
	@$(CYNA) check kernel/src/main.cy

emit-aarch64-obj:
	@rm -f build/cycor.o
	@$(CYNA) build . --emit-obj --output build/cycor >/tmp/cycor-cyna-emit.log 2>&1 || test -f build/cycor.o
	@test -f build/cycor.o
	@echo "wrote build/cycor.o"

build-aarch64:
	@$(CYNA) build .

clean:
	@$(CYNA) clean .

qemu-aarch64:
	@echo "TODO: add QEMU launch after serial logging is implemented."

qemu-riscv64:
	@echo "TODO: wire Cyna freestanding build, linker script, and qemu-system-riscv64 -machine virt."
