# Commands Reference

Quick reference for all operational commands on the Rocket Pool HA setup.

> **OS:** Debian 13 (Trixie)  
> **Nodes:** node001 (Reth + Lighthouse), node002 (Nethermind + Lighthouse)

---

## Rocket Pool Status & Health

### Service Status
```bash
# Full service status (all containers)
rocketpool service status

# Sync status (EC + CC + fallbacks)
rocketpool node sync

# Node registration and wallet info
rocketpool node status

# Wallet address and balance
rocketpool wallet status

# Minipool status
rocketpool minipool status

# Network stats
rocketpool network stats
```

### Version Information
```bash
# Smartnode and client versions
rocketpool service version
```

---

## Rocket Pool Logs

### Client Logs
```bash
# Execution client logs (Reth on node001, Nethermind on node002)
rocketpool service logs eth1 --tail 100
docker logs rocketpool_eth1 --tail 100

# Consensus client logs (Lighthouse)
rocketpool service logs eth2 --tail 100
docker logs rocketpool_eth2 --tail 100

# Validator client logs
rocketpool service logs validator --tail 100
docker logs rocketpool_validator --tail 100

# Follow logs in real-time (add -f)
rocketpool service logs eth1 -f
docker logs -f rocketpool_eth1
```

### MEV-Boost Logs
```bash
# Check relay health (expect HTTP 200 responses)
rocketpool service logs mev-boost --tail 50
docker logs rocketpool_mev-boost --tail 50
```

### Smartnode Daemon Logs
```bash
# Node daemon
docker logs rocketpool_node --tail 100

# Watchtower
docker logs rocketpool_watchtower --tail 100

# API container
docker logs rocketpool_api --tail 100
```

### Monitoring Stack Logs
```bash
# Prometheus
docker logs rocketpool_prometheus --tail 100

# Grafana
docker logs rocketpool_grafana --tail 100

# Alertmanager
docker logs rocketpool_alertmanager --tail 100
```

---

## Rocket Pool Service Control

### Start/Stop Services
```bash
# Stop all services
rocketpool service stop

# Start all services
rocketpool service start

# Restart specific container
docker restart rocketpool_validator
docker restart rocketpool_eth1
docker restart rocketpool_eth2

# Stop specific container
docker stop rocketpool_validator

# Start specific container
docker start rocketpool_validator
```

### Configuration
```bash
# Open TUI configuration
rocketpool service config

# Resync consensus client (checkpoint sync)
rocketpool service resync-eth2

# Prune execution client (Nethermind)
rocketpool service prune-eth1

# Export execution client data
rocketpool service export-eth1-data /path/to/backup

# Import execution client data
rocketpool service import-eth1-data /path/to/backup

# Terminate all services and remove containers
rocketpool service terminate
```

---

## Wallet Operations

### Status & Info
```bash
# Wallet status and address
rocketpool wallet status

# Test recovery (verify mnemonic without changing anything)
rocketpool wallet test-recovery

# Export wallet (backup mnemonic - use carefully)
rocketpool wallet export
```

### Wallet Management
```bash
# Initialize new wallet
rocketpool wallet init

# Recover wallet from mnemonic
rocketpool wallet recover

# Purge wallet and validator keys (CRITICAL - use during failover only)
rocketpool wallet purge
```

---

## Node Operations

### Registration & Setup
```bash
# Register node on-chain
rocketpool node register

# Set timezone
rocketpool node set-timezone Etc/UTC

# Set primary withdrawal address
rocketpool node set-primary-withdrawal-address <address>

# Set RPL withdrawal address (optional)
rocketpool node set-rpl-withdrawal-address <address>
```

### Fee Distributor & Smoothing Pool
```bash
# Initialize fee distributor contract
rocketpool node initialize-fee-distributor

# Join smoothing pool
rocketpool node join-smoothing-pool

# Leave smoothing pool (28-day cooldown)
rocketpool node leave-smoothing-pool

# Distribute accumulated fees
rocketpool node distribute-fees
```

### Minipool Management
```bash
# Create new minipool (deposit)
rocketpool node deposit

# Check minipool status
rocketpool minipool status

# Distribute minipool balance
rocketpool minipool distribute-balance

# Exit minipool (voluntary exit)
rocketpool minipool exit
```

### Rewards
```bash
# Check pending rewards
rocketpool node rewards

# Claim rewards
rocketpool node claim-rewards
```

