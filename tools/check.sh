#!/usr/bin/env sh
set -eu

CYNA="${CYNA:-/Users/chao.yang/Private/cyna/zig-out/bin/cyna}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-3}"

usage() {
  cat <<'EOF'
usage: tools/check.sh <command>

commands:
  aarch64        check, build, and boot the normal AArch64 QEMU image
  riscv64        check, build, and boot the normal RISC-V64 QEMU image
  trap-aarch64   check, build, and boot the opt-in AArch64 trap probe
  trap-riscv64   check, build, and boot the opt-in RISC-V64 trap probe
  normal         run aarch64 and riscv64
  traps          run trap-aarch64 and trap-riscv64
  all            run normal and traps
EOF
}

run_qemu() {
  "$@" || code=$?
  if [ "${code:-0}" -ne 0 ] && [ "${code:-0}" -ne 124 ]; then
    return "$code"
  fi
  unset code
}

run_aarch64() {
  "$CYNA" check .
  "$CYNA" build .
  run_qemu timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cycor.elf
}

run_riscv64() {
  "$CYNA" check cyna.riscv64.toml
  "$CYNA" build cyna.riscv64.toml
  run_qemu timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cycor-riscv64.elf
}

run_trap_aarch64() {
  "$CYNA" check cyna.traptest.toml
  "$CYNA" build cyna.traptest.toml
  run_qemu timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cycor-traptest.elf
}

run_trap_riscv64() {
  "$CYNA" check cyna.traptest.riscv64.toml
  "$CYNA" build cyna.traptest.riscv64.toml
  run_qemu timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cycor-traptest-riscv64.elf
}

run_normal() {
  run_aarch64
  run_riscv64
}

run_traps() {
  run_trap_aarch64
  run_trap_riscv64
}

command="${1:-}"
case "$command" in
  aarch64)
    run_aarch64
    ;;
  riscv64)
    run_riscv64
    ;;
  trap-aarch64)
    run_trap_aarch64
    ;;
  trap-riscv64)
    run_trap_riscv64
    ;;
  normal)
    run_normal
    ;;
  traps)
    run_traps
    ;;
  all)
    run_normal
    run_traps
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac
