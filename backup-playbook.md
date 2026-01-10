# HA Backup Playbook (LVM Snapshots + Clonezilla)

> Primary reference: [Rocket Pool Backups Guide](https://docs.rocketpool.net/guides/node/backups). Rocket Pool explicitly recommends backing up Execution client chain data via `rocketpool service export-eth1-data`; this playbook layers LVM filesystem snapshots and periodic Clonezilla images around that workflow.

## Goal
Preserve fast-restore images for both Rocket Pool nodes without jeopardizing validator availability. Routine LVM snapshots capture OS + Docker volumes with minimal downtime, while quarterly Clonezilla images provide bare-metal recovery. Execution chain data exports remain the authoritative method for client-specific backups per the official docs.

## Prerequisites
- Debian 13 nodes with LVM-managed root volumes (confirmed via `lsblk -f`).
- External storage mounted at `/mnt/backups` (adjust paths below) with ≥2× the root LV size available.
- `lvm2`, `rsync`, `gzip`, `rocketpool` CLI, and `Clonezilla` live media available.
- Maintenance window or standby node ready; avoid snapshotting the active validator during critical duties.

## Workflow Summary
1. **Weekly (per node while standby):** Use `scripts/lvm-snapshot-backup.sh` to capture an LVM snapshot and mirror it to external storage. This freezes the filesystem at a point in time and copies only the delta since the previous run.
2. **Monthly (active node):** Run `rocketpool service export-eth1-data /mnt/backups/eth1/<node>` immediately after the LVM snapshot. This follows Rocket Pool guidance for execution-layer resilience.
3. **Quarterly:** Boot Clonezilla, image the full OS disk to offline media, and verify the image hash. This guards against LVM metadata loss or catastrophic disk failure.
4. **After Any Restore Drill:** Update `node00x-config.txt` via `./scripts/update-config.sh node00x` so current disk topology is documented.

## Routine LVM Snapshot Procedure
**Purpose:** Capture a consistent copy of `/` without stopping Docker longer than necessary. Script defaults are safe for both nodes.

### Steps
1. Ensure `/mnt/backups` is mounted and writable.
2. On the node you are snapshotting (preferably the standby):
   ```bash
   sudo ./scripts/lvm-snapshot-backup.sh \
     --destination /mnt/backups/os-images \
     --size 40G \
     --label weekly
   ```
   - `--size` should exceed expected churn between creation and merge. 40G is safe for 2–3 hours of writes.
   - Add `--quiesce` when running on the active node during low-duty windows; this stops the Rocket Pool stack for the brief moment it takes to create the snapshot, then restarts it automatically.
3. (Optional) Immediately export execution data per docs:
   ```bash
   rocketpool service export-eth1-data /mnt/backups/eth1/node001
   ```
4. Confirm copy completion with `ls /mnt/backups/os-images/$HOSTNAME/` and record the snapshot ID in the maintenance log.

### Validation
- `lvdisplay` shows no leftover snapshots.
- `rsync` exit code 0 and destination folder contains current timestamp.
- `rocketpool service status` reports all containers `Up` (if `--quiesce` used).

### Rollback
If the snapshot job fails mid-run:
1. Remove stale mounts: `sudo umount /mnt/lvm-snap-*`.
2. Drop dangling snapshots: `sudo lvremove -f /dev/<vg>/<snap>`.
3. Rerun the script after resolving disk-space or connectivity issues.

## Clonezilla Baseline Procedure
**Purpose:** Capture full-disk image (partition table + LUKS headers + LVM metadata) for quarterly restore points.

### Steps
1. Schedule maintenance—best on the standby node or during a validator lull.
2. Shut down the node cleanly: `sudo shutdown -h now`.
3. Boot from Clonezilla USB (use UEFI mode, no secure boot).
4. Choose `device-image` → `local_dev`, mount the external disk, and target `/<backups>/<node>/clonezilla`.
5. Select `savedisk`, include the entire OS drive (e.g., `nvme0n1`). Enable `-j2 -zstd` for faster compression.
6. After imaging, Clonezilla prompts to verify; accept (`-sc`).
7. Shutdown, remove media, boot Debian normally.
8. Log the image hash stored under `clonezilla/ocs-srv-checksum.txt`.

### Validation
- `md5sum`/`sha256sum` files exist for each image chunk.
- Debian boots without `fsck` errors post-Clonezilla cycle.

### Rollback
- If verification fails, rerun Clonezilla immediately; do not delete the previous known-good image until a fresh verified copy exists.

## Scheduling Matrix
| Task | Node | Frequency | Target Duration |
| --- | --- | --- | --- |
| LVM snapshot + rsync | Standby weekly, Active monthly | 20–30 min |
| `export-eth1-data` | Active monthly, Standby quarterly | 15–20 min |
| Clonezilla full image | Alternating nodes quarterly | 1–2 h |

## Recovery Quick Reference
1. **OS-level incident:**
   - Boot rescue media, unlock LUKS if needed, mount backup destination.
   - `rsync` the latest snapshot back to the root LV or perform `lvconvert --merge <snap>` if still present locally.
2. **Execution client corruption:**
   - Follow Rocket Pool doc: `rocketpool service import-eth1-data /mnt/backups/eth1/<node>`.
3. **Bare-metal loss:**
   - Restore via Clonezilla image, then import the freshest execution backup, then refresh configs.

## Reporting
After each backup window:
- Update `maintenance-calendar.md` with snapshot IDs, Clonezilla image hashes, and any anomalies.
- Run `./scripts/update-config.sh node00x` so disk topology (now including `lsblk` output) is archived in `node00x-config.txt`.