### Sending ETH/Tokens
```bash
# Check node wallet balance first
rocketpool node status

# Send specific amount of ETH
rocketpool node send 1.5 eth 0xDestinationAddress

# Send RPL tokens
rocketpool node send 100 rpl 0xDestinationAddress

# Send rETH tokens
rocketpool node send 5 reth 0xDestinationAddress
```

> **Note:** Keep at least 0.05-0.1 ETH in your node wallet for gas fees (claiming rewards, voting, etc.)

---

## Docker Commands

### Container Status
```bash
# List all containers (running and stopped)
docker ps -a

# List running containers with status
docker ps --format "{{.Names}} {{.Status}}" | sort

# Container resource usage
docker stats --no-stream
```

### Container Management
```bash
# Execute command inside container
docker exec -it rocketpool_eth1 /bin/sh

# Check container inspect (config, mounts, etc.)
docker inspect rocketpool_eth1

# View container mounts
docker inspect rocketpool_eth1 --format '{{json .Mounts}}' | jq

# Remove stopped containers
docker container prune
```

### Images & Volumes
```bash
# List images
docker images

# Remove unused images
docker image prune

# List volumes
docker volume ls

# Inspect volume
docker volume inspect rocketpool_grafana-storage
```

---

## System Monitoring

### Disk Usage
```bash
# Disk space overview
df -h

# Disk usage by directory
du -sh /var/lib/docker/*
du -sh ~/.rocketpool/*

# Detailed disk usage (chain data)
sudo du -sh /var/lib/docker/volumes/rocketpool_eth1-data/_data
```

### Memory & CPU
```bash
# Real-time system monitor
htop

# Memory usage breakdown
free -h

# Memory details (including buffers/cache)
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached"

# CPU info
lscpu
```

### Process Information
```bash
# Top processes by memory
ps aux --sort=-%mem | head -20

# Top processes by CPU
ps aux --sort=-%cpu | head -20
```

### System Uptime & Load
```bash
# Uptime and load average
uptime

# System information
uname -a

# OS version
cat /etc/os-release
```

---

## NVMe / Storage Health

### Temperature Monitoring
```bash
# NVMe temperature and health (requires nvme-cli)
sudo nvme smart-log /dev/nvme0

# Quick temperature check
sudo nvme smart-log /dev/nvme0 | grep -i temp

# Thermal throttle events
sudo nvme smart-log /dev/nvme0 | grep -i thm

# All sensors via lm-sensors
sensors
```

### SMART Data
```bash
# Full SMART data
sudo smartctl -a /dev/nvme0

# Health summary
sudo smartctl -H /dev/nvme0
```

### LVM (if using)
```bash
# Volume groups
sudo vgs

# Logical volumes
sudo lvs

# Physical volumes
sudo pvs
```

---

## Network

### Connectivity
```bash
# External IP
curl -s ifconfig.me

# Check listening ports
sudo ss -tlnp

# Check specific port
sudo ss -tlnp | grep 9001

# Network interfaces
ip addr

# Routing table
ip route
```

### Firewall (ufw)
```bash
# Status
sudo ufw status verbose

# Allow port
sudo ufw allow 9001/tcp

# Check rules
sudo ufw status numbered
```

### DNS & Connectivity Tests
```bash
# Test DNS resolution
dig beaconstate.ethstaker.cc

# Test beacon API (local)
curl -s localhost:5052/eth/v1/node/syncing | jq

# Test execution RPC (local)
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545 | jq
```

---

## UPS Monitoring (NUT)

### UPS Status
```bash
# Full UPS status
upsc eaton@localhost

# Quick checks
upsc eaton@localhost ups.status        # OL=online, OB=on battery
upsc eaton@localhost battery.charge    # percentage
upsc eaton@localhost battery.runtime   # seconds remaining
upsc eaton@localhost input.voltage     # mains voltage
```

### NUT Services
```bash
# Service status
sudo systemctl status nut-server
sudo systemctl status nut-monitor

# Restart NUT
sudo systemctl restart nut-server nut-monitor

# Test shutdown script (DRY RUN - comment out actual shutdown!)
sudo /usr/local/bin/nut-shutdown.sh
```

---

## LUKS USB Management

### Status & Mounting
```bash
# Check if LUKS mapper is active
sudo cryptsetup status validator_keys

# Check mount status
mount | grep validator_keys
findmnt /mnt/validator_keys

# Verify symlink
readlink -f ~/.rocketpool/data
ls -la ~/.rocketpool/data
ls -la /mnt/validator_keys/data
```

### Manual Unlock/Mount
```bash
# Unlock LUKS (if not auto-unlocked)
sudo systemctl start validator-keys-unlock.service

# Mount (if not auto-mounted)
sudo systemctl start mnt-validator_keys.mount

# Or trigger via automount
ls /mnt/validator_keys
```

