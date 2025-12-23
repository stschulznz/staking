# Rocket Pool Node Failover Runbook

> Primary: node001 (currently standby)
> Standby: node002 (currently active)
> Network: Hoodi Test
> Clients: node001 Reth + Lighthouse, node002 Nethermind + Lighthouse

## Prerequisites (both nodes)
- Smartnode versions match (currently 1.18.6); plan upgrades during maintenance windows.
- Execution and consensus clients fully synced; fallback RPCs reachable (fallback nodes must **never** have validator keys loaded).
- Beacon block height on standby within 8 blocks of explorer.
- Validator indexes recorded and accessible.
- External network between nodes stable; SSH reachable.
- Avoid slashing: validator keys must be active on only one node at a time.

## Node01 → Node02 Failover (Primary to Standby)
**Goal:** Safely stop validating on node001, let an attestation miss finalize, then start validating on node002.

### Phase 1: Preparation & Verification (node002, ~5–10 min)
1) Verify sync health
   - `rocketpool node sync`
   - Expect primary and fallback EC/CC = synced; beacon height delta ≤ 8 blocks.
2) Verify wallet and validator recoverability
   - `rocketpool wallet test-recovery`
   - `rocketpool wallet export` (store on removable media; do not rsync over network).
3) Validate key presence (if using external/rotated validator disks)
   - `rocketpool minipool status`
   - `find ~/.rocketpool/data/validators -type f -name "*.json"`
   - Confirm expected validator indexes/keys exist locally on node002.
4) Record validator indexes and pubkeys for monitoring
   - From explorer or `rocketpool minipool status`; keep list handy for Phase 3/5.

### Phase 2: Stop node001 (primary) (node001, ~0–2 min)
1) Gracefully stop validator & node services
   - `rocketpool service stop validator`
   - `rocketpool service stop node`
   - If Docker directly: `docker stop rocketpool_validator rocketpool_node`
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
- Check explorer per validator index (Hoodi: https://hoodi.beaconcha.in/validator/<index>); ensure a missed/late attestation exists in a **finalized** epoch.
- Optional safety: wait for 2 missed & finalized attestations.

### Phase 4: Activate node002 (standby becomes active)
1) Start validator services
   - `rocketpool service start validator`
   - If needed: `docker start rocketpool_validator`
2) Confirm wallet and validator load
   - `rocketpool wallet status`
   - `rocketpool minipool status`
   - `docker logs -n 100 rocketpool_validator | grep -Ei "proposer|attestation|loaded"`
   - Lighthouse doppelganger protection defaults to **on**; keep it on for the node you are starting. Ensure the stopped node stays powered off and keys purged.
3) Validation checklist (do not proceed until all true)
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
- Stop/start: `rocketpool service stop validator`, `rocketpool service start validator`
- Wallet ops: `rocketpool wallet test-recovery`, `rocketpool wallet export`, `rocketpool wallet purge`
- Logs: `docker logs -n 200 rocketpool_validator`
- Validator files check: `find ~/.rocketpool/data/validators -type f -name "*.json"`
- Explorer finalized-miss check: open `https://hoodi.beaconcha.in/validator/<index>` and verify at least one missed/late attestation in a finalized epoch.
- Lighthouse doppelganger flag: defaults to **on**; keep enabled on the node you start, and ensure stopped node stays powered off with keys purged.

## Test Network Validation (dry-run on Hoodi)
- Complete failover: node01 ➜ node02 ➜ node01.
- Monitor for 24 hours; target missed attestations <1%.
- Document any timing adjustments needed.

## Critical Reminders
- Never have validator keys loaded on both nodes simultaneously.
- Wait for at least one missed and finalized attestation before re-starting validators on another node.
- Always verify key deletion before powering a node back on after failover.
