# Adding PCIe NVMe Storage to node002

> **Purpose:** Detailed guide for installing PCIe-based NVMe drive to expand execution client storage  
> **Target Node:** node002  
> **Last Updated:** 2026-01-13  
> **Status:** Pre-installation (hardware not yet purchased)

---

## Overview

**Problem:**
- node002 execution disk at 75% capacity (1.3TB / 1.8TB)
- Mainnet Nethermind expected to grow to 1.5TB+ when fully synced
- Risk of running out of space during mainnet migration

**Solution:**
- Add 2TB NVMe drive via PCIe Gen 4 x4 adapter in available PCIEX16_2 slot
- Extend existing ethereum-vg LVM volume group
- Expand ethereum-lv logical volume to span both disks
- Total capacity: ~4TB (1.8TB existing + 2TB new)

**Benefits:**
- No data migration required (LVM extension is non-destructive)
- Safer than replacing existing drive
- Cheaper than upgrading to 4TB drive
- Can be done while node is in standby mode

---

## Prerequisites

### Hardware Requirements
- ✅ M.2 NVMe to PCIe Gen 4 x4 adapter
- ✅ 2TB NVMe SSD (Gen 3 or Gen 4)
- ✅ Screwdriver for PCIe card installation
- ✅ Available PCIe slot: PCIEX16_2 (confirmed via `dmidecode`)

### Software/System Requirements
- ✅ node002 in **standby mode** (no active validators)
- ✅ LVM tools installed: `lvm2` package
- ✅ Backup of current configuration (per [backup-playbook.md](backup-playbook.md))

### Pre-Installation Verification
Run these commands to capture baseline state:

```bash
# Current disk layout
df -h > ~/pre-disk-add-df.txt
lsblk > ~/pre-disk-add-lsblk.txt

# Current LVM state
sudo pvs > ~/pre-disk-add-pvs.txt
sudo vgs > ~/pre-disk-add-vgs.txt
sudo lvs > ~/pre-disk-add-lvs.txt

# Current PCIe devices
lspci -nn > ~/pre-disk-add-lspci.txt

# Current NVMe devices
sudo nvme list > ~/pre-disk-add-nvme.txt
```

---

## Part 1: Hardware Installation

### Step 1: Shut Down Services and System

```bash
# Stop all Rocket Pool services
rocketpool service stop

# Verify all containers stopped
docker ps

# Shut down the system
sudo shutdown -h now
```

### Step 2: Physical Installation

1. **Disconnect power** from node002
2. **Ground yourself** (touch metal chassis) to prevent ESD damage
3. **Open the case** and locate PCIEX16_2 slot
   - Per `dmidecode`: Slot 1, PCIe x4, second from top (if x16 slots are stacked)
4. **Remove slot cover** if present
5. **Install PCIe adapter card** into PCIEX16_2
   - Align card with slot
   - Press firmly until fully seated
   - Secure with screw to chassis
6. **Install NVMe drive into adapter**
   - Remove heatsink from adapter if present
   - Insert NVMe drive into M.2 slot at 30° angle
   - Press down and secure with screw
   - Reinstall heatsink if provided
7. **Close case** and reconnect power

### Step 3: Boot and Verify Detection

```bash
# Boot the system (power on)

# After boot, log in and verify new drive is detected
sudo nvme list

# Expected output: 3 NVMe devices
# - nvme0n1 (existing Samsung, 512GB)
# - nvme1n1 (existing Samsung, 2TB)
# - nvme2n1 (NEW drive, 2TB) <-- Look for this

# Verify PCIe slot detection
lspci -nn | grep -i nvme

# Expected: 3 NVMe controllers now listed

# Check dmesg for any errors
dmesg | grep -i nvme | tail -20
```

**If new drive NOT detected:**
- Check adapter is fully seated in PCIe slot
- Check NVMe drive is fully inserted in adapter M.2 slot
- Check BIOS settings for PCIe slot enabling (rarely needed)
- Reboot and check again

---

## Part 2: LVM Configuration

### Step 4: Identify New Drive

```bash
# List all block devices
lsblk

# Expected output shows new /dev/nvme2n1 (or similar)
# Verify it's the correct size (~2TB) and has NO partitions

# Double-check via fdisk
sudo fdisk -l /dev/nvme2n1

# Should show: "Disk /dev/nvme2n1: 1.86 TiB" (or similar)
# Should NOT show any partitions yet
```

**CRITICAL WARNING:** Make absolutely certain you've identified the NEW drive. Do NOT proceed if uncertain.

### Step 5: Create Physical Volume on New Drive

```bash
# Create LVM physical volume on the entire new drive
sudo pvcreate /dev/nvme2n1

# Expected output:
# Physical volume "/dev/nvme2n1" successfully created.

# Verify physical volume created
sudo pvs

# Expected output should now show:
# /dev/nvme2n1   lvm2  ---  <1.86t <1.86t (all free)
```

