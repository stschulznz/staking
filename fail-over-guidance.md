Rocketpool Node Failover Runbook
Prerequisites
    • Both nodes fully synced with Execution and Consensus clients
    • Both nodes running same Rocketpool version
    • Mnemonic securely stored and accessible
    • Validator indices documented
    • Beaconcha.in bookmarked for monitoring
Node01 → Node02 Failover Procedure

Phase 1: Preparation & Verification
Duration: 5-10 minutes
    1. Verify Node02 sync status
# On Node02
rocketpool service status
rocketpool node sync
        ○ Ensure both clients show "Synced" or "100%"
        ○ Note current block heights and compare to block explorer
    2. Test mnemonic recovery (DO NOT SKIP)
# On Node02
rocketpool wallet test-recovery
        ○ Enter your mnemonic when prompted
        ○ Verify it successfully recovers node wallet and all validator keys
        ○ If this fails, STOP. Do not proceed with failover.
    3. Document current state
        ○ Note all validator indices (from rocketpool minipool status) 
        ○ Check current attestation status on beaconcha.in
        ○ Screenshot current performance metrics (optional but recommended)
Phase 2: Stop Node01
Duration: 2-3 minutes
    4. Stop validator on Node01
# On Node01
rocketpool service stop
        ○ Verify services stopped: docker ps (should show no validator container)
        ○ Alternative check: systemctl status rocketpool-validator if using native mode
    5. Purge keys from Node01
# On Node01
rocketpool wallet purge
        ○ Type "yes" when prompted to confirm deletion
    6. Verify key deletion (CRITICAL)
# On Node01
rocketpool wallet status
# Should show: "No wallet found"

# Check validator data directories
ls -la ~/.rocketpool/data/validators/
# Should be empty or show empty subdirectories

# For each consensus client folder, verify no keys:
ls -la ~/.rocketpool/data/validators/lighthouse/validators/
ls -la ~/.rocketpool/data/validators/teku/validator/key-manager/
# (adjust path based on your consensus client)
        ○ Confirm ALL key files are deleted
    7. Power off Node01 and disconnect network
# On Node01
sudo shutdown now
        ○ Physically disconnect Ethernet cable OR disable network interface
        ○ Verify Node01 is completely offline (ping test from another machine)
Phase 3: Critical Waiting Period
Duration: 15-25 minutes MINIMUM
    8. Wait and monitor for missed attestations 
        ○ Go to beaconcha.in/validator/YOUR_VALIDATOR_INDEX (for each validator)
        ○ Wait for at least ONE missed attestation
        ○ Critical: Ensure the epoch containing the missed attestation is FINALIZED
        ○ Finalization takes ~15 minutes after the missed attestation
What to look for: 
        ○ Red/missed attestation appears in timeline
        ○ Check epoch number of missed attestation
        ○ Wait until that epoch shows "Finalized" status
        ○ If you have multiple minipools: ALL must show missed attestations in finalized epochs
Recommended: Wait for 2-3 missed attestations for extra safety margin
Phase 4: Activate Node02
Duration: 5-10 minutes
    9. Recover wallet on Node02
# On Node02
rocketpool wallet recover
        ○ Enter your mnemonic when prompted
        ○ Set password for wallet
        ○ Confirm recovery successful
    10. Verify wallet recovery
# On Node02
rocketpool wallet status
rocketpool minipool status
        ○ Confirm wallet address matches Node01
        ○ Verify all minipools are recognized
    11. Restart validator client
# On Node02
docker restart rocketpool_validator
# OR if using service commands:
rocketpool service start
    12. Verify validator is running
# On Node02
docker logs -f rocketpool_validator
# Watch for "Loaded validator keystores" or similar messages
# Should see no errors about missing keys
Phase 5: Post-Failover Monitoring
Duration: 1-2 hours active monitoring, then 24-48 hours passive
    13. Monitor first attestations
        ○ Watch beaconcha.in for next 3-4 attestations (~20-30 minutes)
        ○ Verify attestations are now successful (green checkmarks)
        ○ Check validator logs for any errors: 
docker logs rocketpool_validator --tail 100
    14. Verify full functionality
# On Node02
rocketpool node status
rocketpool minipool status
rocketpool node sync
        ○ Confirm all services healthy
        ○ Verify RPL stake shows correctly
        ○ Check smoothing pool status if applicable
    15. Extended monitoring (24-48 hours)
        ○ Check attestation effectiveness returns to normal
        ○ Monitor for any penalties or unusual behavior
        ○ Verify rewards continue to accrue properly

