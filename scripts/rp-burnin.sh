#!/usr/bin/env bash
# Rocket Pool Node Burn-in – Fedora 13 friendly, minimal dependencies
# Performs consecutive CPU, RAM, and disk stress tests with simple logging.
# Requirements (install via `yum install stress memtester fio smartmontools`):
#   - stress  (CPU & RAM load)
#   - memtester
#   - fio     (defaults to libaio engine for old kernels)
#   - smartctl (optional, for disk SMART info)
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi

LOG_DIR=${LOG_DIR:-/var/log/rp-burnin}
CPU_DURATION=${CPU_DURATION:-1800}      # seconds   (30 min)
RAM_DURATION=${RAM_DURATION:-1800}      # seconds
MEMTEST_PASSES=${MEMTEST_PASSES:-1}
RAM_STRESS_PCT=${RAM_STRESS_PCT:-70}    # % of total RAM for stress --vm
MEMTEST_PCT=${MEMTEST_PCT:-50}          # % of total RAM for memtester
RAM_RESERVE_MB=${RAM_RESERVE_MB:-512}   # Leave at least this much RAM unused
RAM_MIN_ALLOC_MB=${RAM_MIN_ALLOC_MB:-128}
RAM_TARGET_SCALE_PCT=${RAM_TARGET_SCALE_PCT:-50} # scale RAM workloads (100 = full request)
# RAM_TARGET_SCALE_PCT=${RAM_TARGET_SCALE_PCT:100} # scale RAM workloads (100 = full request)
FIO_RUNTIME=${FIO_RUNTIME:-900}         # seconds   (15 min)
FIO_SIZE=${FIO_SIZE:-8G}
FIO_FILE=${FIO_FILE:-/var/tmp/rp-fio-testfile.bin}
FIO_IOENGINE=${FIO_IOENGINE:-libaio}    # io_uring unavailable on Fedora 13 kernels

mkdir -p "$LOG_DIR"

log()  { echo "[$(date '+%F %T')] $*"; }
ok()   { log "OK: $*"; }
warn() { log "WARN: $*" >&2; }
err()  { log "ERR: $*" >&2; }

# Ensure the script has the privileges it needs to hit hardware directly.
require_root(){
  if [[ $EUID -ne 0 ]]; then
    err "Run this script as root so it can exercise hardware fully."
    exit 1
  fi
}

# Tell the operator how to install dependencies based on the package manager detected.
install_hint(){
  if command -v dnf >/dev/null 2>&1; then
    echo "dnf install stress memtester fio smartmontools"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum install stress memtester fio smartmontools"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt-get install stress memtester fio smartmontools"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper install stress memtester fio smartmontools"
  else
    echo "<your package manager> install stress memtester fio smartmontools"
  fi
}