### Step 6: Extend Volume Group

```bash
# Add the new physical volume to ethereum-vg
sudo vgextend ethereum-vg /dev/nvme2n1

# Expected output:
# Volume group "ethereum-vg" successfully extended

# Verify volume group size increased
sudo vgs

# Expected: ethereum-vg should now show ~3.7TB total size
# (1.8TB existing + 2TB new = ~3.7TB after formatting overhead)
```

### Step 7: Extend Logical Volume

```bash
# Extend the ethereum-lv to use all available space
sudo lvextend -l +100%FREE /dev/ethereum-vg/ethereum-lv

# Expected output:
# Size of logical volume ethereum-vg/ethereum-lv changed from 1.82 TiB to 3.68 TiB
# (sizes will vary based on actual drive capacities)

# Verify logical volume expanded
sudo lvs

# Expected: ethereum-lv should show ~3.7TB size
```

### Step 8: Resize Filesystem

```bash
# Check current filesystem
df -h /mnt/ethereum

# Resize the ext4 filesystem to fill the expanded LV
sudo resize2fs /dev/ethereum-vg/ethereum-lv

# Expected output:
# Resizing the filesystem on /dev/ethereum-vg/ethereum-lv to XXXXXXXXX blocks.
# The filesystem on /dev/ethereum-vg/ethereum-lv is now XXXXXXXXX blocks long.

# Verify new filesystem size
df -h /mnt/ethereum

# Expected: Should show ~3.6TB total size (accounting for filesystem overhead)
```

**Success Check:**
```bash
# Before: /dev/mapper/ethereum--vg-ethereum--lv  1.8T  1.3T  440G  75% /mnt/ethereum
# After:  /dev/mapper/ethereum--vg-ethereum--lv  3.6T  1.3T  2.2T  38% /mnt/ethereum
```

---

## Part 3: Verification and Service Restart

### Step 9: Verify LVM Spanning

```bash
# Show which physical volumes the LV is using
sudo lvs -o +devices

# Expected output should show ethereum-lv spans TWO devices:
# /dev/nvme1n1(0)    <-- existing disk
# /dev/nvme2n1(0)    <-- new disk

# Verify LVM structure
sudo vgdisplay -v ethereum-vg

# Should show 2 physical volumes in the VG
```

### Step 10: Test Disk Performance (Optional)

```bash
# Quick write test to verify new disk performance
sudo dd if=/dev/zero of=/mnt/ethereum/testfile bs=1G count=5 oflag=direct

# Expected: 1-2 GB/s write speed (varies by drive)

# Clean up test file
sudo rm /mnt/ethereum/testfile
```

### Step 11: Restart Services

```bash
# Start Rocket Pool services
rocketpool service start

# Verify all containers started
docker ps

# Check service status
rocketpool service status

# Monitor logs for any errors
docker logs rocketpool_eth1 --tail 50
docker logs rocketpool_eth2 --tail 50
```

### Step 12: Monitor Execution Client Sync

```bash
# Watch Nethermind sync status
docker logs rocketpool_eth1 -f

# Check disk usage growth over time
watch -n 300 'df -h /mnt/ethereum'

# Expected: Disk usage will continue growing as sync progresses
# But now you have ~2.2TB free instead of ~440GB
```

---

## Part 4: Post-Installation Documentation

### Step 13: Update Configuration Files

```bash
# Regenerate node configuration
cd ~/staking
./scripts/update-config.sh node002

# Review updated configuration
cat node002-config.txt

# Verify "Storage Layout" section shows expanded disk
```

### Step 14: Document Changes

Update the following files:

1. **[operational-tasks.md](operational-tasks.md)**
   - Mark "Install and configure additional storage" as ✅ Done
   - Move to Completed Tasks section

2. **[change-log.md](change-log.md)**
   - Add entry documenting the hardware addition
   - Include before/after disk sizes
   - Note any issues encountered

3. **[operations.md](operations.md)**
   - Update "Storage & Pruning" section if needed
   - Document new total capacity

### Step 15: Create Backup Record

```bash
# Capture final state for records
df -h > ~/post-disk-add-df.txt
sudo pvs > ~/post-disk-add-pvs.txt
sudo vgs > ~/post-disk-add-vgs.txt
sudo lvs > ~/post-disk-add-lvs.txt
lsblk > ~/post-disk-add-lsblk.txt

# Copy to backup USB if desired
```

---

## Troubleshooting

### Issue: New drive not detected after boot

**Diagnostics:**
```bash
lspci -nn | grep -i nvme
dmesg | grep -i nvme
sudo nvme list
```

**Possible Causes:**
1. PCIe adapter not fully seated → Reseat the card
2. NVMe drive not fully inserted in adapter → Check M.2 connection
3. Incompatible adapter/drive → Verify adapter supports NVMe (not SATA M.2)
4. PCIe slot disabled in BIOS → Check BIOS settings

