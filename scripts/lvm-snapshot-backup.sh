#!/bin/bash
# LVM snapshot + rsync helper for Rocket Pool nodes
# Creates a read-only snapshot of the root LV, copies it to external storage,
# and cleans up. Works for any node that exposes its root via LVM.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: sudo ./lvm-snapshot-backup.sh --destination /mnt/backups/os-images [options]
Options:
  --destination <path>   Target directory for rsync copy (required)
  --lv <device>          Source LV (default: current / mount, e.g. /dev/mapper/node001--vg-root)
  --size <value>         Snapshot size (default: 20G)
  --label <string>       Friendly label appended to snapshot + folder names
  --quiesce              Temporarily stop the Rocket Pool stack during snapshot create
  --help                 Show this message
EOF
}

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo "This script must run as root (sudo)." >&2
        exit 1
    fi
}

check_cmds() {
    for cmd in lvs lvcreate lvremove mount umount rsync date hostname; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Missing dependency: $cmd" >&2
            exit 1
        fi
    done
}

stop_stack() {
    if [[ "$QUIESCE" == "true" ]]; then
        if command -v rocketpool >/dev/null 2>&1; then
            rocketpool service stop >/tmp/rp-stop.log 2>&1 || true
        fi
    fi
}

start_stack() {
    if [[ "$QUIESCE" == "true" ]]; then
        if command -v rocketpool >/dev/null 2>&1; then
            rocketpool service start >/tmp/rp-start.log 2>&1 || true
        fi
    fi
}

cleanup() {
    set +e
    if mountpoint -q "$SNAP_MOUNT"; then
        umount "$SNAP_MOUNT"
    fi
    if [[ -n "$SNAP_DEVICE" && -e "$SNAP_DEVICE" ]]; then
        lvremove -f "$SNAP_DEVICE" >/dev/null 2>&1
    fi
    start_stack
}

DEST=""
SOURCE_LV=$(findmnt -no SOURCE / || true)
SNAP_SIZE="20G"
LABEL=""
QUIESCE="false"

if [[ -z "$SOURCE_LV" ]]; then
    echo "Unable to detect root LV. Use --lv to specify it." >&2
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --destination)
            DEST="$2"; shift 2 ;;
        --lv)
            SOURCE_LV="$2"; shift 2 ;;
        --size)
            SNAP_SIZE="$2"; shift 2 ;;
        --label)
            LABEL="$2"; shift 2 ;;
        --quiesce)
            QUIESCE="true"; shift 1 ;;
        --help)
            usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1 ;;
    esac
done

if [[ -z "$DEST" ]]; then
    echo "--destination is required." >&2
    usage
    exit 1
fi

require_root
check_cmds

if [[ ! -d "$DEST" ]]; then
    echo "Destination $DEST not found." >&2
    exit 1
fi

VG_NAME=$(lvs --noheadings -o vg_name "$SOURCE_LV" | awk '{print $1}')
LV_NAME=$(lvs --noheadings -o lv_name "$SOURCE_LV" | awk '{print $1}')

if [[ -z "$VG_NAME" || -z "$LV_NAME" ]]; then
    echo "Unable to parse VG/LV names from $SOURCE_LV" >&2
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAP_NAME="${LV_NAME}-snap-${TIMESTAMP}${LABEL:+-$LABEL}"
SNAP_DEVICE="/dev/${VG_NAME}/${SNAP_NAME}"
SNAP_MOUNT="/mnt/${SNAP_NAME}"
TARGET_DIR="${DEST%/}/$(hostname)/${SNAP_NAME}"

trap cleanup EXIT

mkdir -p "$SNAP_MOUNT"
mkdir -p "$TARGET_DIR"

sync
stop_stack

lvcreate -L "$SNAP_SIZE" -s -n "$SNAP_NAME" "$SOURCE_LV" >/dev/null

mount -o ro "$SNAP_DEVICE" "$SNAP_MOUNT"

rsync -aHAX --numeric-ids --delete "$SNAP_MOUNT"/ "$TARGET_DIR"/

echo "Snapshot copied to $TARGET_DIR"

cleanup
trap - EXIT
start_stack

# Remove mount dir once everything is done
rmdir "$SNAP_MOUNT" 2>/dev/null || true
