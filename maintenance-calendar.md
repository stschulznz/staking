# Maintenance Calendar (HA)

Use this to schedule routine work. Keep windows short; prefer standby-first, then active. Times in local + UTC.

## Recurring
- Weekly (Active node = node002 now):
  - OS security updates, reboot if required.
  - Smartnode/client release check.
  - Logs spot check (validator, EC/CC) and `rocketpool node sync`.
- Monthly:
  - Standby readiness check on node001 (`rocketpool node sync`).
  - Failover drill: node01 → node02 → node01; target <1% missed attestations over 24h.
  - EC data backup on active node (`rocketpool service export-eth1-data <path>`).
  - Fallback test: stop EC/CC briefly, confirm Smartnode uses fallback, then restart.
- Quarterly:
  - Storage review and prune plan (Nethermind on node002, Reth on node001; consider history expiry).
  - MEV relay set review.
  - Alerting/Grafana credentials and webhook validation.

## One-off / Scheduled Items
- Date/Time:
- Scope:
- Nodes involved:
- Risk & fallback plan:
- Owner:
- Expected duration:
- Post-checks: `rocketpool node sync`, explorer duties, disk usage, alerts quiet.

## Upcoming Windows
- [ ] Item / date / owner / status

## Completed Windows
- yyyy-mm-dd: summary, nodes, outcome, link to change-log entry
