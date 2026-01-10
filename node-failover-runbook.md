# Rocket Pool Node Failover Runbook

> Primary: node001 (currently standby)
> Standby: node002 (currently active)
> Network: Hoodi Test
> Clients: node001 Reth + Lighthouse, node002 Nethermind + Lighthouse

## Prerequisites (both nodes)
- Smartnode versions match (currently 1.18.6); plan upgrades during maintenance windows and confirm with `rocketpool service version` on both nodes.
- Execution and consensus clients fully synced; fallback RPCs reachable (fallback nodes must **never** have validator keys loaded).
- Beacon block height on standby within 8 blocks of explorer.
- Validator indexes recorded and accessible.
- External network between nodes stable; SSH reachable.
- Avoid slashing: validator keys must be active on only one node at a time.

## Node01 → Node02 Failover (Primary to Standby)
**Goal:** Safely stop validating on node001, let an attestation miss finalize, then start validating on node002.

### Phase 1: Preparation & Verification (~5–10 min total)
0) Refresh config snapshots (both nodes, using `scripts/update-config.sh`)
   - On node002: `./scripts/update-config.sh node002`
   - On node001: `./scripts/update-config.sh node001`
   - Pull the updated `node001-config.txt` / `node002-config.txt` back to your operator terminal so you have the latest node roles, versions, and validator details handy for the remainder of the runbook.
1) Verify sync health (node002)
   - `rocketpool node sync`
   - Expect primary and fallback EC/CC = synced; beacon height delta ≤ 8 blocks.
2) Verify wallet and validator recoverability (node002)
   - `rocketpool wallet test-recovery`
   - Confirm latest mnemonic/password backup exists. If you need a fresh copy, run `rocketpool wallet export` on the currently active node **before** Phase 2 and move it to removable media (never copy over the network).
3) Verify encrypted data volume (node002 LUKS USB)
   - Unlock the USB with its hardware PIN (if not already unlocked) and confirm it is mounted: `ls /mnt/validator_keys/data`.
   - Ensure the Rocket Pool symlink still targets the mounted path: `readlink -f ~/.rocketpool/data` → expect `/mnt/validator_keys/data`.
   - If either command fails, follow [luks-usb-setup.md](luks-usb-setup.md) before continuing.
4) Record validator indexes and pubkeys for monitoring (active node, e.g., node001 while still validating)
   - On the active node: `rocketpool minipool status` or explorer exports; capture validator indexes/pubkeys before stopping services so the standby has an authoritative list for Phase 3/5 monitoring.

### Phase 2: Stop node001 (primary) (node001, ~0–2 min)
1) Gracefully stop the Smartnode stack on node001
   - `rocketpool service stop`
   - If you prefer direct Docker control: `docker stop rocketpool_validator rocketpool_node`
2) Prevent auto-restart (optional but recommended)
   - `docker ps` → ensure validator container is stopped.
3) Delete validator keys on node001 (CRITICAL)
   - `rocketpool wallet purge` (removes keystores and password from data dir)
   - Verify deletion:
     - `find ~/.rocketpool/data/validators -type f -name "*.json"` → expect no results
     - Remove/empty Lighthouse slashing DB: `rm -rf ~/.lighthouse/validators && rm -f ~/.lighthouse/slashing_protection.sqlite`
     - Confirm no slashing DB remnants: `ls ~/.lighthouse` (no validators/slashing_protection.sqlite)
   - Do **not** power node001 back on with keys present.

### Phase 3: Critical waiting period (monitor from either host)
- Duration: minimum 15 minutes **and** after one missed attestation per validator is finalized (per Rocket Pool migration guidance).
- Use the validator pubkeys captured from the active node's latest `node001-config.txt` and `node002-config.txt` (generated in Phase 1) to open each validator page on https://hoodi.beaconcha.in/ (e.g., paste pubkey or index into https://hoodi.beaconcha.in/validator/INDEX) and ensure a missed/late attestation exists in a **finalized** epoch.
- Optional safety: wait for 2 missed & finalized attestations.

### Phase 4: Activate node002 (standby becomes active)
1) Recover wallet and validator keys on node002
   - `rocketpool wallet recover` (use the same mnemonic/password verified in Phase 1).
   - Confirm validator keystores were written to `/mnt/validator_keys/data` and that the LUKS volume remains mounted.
2) Start the Smartnode stack
   - `rocketpool service start`
   - If necessary, use `docker start rocketpool_validator` (and other containers) for manual control.