### Troubleshooting
```bash
# Check unlock service status
sudo systemctl status validator-keys-unlock.service --no-pager

# Check mount/automount status
sudo systemctl status mnt-validator_keys.mount --no-pager
sudo systemctl status mnt-validator_keys.automount --no-pager

# View service logs
sudo journalctl -u validator-keys-unlock.service -b --no-pager | tail -50
sudo journalctl -u mnt-validator_keys.mount -b --no-pager | tail -50

# Reset failed state
sudo systemctl reset-failed mnt-validator_keys.mount

# List block devices
lsblk -f
```

---

## OS Updates & Maintenance

### Package Management (Debian/apt)
```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt dist-upgrade

# Remove unused packages
sudo apt autoremove

# Check if reboot required
cat /var/run/reboot-required

# Search for package
apt search <package-name>

# Show package info
apt show <package-name>
```

### Service Management (systemd)
```bash
# List all services
systemctl list-units --type=service

# Service status
sudo systemctl status <service-name>

# Start/stop/restart service
sudo systemctl start <service-name>
sudo systemctl stop <service-name>
sudo systemctl restart <service-name>

# Enable/disable at boot
sudo systemctl enable <service-name>
sudo systemctl disable <service-name>

# Reload systemd after unit file changes
sudo systemctl daemon-reload
```

### Logs (journalctl)
```bash
# System logs since boot
journalctl -b

# Follow logs in real-time
journalctl -f

# Logs for specific service
journalctl -u <service-name> --no-pager | tail -100

# Logs with timestamps
journalctl -b --since "1 hour ago"

# Kernel messages
dmesg | tail -100
```

### Time Sync (chrony)
```bash
# Check time sync status
chronyc tracking

# Check time sources
chronyc sources -v

# Force sync
sudo chronyc makestep
```

---

## Backup Commands

### Validator Data Backup
```bash
# Mount backup drive
sudo mount /dev/sdb1 /mnt/backup-usb

# Backup validator data (keystores, slashing DB, wallet)
sudo tar -czf /mnt/backup-usb/node001-validators-$(date -I).tgz \
  -C /mnt/validator_keys data

# Backup Smartnode config
sudo tar -czf /mnt/backup-usb/node001-config-$(date -I).tgz \
  -C ~/.rocketpool user-settings.yml docker-compose.override.yml settings.yml 2>/dev/null || true

# Hash verification
sha256sum /mnt/backup-usb/node001-*.tgz >> /mnt/backup-usb/checksums.sha256

# Unmount
sync
sudo umount /mnt/backup-usb
```

### Config Snapshot
```bash
# Update node config snapshot (run on each node)
./scripts/update-config.sh node001
./scripts/update-config.sh node002
```

---

## Failover Quick Reference

### Pre-Failover Checks (standby node)
```bash
rocketpool node sync
rocketpool wallet test-recovery
ls /mnt/validator_keys/data
readlink -f ~/.rocketpool/data
```

### Stop Active Node
```bash
rocketpool service stop
rocketpool wallet purge
find ~/.rocketpool/data/validators -type f -name "*.json"  # expect empty
```

### Activate Standby Node
```bash
rocketpool wallet recover
rocketpool service start
rocketpool wallet status
rocketpool minipool status
docker logs -n 100 rocketpool_validator | grep -Ei "proposer|attestation|loaded"
```

---

## Useful One-Liners

```bash
# Quick health check
rocketpool node sync && rocketpool minipool status

# Watch validator logs for attestations
docker logs -f rocketpool_validator 2>&1 | grep -i attest

# Check all container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Disk space alert check (>80%)
df -h | awk '$5+0 > 80 {print $0}'

# Memory pressure check
free -h | awk '/Mem:/ {printf "Used: %s / %s (%.1f%%)\n", $3, $2, $3/$2*100}'

# NVMe temp quick check
sudo nvme smart-log /dev/nvme0 2>/dev/null | awk '/^temperature/ {print "NVMe Temp: " $3 "°C"}'

# Check for missed attestations in validator logs
docker logs rocketpool_validator 2>&1 | tail -500 | grep -i "miss\|late\|timeout"
```

---

## External Resources

- **Mainnet Explorer:** https://beaconcha.in/validator/<index>
- **Rocket Pool Docs:** https://docs.rocketpool.net/
- **Rocket Pool Discord:** https://discord.gg/rocketpool
- **ETHStaker Discord:** https://discord.gg/ethstaker
