# Operations Guide (Rocket Pool HA, Hoodi)

> Primary node (designated): node001 — Reth + Lighthouse (standby right now)
> Current active validator host: node002 — Nethermind + Lighthouse (fallback RPCs point to node001)
> Smartnode: v1.18.6 on both
> Network: Hoodi Test

## Runbooks & References
- Failover/failback: see [node-failover-runbook.md](node-failover-runbook.md)
- Config snapshots: [node001-config.txt](node001-config.txt), [node002-config.txt](node002-config.txt)

## Daily / Pre-flight (active node = node002)
- Health: `rocketpool node sync` (expect primary/fallback EC/CC synced).
- Validator status: `rocketpool minipool status`; check recent duties on hoodi.beaconcha.in.
- Logs spot check: `docker logs -n 200 rocketpool_validator` for attest/proposer lines and absence of errors.
- Disk: `df -h` (warn at >80% on chain volumes). Nethermind grows; plan prune before 85%.

## Weekly
- OS security patches (Debian 13): `sudo apt update && sudo apt dist-upgrade && sudo apt autoremove`; reboot if `reboot-required` exists.
- Smartnode/client update check: watch Rocket Pool releases; if upgrading, do staged rollout (standby first, then active) during a window.
- Metrics/alerts: confirm Grafana reachable (default 3100) and Alertmanager webhooks still valid.

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
- Standby readiness (node001): `rocketpool node sync` on node001; ensure EC/CC fully synced and within 8 blocks of explorer.
- Failover drill (maintenance window): execute node01 → node02 → node01 per runbook; target <1% missed attestations over 24h.
- Backup execution chain data (active node = node002, uses Nethermind):
  - Mount external storage; run `rocketpool service export-eth1-data /mnt/external-drive`
  - Keep mnemonic offline; do **not** back up wallet/password files unless encrypted and offsite.
- Verify fallback RPCs work: stop EC/CC briefly on active node (`docker stop rocketpool_eth1 rocketpool_eth2`), run `rocketpool network stats`, confirm fallback in use, then `docker start ...`.

## Storage & Pruning
- Node002 (Nethermind): monitor disk; prune/resync via `rocketpool service prune-eth1` (requires fallback online). Expect downtime on EC only; validation continues via fallback if configured.
- Node001 (Reth standby): Reth supports online prune/history expiry; schedule during standby maintenance if space becomes constrained.
- History expiry: consider enabling per client guidance; ensure fallback present before resync/prune events.

## Backups (per docs)
- Must-have: mnemonic for node wallet (offline, tested via `rocketpool wallet test-recovery`).
- Execution chain data: periodic `export-eth1-data`; restore with `rocketpool service import-eth1-data <path>` (overwrites EC data).
- Do **not** back up validator keystores routinely; keys stay only on the active host. If external keys exist, store securely and offline.
- Metrics data (optional): backup `rocketpool_grafana-storage` volume if dashboards/annotations matter.

## Monitoring & Alerting
- Grafana: enable metrics stack; import dashboard ID 21863; set admin password; restrict port 3100 to LAN.
- Alerting: configure Discord webhook in Monitoring/Alerting TUI; test alerts after setup.
- Third-party: beaconcha.in dashboard for validator indices; optional mobile push.
- Doppelganger safety: Lighthouse defaults to doppelganger protection **on**—keep it enabled on the node you bring online; ensure the other node stays powered off with keys purged.

## Security
- SSH: keys only; keep custom port and firewall rules documented; limit Grafana/Prometheus exposure.
- Keys presence: active node only; standby must have no validator keys loaded unless it is about to become active.
- MEV-Boost relays: keep list reviewed; apply relay updates alongside Smartnode updates.

## Change Management
- Sequence updates: standby first (node001) → validate → active (node002).
- Record changes: versions, timestamps, commands run, any errors.
- After any client/Smartnode change: `rocketpool service version`, `rocketpool node sync`, check validator duties next epoch.

## Incident / Failover
- Trigger: persistent validator failures, EC/CC corruption, hardware fault.
- Follow [node-failover-runbook.md](node-failover-runbook.md); ensure one finalized missed attestation before restarting on the target node; keys must exist on exactly one host.

## Contact & Verification
- Hoodi explorer: https://hoodi.beaconcha.in/validator/<index>
- External IP check: `curl -s ifconfig.me` (document per node for firewall/monitoring)
