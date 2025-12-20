# Rocket Pool Operations Guide

> **Purpose:** Operational procedures for managing a two-node HA Rocket Pool setup  
> **Network:** Hoodi Test Network  
> **Last Updated:** 2025-12-20

---

## Architecture Overview

### Current Configuration
- **Active Node:** node002 (AMD Ryzen 7 5800X, Nethermind + Lighthouse)
- **Standby Node:** node001 (Intel i5-1235U, Reth + Lighthouse)
- **Network:** Hoodi Test Network
- **Rocket Pool Version:** 1.18.6
- **Active Minipools:** 1 (on node002)

### HA Strategy
- **Wallet:** Single wallet initialized only on active node (node002)
- **Failover Type:** Manual switchover (not automatic)
- **Fallback Clients:** node002 → node001 (http://192.168.60.101:8545, http://192.168.60.101:5052)
- **Client Diversity:** 
  - node001: Reth (execution) + Lighthouse (consensus)
  - node002: Nethermind (execution) + Lighthouse (consensus)

### Key Addresses
- **Node Address:** `0x985b1E3e49Fa0F6c5d7483100a616b84C723Bc7F`
- **Withdrawal Address:** `0x6260D6583B82BcF4Fc2b9E094110171535a241Fe`
- **Minipool Address:** `0xf5c4243fCCc3Eb6689F4a382b2d389732406B4CA`

---

## Security Configuration

### Encrypted Storage (Hardware Keypad USB)

**Critical:** The Rocket Pool data directory is stored on a LUKS-encrypted USB thumbdrive with physical keypad authentication.

**Important Operational Impact:**
- **Before server shutdown:** No special action needed
- **After server startup:** USB must be unlocked via physical keypad BEFORE services can start
- **Auto-mount configured:** Once USB is unlocked, systemd automatically mounts it

#### Physical Setup
- **Device:** Encrypted USB thumbdrive with physical keypad
- **Mount Point:** `/mnt/validator_keys`
- **Data Location:** `/mnt/validator_keys/data` → symlinked to `~/.rocketpool/data`
- **Encryption:** LUKS with automatic unlock via keyfile (after physical unlock)

#### Boot Sequence
1. Server powers on
2. **YOU:** Unlock USB using physical keypad
3. Systemd service detects unlocked USB
4. Auto-mounts to `/mnt/validator_keys`
5. Rocket Pool services start automatically (symlink active)

#### Systemd Services
```bash
# Check if USB is unlocked and mounted
systemctl status validator-keys-unlock.service
systemctl status mnt-validator_keys.mount

# Verify mount
ls /mnt/validator_keys/data
ls -la ~/.rocketpool/data  # Should show symlink to /mnt/validator_keys/data
```

#### Recovery/Rebuild Procedure
If you need to rebuild the encrypted USB setup on a new node:

<details>
<summary>Click to expand full setup instructions</summary>

```bash
# Install cryptsetup package
sudo apt update
sudo apt install cryptsetup

# Get the UUID of your LUKS-encrypted USB partition (replace /dev/sdX1 with your actual device)
sudo cryptsetup luksUUID /dev/sdX1
# Copy this UUID - you'll need it below

# Create a secure keyfile for automatic unlock
sudo dd if=/dev/urandom of=/root/luks-keyfile bs=512 count=1
sudo chmod 400 /root/luks-keyfile

# Add the keyfile as an unlock method (you'll need your USB passphrase)
sudo cryptsetup luksAddKey /dev/sdX1 /root/luks-keyfile

# Create mount point
sudo mkdir -p /mnt/validator_keys

# Create systemd unlock service
sudo nano /etc/systemd/system/validator-keys-unlock.service
```

**File contents** (replace YOUR-ESCAPED-UUID and YOUR-UUID):
```ini
[Unit]
Description=Unlock Validator Keys USB
After=dev-disk-by\x2duuid-YOUR-ESCAPED-UUID.device
Requires=dev-disk-by\x2duuid-YOUR-ESCAPED-UUID.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/cryptsetup luksOpen UUID=YOUR-UUID validator_keys --key-file /root/luks-keyfile
ExecStop=/usr/sbin/cryptsetup luksClose validator_keys

[Install]
WantedBy=multi-user.target
```

**UUID Escaping:** Replace hyphens with `\x2d`  
Example: `388398aa-3125-4fb0-8f5b-9056ea5b8d39` → `388398aa\x2d3125\x2d4fb0\x2d8f5b\x2d9056ea5b8d39`

```bash
# Create systemd mount unit
sudo nano /etc/systemd/system/mnt-validator_keys.mount
```

**File contents:**
```ini
[Unit]
Description=Mount Validator Keys
After=validator-keys-unlock.service
Requires=validator-keys-unlock.service

[Mount]
What=/dev/mapper/validator_keys
Where=/mnt/validator_keys
Type=ext4
Options=defaults

[Install]
WantedBy=multi-user.target
```

```bash
# Enable services
sudo systemctl daemon-reload
sudo systemctl enable validator-keys-unlock.service
sudo systemctl enable mnt-validator_keys.mount

# Test before rebooting
sudo systemctl start validator-keys-unlock.service
sudo systemctl start mnt-validator_keys.mount
ls /mnt/validator_keys

# If successful, reboot to verify
sudo reboot
```

**After reboot, move Rocket Pool data:**
```bash
# 1. Stop Rocket Pool services
rocketpool service stop

# 2. Wait for complete shutdown
sleep 10

# 3. Move data folder to encrypted USB
sudo mv ~/.rocketpool/data /mnt/validator_keys/data

# 4. Create symbolic link
ln -s /mnt/validator_keys/data ~/.rocketpool/data

# 5. Verify symlink
ls -la ~/.rocketpool/data
# Should show: ~/.rocketpool/data -> /mnt/validator_keys/data

# 6. Reboot to test full boot sequence
sudo reboot

# 7. After reboot, verify and start
ls /mnt/validator_keys/data      # USB mounted
ls -la ~/.rocketpool/data        # Symlink valid
rocketpool service start
rocketpool service status
```

</details>

#### Troubleshooting

**Problem:** Services won't start after reboot
```bash
# Check if USB is mounted
mount | grep validator_keys

# If not mounted, check unlock service
systemctl status validator-keys-unlock.service
systemctl status mnt-validator_keys.mount

# Manually unlock if needed (USB must be physically unlocked first)
sudo cryptsetup luksOpen UUID=YOUR-UUID validator_keys --key-file /root/luks-keyfile
sudo mount /mnt/validator_keys
```

**Problem:** Symlink broken after moving data
```bash
# Remove bad symlink
rm ~/.rocketpool/data

# Recreate
ln -s /mnt/validator_keys/data ~/.rocketpool/data

# Verify
ls -la ~/.rocketpool/data
```

**Problem:** Forgot to unlock USB before booting
```bash
# 1. Unlock USB via physical keypad
# 2. Manually start mount services
sudo systemctl start validator-keys-unlock.service
sudo systemctl start mnt-validator_keys.mount
# 3. Start Rocket Pool
rocketpool service start
```

---

## Failover Procedures

**⚠️ CRITICAL: For detailed failover procedures, see [fail-over-guidance.md](fail-over-guidance.md)**

### Quick Reference
- **Emergency runbook:** fail-over-guidance.md
- **Key safety rule:** Wait 15+ minutes for missed attestations in FINALIZED epochs
- **Never:** Run validators on both nodes simultaneously
- **Always:** Test mnemonic recovery before starting failover
- **Commands:** `rocketpool wallet test-recovery`, `rocketpool wallet purge`, `rocketpool wallet recover`

### When to Trigger Failover
- Hardware failure on active node
- Network connectivity issues on active node
- Performance degradation requiring maintenance
- Planned maintenance/upgrades on active node

---

## Monitoring & Alerts

### Monitoring Setup
**Tools in use:**
- Grafana (port 3100 on both nodes)
- Prometheus (metrics collection)
- Node Exporter (system metrics)
- Alertmanager (configured on node002)
- Uptime Kuma (external ping monitoring → email alerts)
- Beaconcha.in Mobile App (validator performance & alerts)

**Alert Flow:**
1. **Rocket Pool Alerts:**
   - Alertmanager detects issue
   - Sends webhook to n8n: `https://automation.nearfaraway.com/webhook/ecb9d8bf-949a-4f16-945b-b09d6ec15cd2`
   - n8n workflow processes alert
   - Email sent to your inbox

2. **Node Availability Alerts:**
   - Uptime Kuma pings both nodes
   - If ping fails → email alert sent
   - Monitors node reachability/uptime

3. **Validator Performance Alerts:**
   - Beaconcha.in Mobile App
   - Push notifications for missed attestations, proposals, etc.
   - Real-time validator status monitoring

**Configured Alerts** (from user-settings.yml):
- Active Sync Committee
- Beacon/Execution Client Sync Complete
- Client Sync Status (both clients)
- Fee Recipient Changed
- Low Disk Space (Critical & Warning)
- Low ETH Balance (threshold: 0.05 ETH)
- Minipool Events (Balance Distributed, Bond Reduced, Promoted, Staked)
- OS Updates Available
- Rocket Pool Updates Available
- Governance Proposals (Recent & Upcoming)
- Upcoming Sync Committee

### Key Metrics to Watch
```bash
# Check on each node:
# 1. Attestation effectiveness - via Beaconcha.in dashboard or mobile app

# 2. Sync status
rocketpool service status

# 3. System resources
htop           # CPU/RAM
df -h          # Disk usage
```

### Beaconcha.in Monitoring
- **node001 machine name:** node01 (metrics sent to https://hoodi.beaconcha.in/api/v1/client/metrics)
- **node002 machine name:** node02 (metrics sent to https://hoodi.beaconcha.in/api/v1/client/metrics)
- **Mobile App:** Installed for push notifications and on-the-go monitoring
- **Validator tracking:** Beaconcha.in dashboard for attestation effectiveness and rewards

---

## Backup & Recovery

### What to Backup
1. **Rocket Pool Wallet**
   - Location: `~/.rocketpool/data/wallet`
   - **Backup Storage:** Pair of encrypted USB thumbdrives with physical keypads
   - **Security:** LUKS encryption + physical keypad unlock (offline storage)

2. **Validator Keys**
   - Currently on: node002 (active node)
   - **Backup Storage:** Same encrypted USB thumbdrives as wallet
   - **Sync Strategy:** Keys backed up to encrypted USBs, can be restored to either node during failover

3. **Configuration Files**
   - `~/.rocketpool/user-settings.yml`
   - **Backup Storage:** Same encrypted USB thumbdrives

### Backup Strategy
- **Primary Backup:** Encrypted USB thumbdrive #1 (physical keypad)
- **Secondary Backup:** Encrypted USB thumbdrive #2 (physical keypad) - redundancy
- **Storage Location:** Offline, secure location (not connected to nodes)
- **Update Frequency:** After any configuration changes or wallet updates

### Recovery Procedures

#### Recover from Wallet Backup
```bash
# 1. Unlock encrypted USB thumbdrive using physical keypad
# 2. Mount USB (adjust /dev/sdX as needed)
sudo cryptsetup luksOpen /dev/sdX backup_usb
sudo mount /dev/mapper/backup_usb /mnt/backup

# 3. Stop Rocket Pool services
rocketpool service stop

# 4. Restore wallet
sudo cp -r /mnt/backup/wallet ~/.rocketpool/data/

# 5. Restore configuration
sudo cp /mnt/backup/user-settings.yml ~/.rocketpool/

# 6. Verify permissions
sudo chown -R $(whoami):$(whoami) ~/.rocketpool/data/wallet

# 7. Unmount backup USB
sudo umount /mnt/backup
sudo cryptsetup luksClose backup_usb

# 8. Lock USB with physical keypad and store securely

# 9. Start services and verify
rocketpool wallet status
rocketpool service start
```

#### Rebuild Node from Scratch
```bash
# 1. Install Debian 13 and system updates
# 2. Set up encrypted USB for live data (see Security Configuration section)
# 3. Install Rocket Pool
# 4. Restore wallet and keys from backup USB (steps above)
# 5. Restore configuration files
# 6. Verify sync status before activating validator
# 7. Follow failover procedure if switching active node
```

---

## Routine Maintenance

### Monitoring Dashboard
- **Microsoft Surface** on desk showing Grafana dashboards for both nodes
- **node001 Grafana:** http://192.168.60.101:3100
- **node002 Grafana:** http://192.168.60.102:3100
- Displays OS and Rocket Pool update availability
- Alerts visible immediately when updates are available

### Daily Checks
- [ ] Verify both nodes are synced (via Surface/Grafana)
- [ ] Check attestation performance on Beaconcha.in mobile app
- [ ] Review alertmanager for any warnings (email alerts)

### Weekly Checks
- [ ] Review disk usage on both nodes
- [ ] Check for Rocket Pool updates (Grafana dashboard)
- [ ] Verify backup USB thumbdrives are accessible

### Update Strategy

**Important:** Automatic OS updates **disabled** due to previous service startup issues. All updates performed manually when Grafana shows availability.

**Update Order:**
1. **Update standby node (node001) first** - OS then Rocket Pool
2. **Verify standby is stable and services start correctly**
3. **Update active node (node002)** - OS then Rocket Pool
4. **No failover needed** - updates complete in <1 minute, acceptable downtime

#### OS Update Procedure
```bash
# Run on each node (standby first, then active)
sudo apt update
sudo apt dist-upgrade
sudo apt autoremove

# Check if reboot required
cat /var/run/reboot-required
# If file exists: reboot needed
# If "No such file or directory": no reboot needed

# If reboot required:
sudo reboot
# After reboot: unlock encrypted USB via physical keypad
# Verify services started: rocketpool service status
```

#### Rocket Pool Update Procedure
```bash
# Run on each node (standby first, then active)

# 1. Check current version
rocketpool service version

# 2. Stop services
rocketpool service stop

# 3. Download latest version
sudo wget https://github.com/rocket-pool/smartnode/releases/latest/download/rocketpool-cli-linux-amd64 -O ~/bin/rocketpool

# 4. Run installer
rocketpool service install -d

# 5. Review configuration changes (optional)
rocketpool service config
# Review Page shows what's new - make any necessary adjustments

# 6. Start services
rocketpool service start

# 7. Verify version updated
rocketpool service version
# Compare with version from step 1

# 8. Fix status display if needed
sudo apt update

# 9. Verify everything running
rocketpool service status
rocketpool node sync
```

#### Combined OS + Rocket Pool Update
```bash
# Update standby node (node001) first

# OS updates
sudo apt update
sudo apt dist-upgrade
sudo apt autoremove
cat /var/run/reboot-required

# If reboot required, do it now
# [sudo reboot, unlock USB, continue]

# Rocket Pool update
rocketpool service version  # Note current version
rocketpool service stop
sudo wget https://github.com/rocket-pool/smartnode/releases/latest/download/rocketpool-cli-linux-amd64 -O ~/bin/rocketpool
rocketpool service install -d
rocketpool service config  # Review changes
rocketpool service start
rocketpool service version  # Verify new version
sudo apt update  # Fix status display

# Verify standby is healthy
rocketpool service status
rocketpool node sync

# If standby is stable, repeat entire process on active node (node002)
```

---

## Network Configuration

### Internal Network
- **node001 IP:** 192.168.60.101
- **node002 IP:** 192.168.60.102
- **Network segment:** 192.168.60.0/24

### External Access
- **Shared External IP:** 158.140.242.211 (both nodes behind NAT)

### Port Forwarding (NAT)
**node001 (192.168.60.101):**
- **9001/TCP** → Consensus P2P (Lighthouse)
- **30303/TCP+UDP** → Execution P2P (Reth)
- **8001/UDP** → Lighthouse QUIC

**node002 (192.168.60.102):**
- **9002/TCP** → Consensus P2P (Lighthouse)
- **30304/TCP+UDP** → Execution P2P (Nethermind)
- **8002/UDP** → Lighthouse QUIC

### Internal Services (No External Access)
- **3100/TCP** - Grafana (internal monitoring only)
- **8545/TCP** - Execution client RPC (internal API)
- **5052/TCP** - Consensus client API (internal API)
- **SSH** - Custom port [Document your SSH port]

### Firewall Rules
**External (WAN) → Nodes:**
- Allow ports listed above for P2P connectivity
- Block all other inbound traffic

**Between Nodes (LAN):**
- node002 → node001: 8545/TCP, 5052/TCP (fallback clients)
- Allow all other internal 192.168.60.0/24 traffic

**Outbound:**
- Allow all (for updates, NTP, external RPC calls)

---

## Emergency Contacts & Resources

### Official Resources
- **Rocket Pool Docs:** https://docs.rocketpool.net/
- **Discord:** [Your Discord link if you're in RP community]
- **GitHub:** https://github.com/rocket-pool/smartnode

### Testnet Specific
- **Hoodi Explorer:** https://hoodi.beaconcha.in/
- **Checkpoint Sync:** https://checkpoint-sync.hoodi.ethpandaops.io

---

## Troubleshooting Quick Reference

### Validator Missing Attestations
```bash
# 1. Check if validator is running
docker ps | grep validator

# 2. Check sync status
rocketpool service status

# 3. Check recent logs
docker logs rocketpool_validator --tail 100

# 4. Check for errors
journalctl -u rocketpool_* -n 100 --no-pager
```

### Clients Not Syncing
```bash
# Check peers
# [MANUAL: How do you check peer count for your clients?]

# Check disk space
df -h

# Restart services
# [MANUAL: Restart procedure?]
```

### Network Connectivity Issues
```bash
# Test fallback clients (from node002)
curl http://192.168.60.101:8545
curl http://192.168.60.101:5052/eth/v1/node/health

# Ping between nodes
ping 192.168.60.101
```

---

## Notes

**Current Status:**
- node002 is actively validating (since 2025-10-04)
- node001 is in hot standby with wallet uninitialized
- Both nodes running Rocket Pool 1.18.6 on Debian 13
- Testnet environment (Hoodi) - safe for testing procedures

**Custom Setup Quirks:**
- [Add any non-standard configurations here]
- [Document any automation scripts]
- [Note any known issues or workarounds]
