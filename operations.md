# Operations Guide (Rocket Pool HA → Mainnet)

> Target steady state: Ethereum mainnet, node001 primary (Reth + Lighthouse) with 7 LEB8 validators; node002 standby (Nethermind + Lighthouse) ready for failover.
> Current status: Hoodi testnet (check [node001-config.txt](node001-config.txt) / [node002-config.txt](node002-config.txt) for active/standby) pending migration; follow [mainnet-migration-plan.md](mainnet-migration-plan.md) for cutover.
> Smartnode: check current versions in [node001-config.txt](node001-config.txt) / [node002-config.txt](node002-config.txt); keep both nodes matched.
> Wallets: **Destroy Hoodi node wallets during migration and create new mainnet node wallets per [docs](https://docs.rocketpool.net/guides/testnet/mainnet)**. Use Tangem as the cold **withdrawal address**, not as the node wallet.

## Runbooks & References
- Failover/failback: see [node-failover-runbook.md](node-failover-runbook.md)
- Config snapshots: [node001-config.txt](node001-config.txt), [node002-config.txt](node002-config.txt)
- Backup workflows: [backup-playbook.md](backup-playbook.md)
- Task backlog: [operational-tasks.md](operational-tasks.md)

## Daily / Pre-flight (active node = check node00{1,2}-config.txt)
 - Health: `rocketpool node sync` (expect primary/fallback EC/CC synced and checkpoint URL configured).
 - Validator status: `rocketpool minipool status`; check recent duties on beaconcha.in for your current validator indices (record them in [mainnet-reference.md](mainnet-reference.md) once on mainnet).
 - Logs spot check: `docker logs -n 200 rocketpool_validator` for attest/proposer lines and absence of errors.
 - Disk: `df -h` (warn at >80% on chain volumes). Nethermind grows; plan prune before 85%.
 - Fee distributor / smoothing pool: `rocketpool node status` should show “Smoothing Pool: opted in”; re-run `rocketpool node join-smoothing-pool` once cooldown passes if you were forced out.
 - MEV: `rocketpool service logs mev-boost --tail 20` to ensure relays answer with HTTP 200; investigate any connection errors immediately.
 - Hot wallet buffer: ensure ≥2 ETH remains on the active node wallet for gas/distributor payouts; top up from your cold wallet if <1.5 ETH.
## Weekly
- OS security patches (Debian 13): `sudo apt update && sudo apt dist-upgrade && sudo apt autoremove`; reboot if `reboot-required` exists.
- Smartnode/client update check: watch Rocket Pool releases; if upgrading, do staged rollout (standby first, then active) during a window.
- Metrics/alerts: confirm Grafana reachable (default 3100) and Alertmanager webhooks still valid.
- MEV relay audit: ensure enabled relay profiles align with censorship/compliance policy; adjust via `rocketpool service config` if guidance changes.
- Fee distributor hygiene: if not relying solely on smoothing pool payouts, run `rocketpool node distribute-fees` as needed (note taxable event risk).

## Standard Update Procedures

### OS Updates (per node)
```bash
# Refresh package metadata and apply updates
sudo apt update
sudo apt dist-upgrade
sudo apt autoremove

# Reboot check: no output file means no reboot needed
cat /var/run/reboot-required
```

### Smartnode Updates
```bash
# Capture current version
rocketpool service version

# Stop services before upgrading
rocketpool service stop

# Download latest CLI binary
sudo wget https://github.com/rocket-pool/smartnode/releases/latest/download/rocketpool-cli-linux-amd64 -O ~/bin/rocketpool

# Reinstall services with new binary
rocketpool service install -d

# Optional: review config changes via TUI
rocketpool service config

# Restart stack and verify
rocketpool service start
rocketpool service version
```

### Post-Upgrade Status Fix (when `rocketpool node status` shows package cache issues)
```bash
sudo apt update
```

## Monthly
- Standby readiness (node002): `rocketpool node sync` on node002; ensure EC/CC fully synced and within 8 blocks of explorer.
- Failover drill (maintenance window): execute node001 → node002 → node001 per runbook; target <1% missed attestations over 24h.
- **Comprehensive validator backup (Corsair Padlock 3)**:
  ```bash
  # Mount backup drive
  sudo mount /dev/sdb1 /mnt/backup-usb
  
  # Backup all validator data including keystores and slashing protection DB
  sudo tar -czf /mnt/backup-usb/node001-validators-$(date -I).tgz -C /mnt/validator_keys data
  
  # Backup Smartnode configuration
  sudo tar -czf /mnt/backup-usb/node001-config-$(date -I).tgz -C ~/.rocketpool user-settings.yml docker-compose.override.yml settings.yml 2>/dev/null || true
  
  # Hash verification
  sha256sum /mnt/backup-usb/node001-validators-$(date -I).tgz >> /mnt/backup-usb/monthly-backups.sha256
  sha256sum /mnt/backup-usb/node001-config-$(date -I).tgz >> /mnt/backup-usb/monthly-backups.sha256 2>/dev/null || true
  
  # Unmount
  sync
  sudo umount /mnt/backup-usb
  ```
  - Includes: validator keystores, slashing protection DB, wallet files, node configuration
  - **Critical after:** adding new minipools, Smartnode upgrades, configuration changes
  - Verify mnemonic phrase remains securely stored offline (paper backup)
- Backup execution chain data (active node = node001, uses Reth):
  - Mount external storage; run `rocketpool service export-eth1-data /mnt/external-drive`
- Verify fallback RPCs work: stop EC/CC briefly on active node (`docker stop rocketpool_eth1 rocketpool_eth2`), run `rocketpool network stats`, confirm fallback in use, then `docker start ...`.

## Storage & Pruning
- Node001 (primary Reth): plan periodic history expiry per Reth docs; checkpoint sync URL must be set before wiping history segments.
- Node002 (Nethermind standby): monitor disk; prune/resync via `rocketpool service prune-eth1` (requires node001 online to serve fallback). Expect downtime on EC only; validation continues via fallback.
- History expiry: consider enabling per client guidance; ensure fallback present before resync/prune events.

## Backups (per docs)
- **Must-have (offline & secure):**
  - Mnemonic phrase for node wallet (paper backup, tested via `rocketpool wallet test-recovery`)
  - Monthly validator data backup to Corsair Padlock 3 (see Monthly section above)
  - Includes: validator keystores, slashing protection DB, wallet files, node configuration
- **When to backup immediately:**
  - After creating each new minipool (new validator keystores generated)
  - After Smartnode version upgrades (configuration may change)
  - After modifying MEV relays, fallback clients, or other critical settings
  - Before major OS updates or hardware changes
- Execution chain data: periodic `export-eth1-data`; restore with `rocketpool service import-eth1-data <path>` (overwrites EC data).
- Slashing protection database: critical component in monthly backup; prevents slashing if validator keys are restored to different machine.
- Metrics data (optional): backup `rocketpool_grafana-storage` volume if dashboards/annotations matter.
- OS images: follow [backup-playbook.md](backup-playbook.md) for weekly LVM snapshots via `scripts/lvm-snapshot-backup.sh` and quarterly Clonezilla baselines; align scheduling with Rocket Pool's [backup guidance](https://docs.rocketpool.net/guides/node/backups).
- **Backup storage:** All sensitive backups on encrypted Corsair Padlock 3 USB drive; retain minimum 3 monthly snapshots; test restore procedure quarterly.

## Monitoring & Alerting
- Grafana: enable metrics stack; import dashboard ID 21863; set admin password; restrict port 3100 to LAN.
- Alerting: configure Discord webhook in Monitoring/Alerting TUI; include rules for smoothing pool opt-out, mev-boost relay failures, and wallet balance <1.5 ETH.
- Third-party: beaconcha.in dashboard for validator indices; optional mobile push.
- Doppelganger safety: Lighthouse defaults to doppelganger protection **on**—keep it enabled on the node you bring online; ensure the other node stays powered off with keys purged.
- **NVMe temperature:** Alert on hottest sensor: `max(node_hwmon_temp_celsius{chip="nvme_nvme0"})`. Warn at 70°C, critical at 75°C. Thermal throttling begins around 70–75°C and causes sync/performance degradation.

## UPS / Power Protection (node001)
- **Hardware:** Eaton 5E 2200 AU G2 connected via USB
- **Software:** NUT (Network UPS Tools) with `usbhid-ups` driver
- **Shutdown trigger:** Battery charge drops to 20% (~14 min at light load)
- **Shutdown script:** `/usr/local/bin/nut-shutdown.sh` stops Rocket Pool gracefully before system poweroff
- **Check UPS status:**
  ```bash
  upsc eaton@localhost ups.status      # OL = online, OB = on battery
  upsc eaton@localhost battery.charge  # percentage
  upsc eaton@localhost battery.runtime # seconds remaining
  ```
- **Services:** `nut-server`, `nut-monitor`, `nut-driver-enumerator` (all enabled at boot)
- **Config files:** `/etc/nut/ups.conf`, `/etc/nut/upsd.conf`, `/etc/nut/upsd.users`, `/etc/nut/upsmon.conf`
- **Udev rule:** `/etc/udev/rules.d/99-nut-ups.rules` (grants NUT access to USB device)

## Security
- SSH: keys only; keep custom port and firewall rules documented; limit Grafana/Prometheus exposure.
- Keys presence: active node only; standby must have no validator keys loaded unless it is about to become active.
- MEV-Boost relays: keep list reviewed; apply relay updates alongside Smartnode updates; never add untrusted relay URLs.
- Tangem custody: withdrawal addresses and any Tangem-signed transaction details must be verified on-card before signing; maintain your offline record of recovery details.

## Change Management
- Sequence updates (post-migration): standby first (node002) → validate → active (node001).
- Record changes: versions, timestamps, commands run, any errors.
- After any client/Smartnode change: `rocketpool service version`, `rocketpool node sync`, check validator duties next epoch.

## Incident / Failover
- Trigger: persistent validator failures, EC/CC corruption, hardware fault.
- Follow [node-failover-runbook.md](node-failover-runbook.md); ensure one finalized missed attestation before restarting on the target node; keys must exist on exactly one host.

## Mainnet Launch Parameters & Validator Plan
- Validator inventory: start with 7 LEB8 minipools (56 ETH bonded) to leave ~9 ETH headroom for gas and future deposits; scale to 11–12 LEB8 once capital approaches 100 ETH.
- Wallet buffer: reserve ≥2 ETH in the active node wallet for gas/fee distributor payouts; if the standby node wallet is initialized for planned failover, keep a similar buffer there too.
- Smoothing pool: strongly recommended for new minipools; opt in via `rocketpool node join-smoothing-pool`. Opt-out / opt-back-in requires waiting a full rewards interval (28 days on mainnet) per [Fee Distributors and the Smoothing Pool](https://docs.rocketpool.net/guides/node/fee-distrib-sp).
- Fee distributor: run `rocketpool node initialize-fee-distributor` after wallet creation; `rocketpool node deposit` automatically distributes any pending fees (watch for taxable events).
- MEV operation: keep mev-boost locally managed and enabled with preferred relay profiles; verify health via `rocketpool service logs mev-boost --tail 50`.
- Tangem workflows: Tangem signs withdrawal-address confirmation transactions (primary + optional RPL) via the Rocket Pool website flow; the hot node wallet signs node operations (register, join smoothing pool, deposits). Verify destination addresses on-card each time.
- Hoodi archival (pre-migration only): before deleting Hoodi data, optionally run `rocketpool node claim-rewards` and `rocketpool node distribute-fees` to capture Hoodi history (tokens remain testnet-only).

## Contact & Verification
- Mainnet explorer: https://beaconcha.in/validator/<index> (target) and Hoodi explorer (legacy) for pre-migration reference.
- External IP check: `curl -s ifconfig.me` (document per node for firewall/monitoring)
