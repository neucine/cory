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
  restore-aarch64 check, build, and boot the opt-in AArch64 restore probe
  restore-riscv64 check, build, and boot the opt-in RISC-V64 restore probe
  sched-aarch64 check, build, and boot the opt-in AArch64 trap scheduler probe
  sched-riscv64 check, build, and boot the opt-in RISC-V64 trap scheduler probe
  timerirq-aarch64 check, build, and boot the opt-in AArch64 timer IRQ probe
  normal         run aarch64 and riscv64
  traps          run trap-aarch64 and trap-riscv64
  restore        run restore-aarch64 and restore-riscv64
  sched          run sched-aarch64 and sched-riscv64
  timerirq       run timerirq-aarch64
  all            run normal, traps, restore, sched, and timerirq
EOF
}

run_qemu_expect() {
  label="$1"
  expected_1="$2"
  expected_2="$3"
  shift 3
  output="${TMPDIR:-/tmp}/cory-check-${label}-$$.log"

  "$@" > "$output" 2>&1 || code=$?
  cat "$output"
  if [ "${code:-0}" -ne 0 ] && [ "${code:-0}" -ne 124 ]; then
    rm -f "$output"
    return "$code"
  fi
  unset code

  for expected in "$expected_1" "$expected_2"; do
    if [ "$expected" != "" ] && ! grep -Fq "$expected" "$output"; then
      printf '%s\n' "missing expected QEMU output for ${label}: ${expected}" >&2
      rm -f "$output"
      return 1
    fi
  done
  rm -f "$output"
}

run_aarch64() {
  "$CYNA" check .
  "$CYNA" build .
  run_qemu_expect aarch64 "timer: deadline ready" "memory: physical pages ready" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory.elf
}

run_riscv64() {
  "$CYNA" check cyna.riscv64.toml
  "$CYNA" build cyna.riscv64.toml
  run_qemu_expect riscv64 "timer: counter ready" "memory: physical pages ready" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-riscv64.elf
}

run_trap_aarch64() {
  "$CYNA" check cyna.traptest.toml
  "$CYNA" build cyna.traptest.toml
  run_qemu_expect trap-aarch64 "traptest: trigger aarch64" "exception: unhandled aarch64" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-traptest.elf
}

run_trap_riscv64() {
  "$CYNA" check cyna.traptest.riscv64.toml
  "$CYNA" build cyna.traptest.riscv64.toml
  run_qemu_expect trap-riscv64 "traptest: trigger riscv64" "exception: unhandled riscv64" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-traptest-riscv64.elf
}

run_restore_aarch64() {
  "$CYNA" check cyna.restoretest.toml
  "$CYNA" build cyna.restoretest.toml
  run_qemu_expect restore-aarch64 "restoretest: resumed aarch64" "panic" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-restoretest.elf
}

run_restore_riscv64() {
  "$CYNA" check cyna.restoretest.riscv64.toml
  "$CYNA" build cyna.restoretest.riscv64.toml
  run_qemu_expect restore-riscv64 "restoretest: resumed riscv64" "panic" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-restoretest-riscv64.elf
}

run_sched_aarch64() {
  "$CYNA" check cyna.schedtest.toml
  "$CYNA" build cyna.schedtest.toml
  run_qemu_expect sched-aarch64 "schedtest: selected thread b" "schedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-schedtest.elf
}

run_sched_riscv64() {
  "$CYNA" check cyna.schedtest.riscv64.toml
  "$CYNA" build cyna.schedtest.riscv64.toml
  run_qemu_expect sched-riscv64 "schedtest: selected thread b" "schedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-schedtest-riscv64.elf
}

run_timerirq_aarch64() {
  "$CYNA" check cyna.timerirqtest.toml
  "$CYNA" build cyna.timerirqtest.toml
  run_qemu_expect timerirq-aarch64 "timerirqtest: waiting for virtual timer irq" "timerirqtest: received virtual timer irq" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-timerirqtest.elf
}

run_normal() {
  run_aarch64
  run_riscv64
}

run_traps() {
  run_trap_aarch64
  run_trap_riscv64
}

run_restore() {
  run_restore_aarch64
  run_restore_riscv64
}

run_sched() {
  run_sched_aarch64
  run_sched_riscv64
}

run_timerirq() {
  run_timerirq_aarch64
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
  restore-aarch64)
    run_restore_aarch64
    ;;
  restore-riscv64)
    run_restore_riscv64
    ;;
  sched-aarch64)
    run_sched_aarch64
    ;;
  sched-riscv64)
    run_sched_riscv64
    ;;
  timerirq-aarch64)
    run_timerirq_aarch64
    ;;
  normal)
    run_normal
    ;;
  traps)
    run_traps
    ;;
  restore)
    run_restore
    ;;
  sched)
    run_sched
    ;;
  timerirq)
    run_timerirq
    ;;
  all)
    run_normal
    run_traps
    run_restore
    run_sched
    run_timerirq
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac
