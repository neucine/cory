#!/usr/bin/env sh
set -eu

CYNA="${CYNA:-/Users/chao.yang/Private/cyna/zig-out/bin/cyna}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-15}"

usage() {
  cat <<'EOF'
usage: tools/dev.sh <command>

commands:
  aarch64        check, build, and boot the normal AArch64 QEMU image
  riscv64        check, build, and boot the normal RISC-V64 QEMU image
  run-aarch64    run the existing normal AArch64 QEMU image interactively
  run-arm64      alias for run-aarch64
  run-riscv64    run the existing normal RISC-V64 QEMU image interactively
  build-run-aarch64 build and run the normal AArch64 QEMU image interactively
  build-run-riscv64 build and run the normal RISC-V64 QEMU image interactively
  trap-aarch64   check, build, and boot the opt-in AArch64 trap probe
  trap-riscv64   check, build, and boot the opt-in RISC-V64 trap probe
  restore-aarch64 check, build, and boot the opt-in AArch64 restore probe
  restore-riscv64 check, build, and boot the opt-in RISC-V64 restore probe
  userret-aarch64 check, build, and boot the opt-in AArch64 user return probe
  userret-riscv64 check, build, and boot the opt-in RISC-V64 user return probe
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
  userret        run userret-aarch64 and userret-riscv64
  sched          run sched-aarch64 and sched-riscv64
  timerirq       run timerirq-aarch64 and timerirq-riscv64
  timerdiag      run timerdiag-aarch64
  timersched     run timersched-aarch64 and timersched-riscv64
  normalsched    run normalsched-aarch64
  all            run normal, traps, restore, userret, sched, timerirq, timerdiag, timersched, and normalsched

interactive QEMU:
  use Ctrl-c to quit when running interactively
EOF
}

run_qemu_expect() {
  label="$1"
  shift
  output="${TMPDIR:-/tmp}/cory-check-${label}-$$.log"
  expected_output="${TMPDIR:-/tmp}/cory-check-${label}-$$.expected"

  : > "$expected_output"
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    printf '%s\n' "$1" >> "$expected_output"
    shift
  done
  if [ "$#" -eq 0 ]; then
    printf '%s\n' "missing QEMU command separator for ${label}" >&2
    rm -f "$output" "$expected_output"
    return 2
  fi
  shift

  "$@" > "$output" 2>&1 || code=$?
  cat "$output"
  if [ "${code:-0}" -ne 0 ] && [ "${code:-0}" -ne 124 ]; then
    rm -f "$output" "$expected_output"
    return "$code"
  fi
  unset code

  while IFS= read -r expected; do
    if [ "$expected" != "" ] && ! grep -Fq "$expected" "$output"; then
      printf '%s\n' "missing expected QEMU output for ${label}: ${expected}" >&2
      rm -f "$output" "$expected_output"
      return 1
    fi
  done < "$expected_output"
  rm -f "$output" "$expected_output"
}

build_user_images_for_arch() {
  arch="$1"
  for program in init selftest shell echo ps ls cat; do
    "$CYNA" build "user/${program}.toml" --build "$arch"
  done
  python3 tools/mkinitramfs.py "user/build/initramfs-${arch}.bin"
}

build_user_images() {
  build_user_images_for_arch aarch64
  build_user_images_for_arch riscv64
}

build_kernel_for_arch() {
  arch="$1"
  "$CYNA" check kernel/cyna.toml --build "$arch"
  "$CYNA" build kernel/cyna.toml --build "$arch"
}

generate_probe_manifest() {
  label="$1"
  arch="$2"
  test_name="$3"
  test_entry="$4"
  extra_asm="$5"
  manifest_dir="kernel"
  output="${manifest_dir}/.cory-${label}-$$.toml"

  case "$arch" in
    aarch64)
      target="aarch64-none-elf"
      cpu="generic"
      platform="qemu_aarch64_virt"
      arch_trap_asm="src/arch/aarch64/exception.S"
      ;;
    riscv64)
      target="riscv64-none-elf"
      cpu="generic-rv64"
      platform="qemu_riscv64_virt"
      arch_trap_asm="src/arch/riscv64/trap.S"
      ;;
    *)
      printf '%s\n' "unknown probe architecture: ${arch}" >&2
      return 2
      ;;
  esac

  asm_sources="\"src/arch/${arch}/start.S\", \"${arch_trap_asm}\", \"src/platform/${platform}/normal_thread.S\", \"src/platform/${platform}/user_programs.S\""
  if [ "$extra_asm" != "" ]; then
    asm_sources="${asm_sources}, \"${extra_asm}\""
  fi

  cat > "$output" <<EOF
name = "${test_name}"
src = "src"

[build]
kind = "exe"
entry = "${test_entry}"
target = "${target}"
cpu = "${cpu}"
opt = "release"
emit = ["elf", "bin"]

[link]
script = "src/platform/${platform}/link.ld"
entry_symbol = "_start"

[asm]
sources = [${asm_sources}]
EOF
  printf '%s\n' "$output"
}

run_probe() {
  label="$1"
  arch="$2"
  test_name="$3"
  test_entry="$4"
  extra_asm="$5"
  expected_1="$6"
  expected_2="$7"
  shift 7

  build_user_images_for_arch "$arch"
  manifest_dir="kernel"
  temp_entry="src/.cory-${label}-$$.cy"
  cp "${manifest_dir}/${test_entry}" "${manifest_dir}/${temp_entry}"
  manifest="$(generate_probe_manifest "$label" "$arch" "$test_name" "$temp_entry" "$extra_asm")"
  if "$CYNA" check "$manifest" && "$CYNA" build "$manifest" && run_qemu_expect "$label" "$expected_1" "$expected_2" -- "$@"; then
    rm -f "$manifest" "${manifest_dir}/${temp_entry}"
    return 0
  fi
  status="$?"
  rm -f "$manifest" "${manifest_dir}/${temp_entry}"
  return "$status"
}

run_aarch64() {
  build_user_images_for_arch aarch64
  build_kernel_for_arch aarch64
  run_qemu_expect aarch64 \
    "userspace: normal user spawned selftest aarch64" \
    "userspace: cy selftest ran ok" \
    "userspace: selftest wait ok from init" \
    "userspace: normal user spawned shell aarch64" \
    "|      Cory      |" \
    "cory> help" \
    "shell: commands: help, cat, echo, ls, ps, selftest, exit" \
    "cory> ps" \
    "userspace: normal user spawned ps aarch64" \
    "ps: process table" \
    "cory> ls" \
    "userspace: normal user spawned ls aarch64" \
    "/etc/motd" \
    "cory> ls /bin" \
    "userspace: normal user spawned ls aarch64" \
    "cat" \
    "echo" \
    "selftest" \
    "cory> selftest" \
    "userspace: normal user spawned selftest aarch64" \
    "userspace: cy selftest ran ok" \
    "cory> ls /etc" \
    "userspace: normal user spawned ls aarch64" \
    "motd" \
    "cory> cat /etc/motd" \
    "userspace: normal user spawned cat aarch64" \
    "hello from cory fs" \
    "cory> echo alive" \
    "userspace: normal user spawned echo aarch64" \
    "alive" \
    "cory>   ps" \
    "cory> echo   spaced" \
    "spaced" \
    "cory> echo again" \
    "again" \
    -- sh -c 'python3 -c '"'"'import sys, time
time.sleep(2)
for line in ["help", "ps", "ls", "ls /bin", "selftest", "ls /etc", "cat /etc/motd", "echo alive", "  ps", "echo   spaced", "echo again"]:
    for ch in line + "\n":
        sys.stdout.write(ch)
        sys.stdout.flush()
        time.sleep(0.03)
    time.sleep(0.7)
time.sleep(3)
'"'"' | timeout "$1" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel kernel/build/cory-aarch64.elf' sh "$QEMU_TIMEOUT"
}

