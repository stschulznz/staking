# Hoodi → Mainnet Migration Plan

_Last reviewed: 2026-01-10_

## 1. Source Material & Assumptions
- Primary reference: [Rocket Pool Docs — Migrating from the Test Network to Mainnet](https://docs.rocketpool.net/guides/testnet/mainnet) (Docker mode instructions).
- Local reference: [mainnet-reference.md](mainnet-reference.md) (fill placeholders as you gather Tangem addresses, checkpoint URLs, and other source-of-truth data).
- Current topology: node001 is the active Hoodi validator host (Reth + Lighthouse, Tangem-backed wallet, validator data on `/mnt/validator_keys` per [luks-usb-setup.md](luks-usb-setup.md)); node002 remains warm standby (Nethermind + Lighthouse) with no wallet initialized and no validator keys present.
- Goal: redeploy both nodes on Ethereum mainnet, preserving HA design, and route all EL/CL rewards plus future withdrawals to a verified Tangem hardware-wallet address.
- Network change deletes all Hoodi chain data, node wallet, and validator keys. Testnet validators are non-transferrable.
- Per [testnet→mainnet guide](https://docs.rocketpool.net/guides/testnet/mainnet), **you must create new node wallets on mainnet**; reusing the Hoodi wallet is unsupported and unsafe.

## 2. Pre-Migration Checklist
1. **Decide Tangem reward address**
   - Generate/confirm an Ethereum address on the Tangem card for all withdrawal targets (primary, RPL, fee distributor).
   - Verify the address on-device and record checksum offline.
2. **Inventory balances**
   - `rocketpool node status` on node002 for ETH and any legacy RPL amounts.
   - Confirm sufficient mainnet ETH (≥8 ETH per LEB8 or 16 ETH per LEB16, plus gas + 1 ETH buffer). Per [Saturn 0](https://docs.rocketpool.net/guides/saturn-0/whats-new), new minipools no longer require RPL collateral; staking RPL is now strictly optional for commission boosts and governance.
3. **Service health snapshot**
   - `docker ps --format "{{.Names}} {{.Status}}" | sort`
   - `rocketpool service status`
4. **Backups ready**
   - External storage mounted for `/srv/rocketpool/data`, `/var/lib/docker`, Grafana dashboards, and Loki/log archives.
   - Encrypt any node wallet backups at rest.
5. **Tangem signing workflow**
   - Ensure Tangem app is installed and WalletConnect-capable device is available for on-chain transactions (fee distributor, smoothing-pool joins, MEV config approvals, snapshot, etc.).
   - If using the LUKS USB per [luks-usb-setup.md](luks-usb-setup.md), insert the padlock-encrypted drive, unlock it via PIN, and confirm `/mnt/validator_keys` is mounted before running any Smartnode commands so the `~/.rocketpool/data` symlink resolves correctly.
6. **Handle remaining Hoodi rewards**
   - If you want archival copies of testnet rewards before wiping data, run `rocketpool node claim-rewards` to sweep any Hoodi RPL/SP earnings to the node withdrawal address, then `rocketpool node distribute-fees` to flush fee-distributor balances. These tokens remain testnet-only and cannot be bridged to mainnet, but claiming them now preserves a record before you delete the Hoodi data directory.

## 3. Hoodi Wind-Down (node002 while it remains active)
1. **Exit Hoodi minipool** (docs §Automatic Migration Step 1)
   ```bash
   rocketpool minipool exit
   # choose "All available minipools" and confirm
   ```
   - Wait for exit to finalize on Hoodi (watch `rocketpool minipool status`).
2. **Set validator duties to standby (optional)**
   - If the exit takes hours, leave node online until exit epoch completes to avoid attestation misses.
3. **Audit rewards**
   - `rocketpool node rewards` and `rocketpool minipool rewards skim` if applicable.
4. **Gracefully stop services once exit confirms**
   ```bash
   rocketpool service stop
   docker ps  # ensure all rp_* containers stopped
   ```
5. **Standby node001**
   - No Hoodi validators, but run `rocketpool service stop` to ensure identical base state before migration.

## 4. Primary Role Confirmation (node001 stays primary)
1. **Health-check node001 (active)**
   - `rocketpool service status` and `docker ps` should show the Hoodi stack running normally; resolve any alarms before touching data.
   - Confirm OS patches, firmware, and time sync (chrony) are current per [`node-failover-runbook.md`](node-failover-runbook.md).
2. **Verify encrypted data path**
   - Ensure the LUKS USB from [luks-usb-setup.md](luks-usb-setup.md) is present, unlocked, and mounted at `/mnt/validator_keys`; `readlink -f ~/.rocketpool/data` must continue to point to `/mnt/validator_keys/data` before you take any backups or wipe Hoodi data.
3. **Document fallback relationships**
   - Node002 should already list node001 as its fallback EC/CC; capture screenshots or config exports so you can recreate the same topology post-migration.
4. **Leave node002 in cold standby**
   - Keep node002’s services stopped (no wallet initialized, no validator keys) until you intentionally reintroduce it on mainnet; note this state in [`operations.md`](operations.md) for change tracking.

## 5. Backup & Data Preservation
1. **Create tarball per node**
   ```bash
   # Validator data lives on the LUKS mount per luks-usb-setup.md
   sudo tar -czf /mnt/backups/node002-hoodi-data-$(date -I).tgz -C /mnt/validator_keys data

   # Capture Smartnode configs, watchtower state, and service overrides
   sudo tar -czf /mnt/backups/node002-hoodi-config-$(date -I).tgz -C ~/.rocketpool .
   ```
2. **Hash verification**
   - `sha256sum /mnt/backups/node002-hoodi-*.tgz > /mnt/backups/node002-hoodi.sha256`
3. **Store copies offline** (air-gapped drive or encrypted cloud vault) in case you ever need to rejoin Hoodi.

## 6. Choose Migration Path per Docs
- **Preferred (Docker Automatic Migration)** on both nodes:
  1. Exit validators (already done).
  2. `rocketpool service config` → Smartnode and TX Fees → switch Network from `Hoodi Testnet` to `Ethereum Mainnet`.
  3. Review warning: confirms deletion of `data` folder, wallet, validators.
  4. After backing up, answer `y` to rebuild containers and clean volumes.
- **Manual path** only if automation fails (docs §Migrating Manually): stop services, `rocketpool service terminate`, `sudo rm -rf ~/.rocketpool`, reinstall CLI, then follow fresh install guide.

## 7. Mainnet Bring-Up Steps (Per Node)
1. **Update Smartnode stack**
   ```bash
   rocketpool service install --upgrade
   ```
   - Confirms latest images before syncing mainnet.
2. **Execution/Consensus settings**
   - Reapply client choices (node001 primary: Reth + Lighthouse, node002 standby: Nethermind + Lighthouse) via `rocketpool service config`.
   - Configure checkpoint sync URL (e.g., `https://mainnet.checkpoint.sigp.io`) under Beacon Chain settings to avoid multi-day sync.
3. **Wallet initialization (new wallet only)** ([docs](https://docs.rocketpool.net/guides/node/wallet-init))
   ```bash
   rocketpool wallet init
   ```
   - CLI prompts for a wallet password and shows the 24-word mnemonic once; write both to the secure mediums defined in [mainnet-reference.md](mainnet-reference.md).
   - The wallet files remain under `~/.rocketpool/data/{wallet,password}` on the node per the official guide; no Tangem interaction is required for this step.
4. **Set withdrawal + fee addresses to Tangem**
   ```bash
   # Use the checksum address recorded in mainnet-reference.md
   rocketpool node set-withdrawal-address <TangemAddress>
   rocketpool node set-primary-withdrawal-address <TangemAddress>
   rocketpool node set-fee-distributor <feeDistributorAddress>
   # Optional if you later stake RPL
   rocketpool node set-rpl-withdrawal-address <TangemAddress>
   ```
   - These commands are executed by the node wallet (no WalletConnect required). Before running each one, verify the Tangem address on-card and cross-check it with [mainnet-reference.md](mainnet-reference.md).
   - After each transaction, record the tx hash and timestamp in the reference file so you can audit changes later.
5. **Initialize fee distributor & join smoothing pool** ([docs](https://docs.rocketpool.net/guides/node/fee-distrib-sp))
   ```bash
   rocketpool node initialize-fee-distributor
   rocketpool node join-smoothing-pool
   ```
   - Each command sends an on-chain transaction from the node wallet; follow the same practice of logging tx hashes in [mainnet-reference.md](mainnet-reference.md).
   - Initialization ensures priority fees/MEV share the Tangem withdrawal split; Smartnode auto-calls `distribute-fees` on new deposits, so note potential taxable events when balances flush.
   - Opting into the smoothing pool is required for the Saturn 0 dynamic commission boost; exiting requires waiting a full rewards interval.
6. **Enable MEV-Boost relays** ([docs](https://docs.rocketpool.net/guides/node/mev))
   ```bash
   rocketpool service config  # MEV-Boost section
   rocketpool service logs mev-boost --tail 50
   ```
   - Ensure `Enable MEV-Boost` stays checked, pick sanctioned vs. unsanctioned relay profiles per policy, and leave mode on Locally Managed unless you run your own mev-boost instance.
   - Verify logs show successful relay registration (e.g., `POST /eth/v1/builder/validators 200`); resolve errors before proceeding.
7. **Fund wallet**
   - Use the Tangem mobile app to send ETH from the hardware wallet to the node wallet address (record both tx hash and amount in [mainnet-reference.md](mainnet-reference.md)). This step happens outside the node; no GUI is required on Fedora.
   - Keep ≥2 ETH on the node wallet for gas/distributor operations. RPL transfers remain optional; only send if you later decide to stake for commission boosts or governance.
   - Verify deposits with `rocketpool node status`.
8. **Register node and set timezone**
   ```bash
   rocketpool node register
   rocketpool node set-timezone Pacific/Auckland
   ```
9. **Recreate HA fallback links**
   - Configure node002 fallback clients to node001 mainnet endpoints (update IPs/ports if changed).
   - Mirror on node001 for symmetrical failover and document the new primary/standby relationship.
10. **Create new minipools**
   ```bash
   rocketpool minipool create --bond <8-or-16> --count 1
   ```
   - Select `--bond 8` for LEB8 validators or `--bond 16` for legacy 16-ETH minipools based on the staking analysis below; repeat after verifying collateral ratios.

## 8. Saturn 0 Considerations (ETH-only minipools)
- [Saturn 0](https://docs.rocketpool.net/guides/saturn-0/whats-new) removes the mandatory RPL stake for new minipools; you can deploy purely with ETH bonds. This matches the “no additional token” preference.
- Commission model: base 5% from the minipool contract plus a 5% dynamic boost for all nodes (10% total) even without RPL. Opting into the Smoothing Pool remains required to earn the boost.
- Optional RPL staking now provides up to +4% additional dynamic commission when RPL value ≥10% of borrowed ETH and still grants Protocol DAO voting rights. You can defer or skip entirely if you want zero RPL exposure.
- Existing RPL positions continue to qualify for issuance rewards even below the previous 10% cliff; if you retain any RPL, restake at your convenience.

## 9. Tangem Hardware Wallet Considerations
- **Address management**: record Tangem address with checksum (EIP-55). Store as read-only watch-only entry in monitoring tools to confirm rewards.
- **Signing policy**: require on-device verification for every withdrawal change; never export the private key.
- **Funding workflow**: originate all ETH transfers from Tangem to the node wallet inside the Tangem mobile app; no WalletConnect or GUI on the node is required because Rocket Pool signs operations with the local node wallet.
- **Backup cards**: if Tangem set is 2-of-3, ensure spares stored separately.
- **Fee distributor**: set to same Tangem-controlled address or a dedicated Tangem wallet; remember smoothing-pool payouts follow fee distributor.

## 10. Post-Migration Validation
1. **Service status**
   - `rocketpool service status`
   - `docker logs rocketpool_eth1 --tail 50` (fast sync progress).
2. **Chain sync checkpoints**
   - Execution: `rocketpool service logs eth1` until `Imported new chain segment` with `synced=1`.
   - Consensus: `curl localhost:5052/eth/v1/node/syncing` expecting `is_syncing:false`.
3. **Wallet integrity**
   - `rocketpool wallet status` should show mainnet network and Tangem addresses.
4. **Test transactions**
   - Send small ETH from Tangem to node wallet, confirm receipt, send back to ensure signing path works.
5. **Alerting**
   - Repoint Grafana, Alertmanager webhooks, and watchtower notifications to mainnet dashboards.
6. **Smoothing pool & MEV verification**
   - `rocketpool node status` should list `Smoothing Pool: opted in`; `rocketpool node join-smoothing-pool` again if necessary (wait one interval if previously opted out).
   - `rocketpool service logs mev-boost --tail 20` should show healthy relay heartbeats; investigate any `status!=200` entries.

## 11. HA & Failover Alignment
- Update [`node-failover-runbook.md`](node-failover-runbook.md) with mainnet specifics (ports, checkpoint URLs, new wallet IDs).
- Ensure both nodes maintain same Smartnode version and client patch levels to prevent drift.
- Dry-run failover by temporarily promoting node001 once sync completes, ensuring validators can migrate without downtime (do not activate until production minipools exist).

## 12. Operational Follow-Ups
1. Refresh `node001-config.txt` and `node002-config.txt` post-migration via `./scripts/update-config.sh node00{1,2}`.
2. Update `operational-tasks.md` with any lingering TODOs (e.g., Tangem address verification logs, new checkpoint providers).
3. Document Tangem wallet custody procedures (who holds which card, PIN management, NFC security).
4. Schedule quarterly recovery drills: restore from backup tarball to spare machine and confirm you can read encrypted archives (no need to connect to mainnet).
5. Add MEV-Boost relay health and smoothing-pool opt-in state to monitoring dashboards/alerts to detect unexpected opt-outs or relay downtime quickly.

---
This plan keeps both nodes aligned with Rocket Pool's documented migration process while ensuring all future EL/CL rewards land on the Tangem-controlled withdrawal address.