### Issue: pvcreate fails with "Device /dev/nvme2n1 not found"

**Diagnostics:**
```bash
ls -la /dev/nvme*
lsblk
```

**Solution:** Use exact device name from `lsblk` output (might be nvme3n1 or different number)

### Issue: vgextend fails with "Physical volume not found"

**Diagnostics:**
```bash
sudo pvs
sudo pvscan
```

**Solution:** Verify `pvcreate` completed successfully. Rerun if needed.

### Issue: resize2fs fails

**Diagnostics:**
```bash
sudo e2fsck -f /dev/ethereum-vg/ethereum-lv
```

**Solution:** Run filesystem check, then retry resize2fs

### Issue: Services won't start after disk changes

**Diagnostics:**
```bash
docker ps -a
docker logs rocketpool_eth1
ls -la /mnt/ethereum
```

**Possible Causes:**
1. Filesystem not mounted → Check `df -h`
2. Permissions changed → Run `sudo chown -R 1000:1000 /mnt/ethereum`
3. Docker can't access mount → Restart Docker: `sudo systemctl restart docker`

---

## Rollback Procedure (If Needed)

**If you need to remove the new disk for any reason:**

⚠️ **WARNING:** Only possible if ethereum-lv hasn't written data to the new disk yet (i.e., immediately after extending).

```bash
# DO NOT attempt rollback if execution client has been running!
# Data will be striped across both disks - removing one will cause data loss.

# If you must rollback (within first hour, before significant writes):
sudo lvreduce -L 1.8T /dev/ethereum-vg/ethereum-lv
sudo resize2fs /dev/ethereum-vg/ethereum-lv 1.8T
sudo vgreduce ethereum-vg /dev/nvme2n1
sudo pvremove /dev/nvme2n1
# Then shut down and physically remove hardware
```

**Better approach:** If unsure, don't remove the disk. It's not causing harm even if unused.

---

## Success Criteria

After completing this procedure, you should have:

- ✅ New NVMe drive detected: `sudo nvme list` shows 3 drives
- ✅ Physical volume created: `sudo pvs` shows `/dev/nvme2n1`
- ✅ Volume group extended: `sudo vgs` shows ethereum-vg at ~3.7TB
- ✅ Logical volume extended: `sudo lvs` shows ethereum-lv at ~3.7TB
- ✅ Filesystem resized: `df -h /mnt/ethereum` shows ~3.6TB total
- ✅ LV spans both disks: `sudo lvs -o +devices` shows two PVs
- ✅ Services running: `docker ps` shows all rocketpool containers
- ✅ No errors in logs: `docker logs rocketpool_eth1` clean
- ✅ Configuration updated: `node002-config.txt` reflects new disk size
- ✅ Documentation updated: change-log.md and operational-tasks.md

---

## Reference Information

### Current Hardware State (Pre-Installation)
```
Motherboard: Intel Z370 chipset
Available Slot: PCIEX16_2 (PCIe Gen 4 x4, ~8GB/s bandwidth)
Existing Drives:
  - nvme0n1: 512GB (Samsung 980 Pro) - OS/root
  - nvme1n1: 2TB (Samsung 980 Pro) - ethereum-vg
```

### Expected Hardware State (Post-Installation)
```
Motherboard: Intel Z370 chipset
Used Slot: PCIEX16_2 (PCIe adapter + NVMe)
Drives:
  - nvme0n1: 512GB (Samsung 980 Pro) - OS/root
  - nvme1n1: 2TB (Samsung 980 Pro) - ethereum-vg (original)
  - nvme2n1: 2TB (New NVMe) - ethereum-vg (added)
Total ethereum-vg capacity: ~3.7TB
```

### Estimated Timeline
- Hardware installation: 15-20 minutes
- LVM configuration: 10-15 minutes
- Service restart & verification: 10-15 minutes
- Documentation: 10-15 minutes
- **Total estimated time:** 45-65 minutes

### Related Documentation
- [operational-tasks.md](operational-tasks.md) - Task tracking
- [node002-config.txt](node002-config.txt) - Current configuration
- [operations.md](operations.md) - Operational procedures
- [backup-playbook.md](backup-playbook.md) - Backup procedures
- [node-failover-runbook.md](node-failover-runbook.md) - Service management

---

## Notes

- **LVM striping:** By default, `lvextend` will use linear allocation (not striped). This means data is written to the first PV until full, then to the second PV. Performance impact is minimal for this use case.
- **TRIM support:** Modern NVMe drives support TRIM. LVM passes through TRIM commands automatically with default settings.
- **Monitoring:** After installation, monitor disk usage growth via Grafana or `df -h` to ensure adequate headroom.
- **Future expansion:** If you ever need MORE space, you can repeat this process with another PCIe slot (PCIEX1_1 or PCIEX1_2 available, though x1 slots have lower bandwidth).

---

*Last updated: 2026-01-13*