run_riscv64() {
  build_user_images_for_arch riscv64
  build_kernel_for_arch riscv64
  run_qemu_expect riscv64 \
    "userspace: normal user spawned selftest riscv64" \
    "userspace: cy selftest ran ok" \
    "userspace: selftest wait ok from init" \
    "userspace: normal user spawned shell riscv64" \
    "|      Cory      |" \
    "cory> help" \
    "shell: commands: help, cat, echo, ls, ps, selftest, exit" \
    "cory> ps" \
    "userspace: normal user spawned ps riscv64" \
    "ps: process table" \
    "cory> ls" \
    "userspace: normal user spawned ls riscv64" \
    "/etc/motd" \
    "cory> ls /bin" \
    "userspace: normal user spawned ls riscv64" \
    "cat" \
    "echo" \
    "selftest" \
    "cory> selftest" \
    "userspace: normal user spawned selftest riscv64" \
    "userspace: cy selftest ran ok" \
    "cory> ls /etc" \
    "userspace: normal user spawned ls riscv64" \
    "motd" \
    "cory> cat /etc/motd" \
    "userspace: normal user spawned cat riscv64" \
    "hello from cory fs" \
    "cory> echo alive" \
    "userspace: normal user spawned echo riscv64" \
    "alive" \
    "cory>   ps" \
    "cory> echo   spaced" \
    "spaced" \
    "cory> echo again" \
    "again" \
    -- sh -c 'python3 -c '"'"'import sys, time
time.sleep(2)
for line in ["help", "ps", "ls", "ls /bin", "selftest", "ls /etc", "cat /etc/motd", "echo alive", "  ps", "echo   spaced", "echo again"]:
    for ch in line + "\n":
        sys.stdout.write(ch)
        sys.stdout.flush()
        time.sleep(0.03)
    time.sleep(0.7)
time.sleep(3)
'"'"' | timeout "$1" qemu-system-riscv64 -machine virt -nographic -bios none -kernel kernel/build/cory-riscv64.elf' sh "$QEMU_TIMEOUT"
}

qemu_aarch64_interactive() {
  printf '%s\n' "starting AArch64 QEMU on stdio serial; use Ctrl-c to quit"
  qemu-system-aarch64 -machine virt -cpu cortex-a53 -display none -serial stdio -monitor none -kernel kernel/build/cory-aarch64.elf
}

qemu_riscv64_interactive() {
  printf '%s\n' "starting RISC-V64 QEMU on stdio serial; use Ctrl-c to quit"
  qemu-system-riscv64 -machine virt -display none -serial stdio -monitor none -bios none -kernel kernel/build/cory-riscv64.elf
}

build_run_interactive_aarch64() {
  build_user_images_for_arch aarch64
  build_kernel_for_arch aarch64
  qemu_aarch64_interactive
}

build_run_interactive_riscv64() {
  build_user_images_for_arch riscv64
  build_kernel_for_arch riscv64
  qemu_riscv64_interactive
}

run_trap_aarch64() {
  run_probe trap-aarch64 aarch64 cory-traptest src/tests/platform/qemu_aarch64_virt/trap.test.cy "" "traptest: trigger aarch64" "exception: unhandled aarch64" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel kernel/build/cory-traptest.elf
}

run_trap_riscv64() {
  run_probe trap-riscv64 riscv64 cory-traptest-riscv64 src/tests/platform/qemu_riscv64_virt/trap.test.cy "" "traptest: trigger riscv64" "exception: unhandled riscv64" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel kernel/build/cory-traptest-riscv64.elf
}

run_restore_aarch64() {
  run_probe restore-aarch64 aarch64 cory-restoretest src/tests/platform/qemu_aarch64_virt/restore.test.cy "" "restoretest: resumed aarch64" "panic" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel kernel/build/cory-restoretest.elf
}

run_restore_riscv64() {
  run_probe restore-riscv64 riscv64 cory-restoretest-riscv64 src/tests/platform/qemu_riscv64_virt/restore.test.cy "" "restoretest: resumed riscv64" "panic" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel kernel/build/cory-restoretest-riscv64.elf
}