3) Confirm wallet and validator load
   - `rocketpool wallet status`
   - `rocketpool minipool status`
   - `docker logs -n 100 rocketpool_validator | grep -Ei "proposer|attestation|loaded"`
   - Lighthouse doppelganger protection defaults to **on**; keep it on for the node you are starting. Ensure the stopped node stays powered off and keys purged.
4) Validation checklist (do not proceed until all true)
   - Explorer shows next attestation from node002
   - `rocketpool node sync` healthy
   - Logs show scheduled/processed duties without errors

### Phase 5: Post-failover monitoring
- First 2 hours: watch missed/late attestations every epoch.
- Next 48 hours: monitor hourly.
- Commands:
  - `rocketpool node sync`
  - `docker logs -n 200 rocketpool_validator`
  - `rocketpool network stats --minipools`
  - Explorer: missed/attestation rate <1% over 24h.
- Re-point fallback clients so the newly active node fails over to the new standby:
   - On the active node, run `rocketpool service config`, open **Fallback Clients**, set `Use Fallback Clients = true`, and enter the standby node's Execution (`http://<standby-ip>:8545`) and Beacon (`http://<standby-ip>:5052`) URLs (see screenshot reference). Apply and restart services if prompted.
- Validate fallback configuration per [Rocket Pool docs](https://docs.rocketpool.net/guides/node/fallback):
   - `rocketpool node sync` should report both fallback Execution and Consensus clients as "fully synced"; if not, revisit `rocketpool service config`.
   - Optional full test: `docker stop rocketpool_eth1 rocketpool_eth2`, run `rocketpool network stats`, confirm the warning `NOTE: primary clients are not ready, using fallback clients...`, then `docker start rocketpool_eth1 rocketpool_eth2` and re-run `rocketpool node sync` to ensure primaries resume.
- Once validation is stable (after initial monitoring window), rerun `./scripts/update-config.sh node001` and `./scripts/update-config.sh node002` so the config files reflect the new active/standby roles and can be referenced for future procedures.

## Node02 → Node01 Failback (mirror of above)
Follow the same phases, swapping roles (stop node002, wait for finalized miss, start node001). Checklist:
1) Prep node001 (sync, wallet test-recovery, key presence).
2) Stop validator on node002 and purge keys there.
3) Wait for finalized missed attestation.
4) Start validator on node001; verify duties.
5) Monitor 48h.

## Emergency Rollback (if failover goes wrong)
- If node002 cannot validate:
  1) **Do not** power on both nodes with keys simultaneously.
  2) Keep node001 powered off until node002 keys are purged.
  3) Purge validator keys on the non-working node; verify deletion.
  4) Choose one node to recover, apply standard failover procedure again.

## Troubleshooting
- Mnemonic test-recovery fails: stop; do not proceed; fix mnemonic before purging keys.
- Keys still present after purge: re-run purge; manually delete JSON under `~/.rocketpool/data/validators`; re-check with `find ... -name "*.json"`.
- Node won’t start because key offline: ensure node is offline while verifying slashing DB; recover only after miss + finalization.
- Missing attestations not visible on explorer: wait 10–15 minutes; check finalized epochs; confirm validator index.
- Validator shows “active” on both nodes: immediately stop validator service on one node; ensure only one has keys.

## Maintenance & Testing
- Monthly standby sync check: `rocketpool node sync` on standby; verify CC/EC synced.
- Test failover during maintenance windows only; never with both nodes validating.
- Version updates: upgrade both nodes during maintenance, keep versions matched.

## Quick Reference Commands
- Status: `rocketpool node sync`, `rocketpool service status`, `rocketpool wallet status`, `rocketpool minipool status`
- Stop/start: `rocketpool service stop` (entire stack), `rocketpool service start validator`
- Wallet ops: `rocketpool wallet test-recovery`, `rocketpool wallet export`, `rocketpool wallet purge`
- Logs: `docker logs -n 200 rocketpool_validator`
- Validator files check: `find ~/.rocketpool/data/validators -type f -name "*.json"`
- Explorer finalized-miss check: open https://hoodi.beaconcha.in/ and navigate to each validator (e.g., https://hoodi.beaconcha.in/validator/123456) to verify at least one missed/late attestation in a finalized epoch.

## Test Network Validation (dry-run on Hoodi)
- Complete failover: node01 ➜ node02 ➜ node01.
- Monitor for 24 hours; target missed attestations <1%.
- Document any timing adjustments needed.

## Critical Reminders
- Never have validator keys loaded on both nodes simultaneously.
- Wait for at least one missed and finalized attestation before re-starting validators on another node.
- Always verify key deletion before powering a node back on after failover.