check_commands(){
  local missing=""
  local cmds=("$@")
  [[ ${#cmds[@]} -eq 0 ]] && cmds=(stress memtester fio)
  # Collect every command we rely on for the selected mode(s).
  for cmd in "${cmds[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      if [[ -z "$missing" ]]; then
        missing="$cmd"
      else
        missing="$missing $cmd"
      fi
    fi
  done
  if [[ -n "$missing" ]]; then
    local hint
    hint=$(install_hint)
    err "Missing required tools: $missing"
    echo "Install them first, e.g. '$hint'." >&2
    exit 1
  fi
  command -v smartctl >/dev/null 2>&1 || warn "smartctl not found; SMART data will be skipped."
}

# Remove the provided tooling via the detected package manager (best effort).
uninstall_tools(){
  local cmds=("$@")
  [[ ${#cmds[@]} -eq 0 ]] && return 0

  local pkg_cmd=()
  if command -v dnf >/dev/null 2>&1; then
    pkg_cmd=(dnf remove -y)
  elif command -v yum >/dev/null 2>&1; then
    pkg_cmd=(yum remove -y)
  elif command -v apt-get >/dev/null 2>&1; then
    pkg_cmd=(apt-get remove -y)
  elif command -v zypper >/dev/null 2>&1; then
    pkg_cmd=(zypper remove -y)
  else
    warn "No supported package manager found; remove ${cmds[*]} manually if desired."
    return 0
  fi

  local uninstall_list=()
  for cmd in "${cmds[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      uninstall_list+=("$cmd")
    fi
  done
  if [[ ${#uninstall_list[@]} -eq 0 ]]; then
    log "Requested uninstall but none of the tools (${cmds[*]}) are present."
    return 0
  fi

  log "Removing burn-in tools: ${uninstall_list[*]}"
  set +e
  "${pkg_cmd[@]}" "${uninstall_list[@]}"
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    warn "Tool removal failed (exit $rc)."
  else
    ok "Tool removal completed."
  fi
}

cpu_cores(){
  if command -v nproc >/dev/null 2>&1; then
    nproc
  else
    awk '/^processor/{cores++} END{print cores?cores:1}' /proc/cpuinfo
  fi
}

ram_total_mb(){
  free -m | awk '/Mem:/{print $2}'
}

# Prefer MemAvailable so we know how much headroom is left for stress/memtester.
ram_available_mb(){
  local avail=""
  if [[ -r /proc/meminfo ]]; then
    avail=$(awk '/MemAvailable:/ {printf "%d\n", $2/1024; exit}' /proc/meminfo 2>/dev/null || true)
  fi
  if [[ -z "$avail" ]]; then
    avail=$(free -m | awk '/Mem:/ {print ($7 && $7 !~ /-/)?$7:$4}')
  fi
  echo "${avail:-0}"
}

# Clamp requested RAM usage to what is actually free, keeping a reserve for the OS.
adjust_ram_target_mb(){
  local desired_mb=$1
  local available_mb=$2
  local label=$3
  local headroom=$(( available_mb - RAM_RESERVE_MB ))

  if (( headroom <= 0 )); then
    warn "$label skipped; available RAM (${available_mb} MB) is below reserve (${RAM_RESERVE_MB} MB)."
    echo 0
    return
  fi

  if (( desired_mb > headroom )); then
    warn "$label requested ${desired_mb} MB but only ${headroom} MB free (reserve ${RAM_RESERVE_MB} MB); clamping."
    desired_mb=$headroom
  fi

  if (( desired_mb < RAM_MIN_ALLOC_MB )); then
    warn "$label target ${desired_mb} MB below minimum (${RAM_MIN_ALLOC_MB} MB); skipping."
    echo 0
    return
  fi

  echo "$desired_mb"
}

smart_summary(){
  if command -v smartctl >/dev/null 2>&1; then
    local disk=${1:-}
    [[ -b $disk ]] || return 0
    # Capture the SMART health snapshot alongside the fio logs.
    smartctl -H "$disk" 2>/dev/null | tee "$LOG_DIR/smart-${disk##*/}.log" || warn "smartctl failed for $disk"
  fi
}

run_with_log(){
  local name=$1; shift
  local log_file="$LOG_DIR/$name.log"
  log "Starting $name"
  : >"$log_file"
  set +e
  "$@" > >(tee "$log_file") 2>&1
  local rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    ok "$name completed"
  else
    err "$name failed (exit $rc) – see $LOG_DIR/$name.log"
    return $rc
  fi
}

cleanup(){
  rm -f "$FIO_FILE"
}
trap cleanup EXIT

usage(){
  cat <<'EOF'
Usage: rp-burnin.sh [mode]

Modes:
  all        Run every test (default)
  cpu        CPU stress only
  ram        RAM stress (stress --vm) only
  memtester  RAM integrity (memtester) only
  disk       Disk / IO stress (fio) only

Options:
  -u, --uninstall-tools  Remove the required packages after the run
  -h, --help             Show this help
EOF
}

main(){
  local mode=all
  local uninstall_after=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      all|cpu|ram|memtester|disk)
        mode="$1"
        ;;
      --uninstall-tools|-u)
        uninstall_after=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: $1"
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  local run_cpu=0 run_ram=0 run_mem=0 run_disk=0
  case "$mode" in
    all)
      run_cpu=1
      run_ram=1
      run_mem=1
      run_disk=1
      ;;
    cpu) run_cpu=1 ;;
    ram) run_ram=1 ;;
    memtester) run_mem=1 ;;
    disk) run_disk=1 ;;
  esac

  require_root
  local required_cmds=()
  local unique_cmds=()
  (( run_cpu || run_ram )) && required_cmds+=("stress")
  (( run_mem )) && required_cmds+=("memtester")
  (( run_disk )) && required_cmds+=("fio")
  # Deduplicate required commands so we only probe each tool once.
  if [[ ${#required_cmds[@]} -gt 0 ]]; then
    local seen=""
    for cmd in "${required_cmds[@]}"; do
      if [[ " $seen " != *" $cmd "* ]]; then
        unique_cmds+=("$cmd")
        seen+=" $cmd"
      fi
    done
    check_commands "${unique_cmds[@]}"
  else
    err "No test modes selected."
    exit 1
  fi

  local cores total_ram vm_target_mb memtester_target_mb
  cores=$(cpu_cores)
  total_ram=$(ram_total_mb)
  vm_target_mb=$(( total_ram * RAM_STRESS_PCT / 100 ))
  memtester_target_mb=$(( total_ram * MEMTEST_PCT / 100 ))
  vm_target_mb=$(( vm_target_mb * RAM_TARGET_SCALE_PCT / 100 ))
  memtester_target_mb=$(( memtester_target_mb * RAM_TARGET_SCALE_PCT / 100 ))
  local initial_available
  initial_available=$(ram_available_mb)

  # Announce upfront what the run parameters look like for quick operator checks.
  log "CPU cores: $cores"
  log "Total RAM: ${total_ram} MB"
  log "stress --vm-bytes target: ${vm_target_mb}M"
  log "memtester target: ${memtester_target_mb} MB (passes: $MEMTEST_PASSES)"
  log "RAM workload scale: ${RAM_TARGET_SCALE_PCT}%"
  log "Currently available RAM: ${initial_available} MB (reserve ${RAM_RESERVE_MB} MB)"
  log "fio target file: $FIO_FILE (${FIO_SIZE}, runtime ${FIO_RUNTIME}s, engine ${FIO_IOENGINE})"

  log "Selected mode: $mode"

  # Optional SMART snapshot (best-effort, first SATA disk)
  local disk
  disk=$(ls /dev/sd[a-z] 2>/dev/null | head -n1 || true)
  if (( run_disk )); then
    [[ -n $disk ]] && smart_summary "$disk"
  fi

  local overall_rc=0

  if (( run_cpu )); then
    # CPU stress (integer + matrix workloads)
    run_with_log cpu-stress \
      stress --cpu "$cores" --timeout "${CPU_DURATION}s" || overall_rc=1
  fi

  if (( run_ram )); then
    # RAM pressure using stress workers
    local current_avail ram_target_mb ram_effective_mb
    current_avail=$(ram_available_mb)
    ram_effective_mb=$(adjust_ram_target_mb "$vm_target_mb" "$current_avail" "RAM stress")
    if (( ram_effective_mb == 0 )); then
      warn "Skipping RAM stress due to insufficient available memory."
    else
      log "RAM stress allocation: ${ram_effective_mb} MB (available ${current_avail} MB)"
      run_with_log ram-stress \
        stress --vm 2 --vm-bytes "${ram_effective_mb}M" --vm-keep --timeout "${RAM_DURATION}s" || overall_rc=1
    fi
  fi

  if (( run_mem )); then
    # RAM integrity via memtester
    local current_avail mem_target_mb mem_effective_mb
    current_avail=$(ram_available_mb)
    mem_effective_mb=$(adjust_ram_target_mb "$memtester_target_mb" "$current_avail" "memtester")
    if (( mem_effective_mb == 0 )); then
      warn "Skipping memtester due to insufficient available memory."
    else
      log "memtester allocation: ${mem_effective_mb} MB (available ${current_avail} MB)"
      run_with_log memtester \
        memtester "${mem_effective_mb}M" "$MEMTEST_PASSES" || overall_rc=1
    fi
  fi

  if (( run_disk )); then
    # Disk / IO stress
    run_with_log fio \
      fio --name=rp_burnin --filename="$FIO_FILE" --size="$FIO_SIZE" \
          --ioengine="$FIO_IOENGINE" --direct=1 --rw=randrw --rwmixread=60 \
          --bs=4k --numjobs=2 --iodepth=16 --runtime="$FIO_RUNTIME" --time_based=1 --group_reporting || overall_rc=1
  fi

  if (( run_disk )); then
    [[ -n $disk ]] && smart_summary "$disk"
  fi

  if [[ $overall_rc -eq 0 ]]; then
    ok "Burn-in completed successfully. Logs in $LOG_DIR"
  else
    err "Burn-in encountered failures. Review logs in $LOG_DIR"
  fi

  if (( uninstall_after )); then
    uninstall_tools "${unique_cmds[@]}"
  fi
  exit "$overall_rc"
}

main "$@"