Node02 → Node01 Failback Procedure
Use the exact same procedure as above, just swap node names:
    • Replace "Node01" with "Node02" in Phase 2
    • Replace "Node02" with "Node01" in Phase 4
    • All steps and waiting periods remain identical
Quick Failback Checklist:
    1. ✓ Node01 fully synced and ready
    2. ✓ Test mnemonic recovery on Node01
    3. ✓ Stop validator on Node02
    4. ✓ Purge keys from Node02
    5. ✓ Verify deletion on Node02
    6. ✓ Power off Node02 and disconnect network
    7. ✓ Wait 15+ minutes for missed attestations in finalized epochs
    8. ✓ Recover wallet on Node01
    9. ✓ Restart validator on Node01
    10. ✓ Monitor attestations for 24-48 hours

Emergency Rollback Procedure
If something goes wrong during failover:
    1. DO NOT panic or rush
    2. DO NOT start both nodes simultaneously
    3. Assess the situation:
        ○ Which node has keys loaded?
        ○ Have both nodes been stopped for 15+ minutes?
        ○ Are attestations being missed?
    4. If uncertain which node is active:
# Check each node:
rocketpool wallet status
docker ps | grep validator
    5. Recovery steps:
        ○ Ensure BOTH nodes are stopped and powered off
        ○ Wait 30 minutes minimum
        ○ Choose ONE node to recover to
        ○ Follow standard activation procedure (Phase 4)

Troubleshooting
Problem: Mnemonic test-recovery fails
Solution: DO NOT PROCEED. Your mnemonic may be incorrect or corrupted. Do not purge keys from active node.
Problem: Keys still present after purge
Solution: Manually delete validator key directories and verify again before proceeding.
Problem: Node won't sync after being offline
Solution: May need to resync from checkpoint or snapshot. Keep other node offline while resolving.
Problem: Missed attestations not showing on beaconcha.in
Solution: Wait longer. Beaconcha.in may have delays. Verify epoch finalization.
Problem: Validator shows "active" on both nodes
Solution: IMMEDIATELY stop both nodes, wait 30 minutes, then recover to one node only.

Maintenance Notes
Periodic Standby Node Sync (Monthly Recommended)
    1. Ensure active node is running normally
    2. Power on standby node (WITHOUT wallet/keys)
    3. Let clients sync for 1-2 hours
    4. Verify sync status: rocketpool node sync
    5. Stop services: rocketpool service stop
    6. Power off standby node
    7. Never load wallet/keys during maintenance sync
Version Updates
    • Update both nodes to same version during maintenance windows
    • Test on standby node first when possible
    • Keep versions synchronized to avoid compatibility issues during failover

Quick Reference Commands
# Check sync status
rocketpool node sync
rocketpool service status
# Test mnemonic
rocketpool wallet test-recovery
# Stop services
rocketpool service stop
# Purge wallet
rocketpool wallet purge
# Check wallet status
rocketpool wallet status
# Recover wallet
rocketpool wallet recover
# Restart validator
docker restart rocketpool_validator
# View logs
docker logs -f rocketpool_validator
docker logs rocketpool_eth2 --tail 100
docker logs rocketpool_eth1 --tail 100
# Check minipool status
rocketpool minipool status

Test Network Validation
Before moving to mainnet, validate on Holesky:
    • ✓ Complete failover Node01 → Node02
    • ✓ Monitor for 24 hours
    • ✓ Complete failback Node02 → Node01
    • ✓ Monitor for 24 hours
    • ✓ Verify no slashing penalties occurred
    • ✓ Document any issues or timing adjustments needed
    • ✓ Confirm comfort level with entire process
Only proceed to mainnet after successful test network validation.

Critical Reminders
⚠️ NEVER have wallet/keys loaded on both nodes simultaneously
⚠️ ALWAYS wait for missed attestations in FINALIZED epochs
⚠️ ALWAYS verify key deletion before powering on new node
⚠️ ALWAYS test mnemonic recovery before starting failover
⚠️ When in doubt, wait longer. Extra waiting never causes slashing.

Document Version: 1.0
Last Updated: [Add date when you test]
Network: Holesky Testnet → [Update to Mainnet after successful testing]
Your Validator Indices: [Add your validator indices here]