run_userret_aarch64() {
  run_probe userret-aarch64 aarch64 cory-userrettest src/tests/platform/qemu_aarch64_virt/userret.test.cy src/platform/qemu_aarch64_virt/usermode_probe.S "userrettest: return to user aarch64" "userrettest: user trap aarch64" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel kernel/build/cory-userrettest.elf
}

run_userret_riscv64() {
  run_probe userret-riscv64 riscv64 cory-userrettest-riscv64 src/tests/platform/qemu_riscv64_virt/userret.test.cy src/platform/qemu_riscv64_virt/usermode_probe.S "userrettest: return to user riscv64" "userrettest: user trap riscv64" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel kernel/build/cory-userrettest-riscv64.elf
}

run_sched_aarch64() {
  run_probe sched-aarch64 aarch64 cory-schedtest src/tests/platform/qemu_aarch64_virt/sched.test.cy src/platform/qemu_aarch64_virt/schedtest.S "schedtest: selected thread b" "schedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel kernel/build/cory-schedtest.elf
}

run_sched_riscv64() {
  run_probe sched-riscv64 riscv64 cory-schedtest-riscv64 src/tests/platform/qemu_riscv64_virt/sched.test.cy src/platform/qemu_riscv64_virt/schedtest.S "schedtest: selected thread b" "schedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel kernel/build/cory-schedtest-riscv64.elf
}

run_timerirq_aarch64() {
  run_probe timerirq-aarch64 aarch64 cory-timerirqtest src/tests/platform/qemu_aarch64_virt/timerirq.test.cy "" "timerirqtest: waiting for virtual timer irq" "timerirqtest: received virtual timer irq" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel kernel/build/cory-timerirqtest.elf
}

run_timerirq_riscv64() {
  run_probe timerirq-riscv64 riscv64 cory-timerirqtest-riscv64 src/tests/platform/qemu_riscv64_virt/timerirq.test.cy "" "timerirqtest: waiting for supervisor timer irq" "timerirqtest: received supervisor timer irq" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel kernel/build/cory-timerirqtest-riscv64.elf
}

run_timerdiag_aarch64() {
  run_probe timerdiag-aarch64 aarch64 cory-timerdiagtest src/tests/platform/qemu_aarch64_virt/timerdiag.test.cy "" "timerdiagtest: waiting for diagnostic tick" "timerdiagtest: diagnostic tick" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel kernel/build/cory-timerdiagtest.elf
}

run_timersched_aarch64() {
  run_probe timersched-aarch64 aarch64 cory-timerschedtest src/tests/platform/qemu_aarch64_virt/timersched.test.cy src/platform/qemu_aarch64_virt/schedtest.S "timerschedtest: selected thread b" "timerschedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel kernel/build/cory-timerschedtest.elf
}

run_timersched_riscv64() {
  run_probe timersched-riscv64 riscv64 cory-timerschedtest-riscv64 src/tests/platform/qemu_riscv64_virt/timersched.test.cy src/platform/qemu_riscv64_virt/schedtest.S "timerschedtest: selected thread b" "timerschedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-riscv64 -machine virt -nographic -bios none -kernel kernel/build/cory-timerschedtest-riscv64.elf
}

run_normalsched_aarch64() {
  run_probe normalsched-aarch64 aarch64 cory-normalschedtest src/tests/platform/qemu_aarch64_virt/normalsched.test.cy src/platform/qemu_aarch64_virt/schedtest.S "tick: scheduler tick" "normalschedtest: thread b resumed" timeout "$QEMU_TIMEOUT" qemu-system-aarch64 -machine virt -cpu cortex-a53 -nographic -kernel kernel/build/cory-normalschedtest.elf
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

run_userret() {
  run_userret_aarch64
  run_userret_riscv64
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
  run-aarch64|run-arm64)
    qemu_aarch64_interactive
    ;;
  run-riscv64)
    qemu_riscv64_interactive
    ;;
  build-run-aarch64|build-run-arm64)
    build_run_interactive_aarch64
    ;;
  build-run-riscv64)
    build_run_interactive_riscv64
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
  userret-aarch64)
    run_userret_aarch64
    ;;
  userret-riscv64)
    run_userret_riscv64
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
  userret)
    run_userret
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
    run_userret
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
