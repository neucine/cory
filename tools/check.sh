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
  timerirq-riscv64 check, build, and boot the opt-in RISC-V64 timer IRQ probe
  timerdiag-aarch64 check, build, and boot the opt-in AArch64 diagnostic tick probe
  timersched-aarch64 check, build, and boot the opt-in AArch64 timer scheduler probe
  timersched-riscv64 check, build, and boot the opt-in RISC-V64 timer scheduler probe
  normalsched-aarch64 check, build, and boot the opt-in AArch64 normal IRQ scheduler probe
  normal         run aarch64 and riscv64
  traps          run trap-aarch64 and trap-riscv64
  restore        run restore-aarch64 and restore-riscv64
  sched          run sched-aarch64 and sched-riscv64
  timerirq       run timerirq-aarch64 and timerirq-riscv64
  timerdiag      run timerdiag-aarch64
  timersched     run timersched-aarch64 and timersched-riscv64
  normalsched    run normalsched-aarch64
  all            run normal, traps, restore, sched, timerirq, timerdiag, timersched, and normalsched
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

generate_probe_manifest() {
  label="$1"
  base_manifest="$2"
  test_name="$3"
  test_entry="$4"
  extra_asm="$5"
  output=".cory-${label}-$$.toml"

  awk -v test_name="$test_name" -v test_entry="$test_entry" -v extra_asm="$extra_asm" '
    /^name = / {
      print "name = \"" test_name "\""
      next
    }
    /^entry = / {
      print "entry = \"" test_entry "\""
      next
    }
    /^sources = / && extra_asm != "" {
      sub(/\][[:space:]]*$/, ", \"" extra_asm "\"]")
      print
      next
    }
    {
      print
    }
  ' "$base_manifest" > "$output"
  printf '%s\n' "$output"
}

run_probe() {
  label="$1"
  base_manifest="$2"
  test_name="$3"
  test_entry="$4"
  extra_asm="$5"
  expected_1="$6"
  expected_2="$7"
  shift 7

  manifest="$(generate_probe_manifest "$label" "$base_manifest" "$test_name" "$test_entry" "$extra_asm")"
  if "$CYNA" check "$manifest" && "$CYNA" build "$manifest" && run_qemu_expect "$label" "$expected_1" "$expected_2" "$@"; then
    rm -f "$manifest"
    return 0
  fi
  status="$?"
  rm -f "$manifest"
  return "$status"
}

run_aarch64() {
  "$CYNA" check .
  "$CYNA" build .
  run_qemu_expect aarch64 "memory: physical pages ready" "scheduler: normal thread resumed" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory.elf
}

run_riscv64() {
  "$CYNA" check cyna.riscv64.toml
  "$CYNA" build cyna.riscv64.toml
  run_qemu_expect riscv64 "memory: physical pages ready" "scheduler: normal thread resumed" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-riscv64.elf
}

run_trap_aarch64() {
  run_probe trap-aarch64 cyna.toml cory-traptest src/kernel/platform/qemu_aarch64_virt/trap.test.cy "" "traptest: trigger aarch64" "exception: unhandled aarch64" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-traptest.elf
}

run_trap_riscv64() {
  run_probe trap-riscv64 cyna.riscv64.toml cory-traptest-riscv64 src/kernel/platform/qemu_riscv64_virt/trap.test.cy "" "traptest: trigger riscv64" "exception: unhandled riscv64" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-traptest-riscv64.elf
}

run_restore_aarch64() {
  run_probe restore-aarch64 cyna.toml cory-restoretest src/kernel/platform/qemu_aarch64_virt/restore.test.cy "" "restoretest: resumed aarch64" "panic" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-restoretest.elf
}

run_restore_riscv64() {
  run_probe restore-riscv64 cyna.riscv64.toml cory-restoretest-riscv64 src/kernel/platform/qemu_riscv64_virt/restore.test.cy "" "restoretest: resumed riscv64" "panic" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-restoretest-riscv64.elf
}

run_sched_aarch64() {
  run_probe sched-aarch64 cyna.toml cory-schedtest src/kernel/platform/qemu_aarch64_virt/sched.test.cy src/kernel/platform/qemu_aarch64_virt/schedtest.S "schedtest: selected thread b" "schedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-schedtest.elf
}

run_sched_riscv64() {
  run_probe sched-riscv64 cyna.riscv64.toml cory-schedtest-riscv64 src/kernel/platform/qemu_riscv64_virt/sched.test.cy src/kernel/platform/qemu_riscv64_virt/schedtest.S "schedtest: selected thread b" "schedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-schedtest-riscv64.elf
}

run_timerirq_aarch64() {
  run_probe timerirq-aarch64 cyna.toml cory-timerirqtest src/kernel/platform/qemu_aarch64_virt/timerirq.test.cy "" "timerirqtest: waiting for virtual timer irq" "timerirqtest: received virtual timer irq" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-timerirqtest.elf
}

run_timerirq_riscv64() {
  run_probe timerirq-riscv64 cyna.riscv64.toml cory-timerirqtest-riscv64 src/kernel/platform/qemu_riscv64_virt/timerirq.test.cy "" "timerirqtest: waiting for supervisor timer irq" "timerirqtest: received supervisor timer irq" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-timerirqtest-riscv64.elf
}

run_timerdiag_aarch64() {
  run_probe timerdiag-aarch64 cyna.toml cory-timerdiagtest src/kernel/platform/qemu_aarch64_virt/timerdiag.test.cy "" "timerdiagtest: waiting for diagnostic tick" "timerdiagtest: diagnostic tick" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-timerdiagtest.elf
}

run_timersched_aarch64() {
  run_probe timersched-aarch64 cyna.toml cory-timerschedtest src/kernel/platform/qemu_aarch64_virt/timersched.test.cy src/kernel/platform/qemu_aarch64_virt/schedtest.S "timerschedtest: selected thread b" "timerschedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-timerschedtest.elf
}

run_timersched_riscv64() {
  run_probe timersched-riscv64 cyna.riscv64.toml cory-timerschedtest-riscv64 src/kernel/platform/qemu_riscv64_virt/timersched.test.cy src/kernel/platform/qemu_riscv64_virt/schedtest.S "timerschedtest: selected thread b" "timerschedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel build/cory-timerschedtest-riscv64.elf
}

run_normalsched_aarch64() {
  run_probe normalsched-aarch64 cyna.toml cory-normalschedtest src/kernel/platform/qemu_aarch64_virt/normalsched.test.cy src/kernel/platform/qemu_aarch64_virt/schedtest.S "tick: scheduler tick" "normalschedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel build/cory-normalschedtest.elf
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
  run_timerirq_riscv64
}

run_timerdiag() {
  run_timerdiag_aarch64
}

run_timersched() {
  run_timersched_aarch64
  run_timersched_riscv64
}

run_normalsched() {
  run_normalsched_aarch64
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
  timerirq-riscv64)
    run_timerirq_riscv64
    ;;
  timerdiag-aarch64)
    run_timerdiag_aarch64
    ;;
  timersched-aarch64)
    run_timersched_aarch64
    ;;
  timersched-riscv64)
    run_timersched_riscv64
    ;;
  normalsched-aarch64)
    run_normalsched_aarch64
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
  timerdiag)
    run_timerdiag
    ;;
  timersched)
    run_timersched
    ;;
  normalsched)
    run_normalsched
    ;;
  all)
    run_normal
    run_traps
    run_restore
    run_sched
    run_timerirq
    run_timerdiag
    run_timersched
    run_normalsched
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac
