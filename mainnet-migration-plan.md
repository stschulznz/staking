# Hoodi → Mainnet Migration Plan

_Last reviewed: 2026-01-10_

## 1. Source Material & Assumptions
- Primary reference: [Rocket Pool Docs — Migrating from the Test Network to Mainnet](https://docs.rocketpool.net/guides/testnet/mainnet) (Docker mode instructions).
- Local reference: [mainnet-reference.md](mainnet-reference.md) (fill placeholders as you gather Tangem addresses, checkpoint URLs, and other source-of-truth data).
- Current topology (verify before you start): node001 is the active Hoodi validator host (Reth + Lighthouse, Rocket Pool node wallet initialized, validator data on `/mnt/validator_keys` per [luks-usb-setup.md](luks-usb-setup.md)); node002 is warm standby (Nethermind + Lighthouse) with no wallet initialized and no validator keys present.
   - Source of truth for roles: [node001-config.txt](node001-config.txt) and [node002-config.txt](node002-config.txt).
- Goal: redeploy both nodes on Ethereum mainnet, preserving HA design, and route all EL/CL rewards plus future withdrawals to a verified Tangem hardware-wallet address.
- Network change deletes all Hoodi chain data, node wallet, and validator keys. Testnet validators are non-transferrable.
- Per [testnet→mainnet guide](https://docs.rocketpool.net/guides/testnet/mainnet), **you must create new node wallets on mainnet**; reusing the Hoodi wallet is unsupported and unsafe.

## 2. Pre-Migration Checklist
1. **Decide Tangem reward address**
   - Generate/confirm an Ethereum address on the Tangem card for the **Primary Withdrawal Address** (and optionally a separate **RPL Withdrawal Address**).
   - Verify the address on-device and record checksum offline.
   - Purpose: this is your “cold authority” for withdrawals; it should not live on the node.
2. **Inventory balances**
   - `rocketpool node status` on node001 (the only Hoodi node with a wallet initialized).
   - Confirm sufficient mainnet ETH (≥8 ETH per LEB8 or 16 ETH per LEB16, plus gas + 1 ETH buffer). Per [Saturn 0](https://docs.rocketpool.net/guides/saturn-0/whats-new), new minipools no longer require RPL collateral; staking RPL is now strictly optional for commission boosts and governance.
   - Purpose: avoid being blocked mid-migration due to missing funding or gas.
3. **Service health snapshot**
   - `docker ps --format "{{.Names}} {{.Status}}" | sort`
   - `rocketpool service status`
   - Purpose: capture a baseline so “after” can be compared to “before”.
4. **Backups ready**
   - External storage mounted for `/srv/rocketpool/data`, `/var/lib/docker`, Grafana dashboards, and Loki/log archives.
   - Encrypt any node wallet backups at rest.
   - Purpose: network switch is destructive; this is your rollback/forensics safety net.
5. **Tangem signing workflow**
   - Ensure the Tangem app is installed and a WalletConnect-capable device is available **if you will confirm withdrawal / RPL-withdrawal address changes via the Rocket Pool website**.
   - If using the LUKS USB per [luks-usb-setup.md](luks-usb-setup.md), insert the padlock-encrypted drive, unlock it via PIN, and confirm `/mnt/validator_keys` is mounted before running any Smartnode commands so the `~/.rocketpool/data` symlink resolves correctly.
   - Purpose: prevent accidentally writing sensitive wallet/validator data to the wrong disk.
6. **Handle remaining Hoodi rewards**
   - If you want archival copies of testnet rewards before wiping data, run `rocketpool node claim-rewards` to sweep any Hoodi RPL/SP earnings to the node withdrawal address, then `rocketpool node distribute-fees` to flush fee-distributor balances. These tokens remain testnet-only and cannot be bridged to mainnet, but claiming them now preserves a record before you delete the Hoodi data directory.

## 3. Hoodi Wind-Down
> Applies to whichever node is currently validating (confirm via [node001-config.txt](node001-config.txt) / [node002-config.txt](node002-config.txt)).
1. **Exit Hoodi minipool** (docs §Automatic Migration Step 1)
   ```bash
   rocketpool minipool exit
   # choose "All available minipools" and confirm
   ```
   - Purpose: cleanly remove testnet validators before deleting testnet data.
   - Success: `rocketpool minipool status` shows the minipool(s) exited (and the explorer reflects exit finalization).
2. **Set validator duties to standby (optional)**
   - If the exit takes hours, leave the node online until exit epoch completes to avoid unnecessary attestation misses.
3. **Audit rewards**
   - `rocketpool node rewards` and (if you need to distribute skimmed EL rewards) `rocketpool minipool distribute-balance`.
4. **Gracefully stop services once exit confirms**
   ```bash
   rocketpool service stop
   docker ps  # ensure all rp_* containers stopped
   ```
5. **Standby node002**
   - No Hoodi validators, but run `rocketpool service stop` to ensure identical base state before migration.

## 4. Primary Role Confirmation (node001 stays primary)
> **Note:** This section assumes services are now stopped from Section 3. Health checks from Section 2 Pre-Migration Checklist should have verified system health while services were running.

1. **Verify services are stopped**
   - `docker ps` should show no rocketpool containers running (or all stopped).
   - Confirm OS patches, firmware, and time sync (chrony) are current per [`node-failover-runbook.md`](node-failover-runbook.md).
   - Purpose: ensure clean state before migration and verify system fundamentals are healthy.
2. **Verify encrypted data path**
   - Ensure the LUKS USB from [luks-usb-setup.md](luks-usb-setup.md) is present, unlocked, and mounted at `/mnt/validator_keys`; `readlink -f ~/.rocketpool/data` must continue to point to `/mnt/validator_keys/data` before you take any backups or wipe Hoodi data.
   - Purpose: ensure wallets/keys live only on the encrypted mount.
3. **Document fallback relationships**
   - Node001 (primary) should already list node002 as its fallback EC/CC; capture screenshots or config exports so you can recreate the same topology post-migration.
   - Purpose: speed up restoring HA after the destructive network switch.
4. **Leave node002 in cold standby**
   - Keep node002’s services stopped (no wallet initialized, no validator keys) until you intentionally reintroduce it on mainnet; note this state in [`operations.md`](operations.md) for change tracking.
   - Purpose: avoid accidental key material creation/sprawl on the standby host.

## 5. Backup & Data Preservation
1. **Mount Corsair Padlock 3 backup drive**
   ```bash
   # Unlock the Corsair Padlock 3 with physical key first, then insert USB drive
   
   # Identify the device (usually /dev/sdb1 or /dev/sdc1)
   lsblk
   
   # Create mount point if it doesn't exist
   sudo mkdir -p /mnt/backup-usb
   
   # Mount the drive (adjust device path based on lsblk output)
   sudo mount /dev/sdb1 /mnt/backup-usb
   
   # Verify mount and available space
   df -h /mnt/backup-usb
   ls -la /mnt/backup-usb
   ```
   - Purpose: secure offline storage for wallet backups and Hoodi testnet archives.
   - Note: Ensure physical key remains in locked position after USB insertion until mount completes.

2. **Create tarball per node**
   ```bash
   # Run this on the node that currently has the wallet + validator keys (node001 today).
   # Validator data lives on the LUKS mount per luks-usb-setup.md
   sudo tar -czf /mnt/backup-usb/node001-hoodi-data-$(date -I).tgz -C /mnt/validator_keys data

   # Capture Smartnode configs, watchtower state, and service overrides
   sudo tar -czf /mnt/backup-usb/node001-hoodi-config-$(date -I).tgz -C ~/.rocketpool .
   ```
3. **Hash verification**
   ```bash
   sha256sum /mnt/backup-usb/node001-hoodi-*.tgz > /mnt/backup-usb/node001-hoodi.sha256
   cat /mnt/backup-usb/node001-hoodi.sha256  # verify hashes were written
   ```
4. **Unmount backup drive**
   ```bash
   # Ensure all writes complete
   sync
   
   # Unmount the drive
   sudo umount /mnt/backup-usb
   ```
   - Note: You can leave the USB drive connected if desired, just ensure it's unmounted when not actively writing to it.
5. **Optional: Store additional copies** in encrypted cloud vault in case you ever need to rejoin Hoodi or restore configuration.

## 6. Choose Migration Path per Docs
- **Preferred (Docker Automatic Migration)** on both nodes:
  1. Exit validators (already done).
  2. `rocketpool service config` → Smartnode and TX Fees → switch Network from `Hoodi Testnet` to `Ethereum Mainnet`.
  3. Review warning: confirms deletion of `data` folder, wallet, validators.
  4. After backing up, answer `y` to rebuild containers and clean volumes.
   - Purpose: this is the documented, supported path and preserves most non-secret settings while safely resetting chain data and wallets.
- **Manual path** only if automation fails (docs §Migrating Manually): stop services, `rocketpool service terminate`, `sudo rm -rf ~/.rocketpool`, reinstall CLI, then follow fresh install guide.

## 7. Mainnet Bring-Up Steps

> This section is intentionally split into “common base” steps (safe to do on both nodes) and “active validator host” steps (only do on node001).

### 7A. Both nodes (common base)
1. **Update Smartnode stack** ([docs](https://docs.rocketpool.net/guides/node/updates))
   ```bash
   # Stop services
   rocketpool service stop
   
   # Download latest Smartnode CLI (x64 systems)
   sudo wget https://github.com/rocket-pool/smartnode/releases/latest/download/rocketpool-cli-linux-amd64 -O ~/bin/rocketpool
   
   # Install updated stack (skip dependencies already installed)
   rocketpool service install -d
   
   # Start services
   rocketpool service start
   ```
   - Purpose: ensure the mainnet stack is current before syncing and transacting.
   - Verify versions match: `rocketpool service version`
2. **Confirm services are running on mainnet**
   ```bash
   rocketpool service status
   rocketpool node sync
   ```
   - Purpose: avoid submitting on-chain transactions with unsynced clients.
   - Success: `rocketpool node sync` reports EC + CC synced (and fallbacks, if enabled).
3. **Execution/Consensus settings + checkpoint sync**
   - Configure checkpoint sync via `rocketpool service config`:
     - Navigate to Consensus Client (ETH2) → Lighthouse settings
     - Enable checkpoint sync and enter: `https://beaconstate.ethstaker.cc`
     - Save and exit
   - **If you already started services without checkpoint sync configured:**
     ```bash
     # Stop services
     rocketpool service stop
     
     # Delete existing beacon chain data to enable checkpoint sync
     rocketpool service resync-eth2
     
     # Restart services - Lighthouse will now checkpoint sync (5-15 min vs 7-10 days)
     rocketpool service start
     ```
   - Verify sync progress: `rocketpool node sync` (expect "Synced: Yes" within 15 minutes)

### 7B. Node001 only (active validator host)
4. **Initialize a new mainnet node wallet** ([docs](https://docs.rocketpool.net/guides/node/wallet-init))
   ```bash
   rocketpool wallet init
   ```
   - Purpose: create the hot node wallet used to sign Rocket Pool operations (deposits, node registration, fee distributor init, smoothing pool join).
   - Safety: the wallet private key and password live on disk under `~/.rocketpool/data/{wallet,password}` (per docs); keep the LUKS mount attached and your OS hardened.
   - **CRITICAL:** Write down the 24-word mnemonic phrase on paper and store securely offline. This is your only recovery method if the node fails.

5. **Backup mainnet wallet to Corsair Padlock 3**
   ```bash
   # Mount the Corsair Padlock 3 (unlock with physical key first)
   sudo mkdir -p /mnt/backup-usb
   sudo mount /dev/sdb1 /mnt/backup-usb  # adjust device path if needed
   
   # Backup wallet and password from LUKS mount
   sudo tar -czf /mnt/backup-usb/node001-mainnet-wallet-$(date -I).tgz -C /mnt/validator_keys/data wallet password
   
   # Hash verification
   sha256sum /mnt/backup-usb/node001-mainnet-wallet-$(date -I).tgz >> /mnt/backup-usb/node001-mainnet.sha256
   
   # Secure and unmount
   sync
   sudo umount /mnt/backup-usb
   # Remove USB and lock with physical key
   ```
   - Purpose: encrypted backup of mainnet wallet for disaster recovery.
   - **WARNING:** This backup contains your hot wallet private key. Store the USB drive in a secure location separate from the node.
   - Alternative: Also backup mnemonic phrase separately from the USB (paper in safe).

6. **Fund the node wallet with gas + deposits**
   - Send ETH to the *node wallet address* (shown by `rocketpool wallet status`).
   - Purpose: pay gas for setup tx and fund minipool bond(s) (e.g., 8 ETH per LEB8 deposit plus variable gas).
   - Operational target: keep a long-lived gas buffer (your baseline in [operations.md](operations.md) is ≥2 ETH).
6. **Register node (timezone is non-sensitive)**
   ```bash
   rocketpool node register
   rocketpool node set-timezone Etc/UTC
   ```
   - Purpose: register the node on-chain and set a timezone for the public node map (docs note you can use a generic timezone for privacy).
   - Note: registration must happen before setting withdrawal addresses.
7. **Set withdrawal addresses to Tangem + confirm** ([docs](https://docs.rocketpool.net/guides/node/prepare-node))
   
   **Part A: Set pending address (on node via SSH):**
   ```bash
   rocketpool node set-primary-withdrawal-address <TangemAddress>
   rocketpool node set-rpl-withdrawal-address <TangemAddress>  # optional
   ```
   - Purpose: mark your Tangem address as "pending" withdrawal address (not active until confirmed).
   - **CRITICAL Prereq:** send a small amount of ETH (~0.01 ETH) to your Tangem address **before proceeding** to pay for confirmation gas.
   
   **Part B: Confirm address (via WalletConnect on PC + Tangem app on phone):**
   1. Open `https://node.rocketpool.net/primary-withdrawal-address` in your PC browser (Firefox/Chrome)
   2. Enter your **node address** (get it from `rocketpool node status` or `rocketpool wallet status`) in the "Node Address" field
   3. Click "Connect Wallet" → Choose "WalletConnect"
   4. QR code appears on PC screen
   5. Open Tangem app on phone → scan QR code to connect wallet to website
   6. On PC: Select "Confirm Pending" (should appear after wallet connects)
   7. On phone: Approve the transaction via Tangem app (NFC tap to confirm on card)
   8. Wait for transaction confirmation on PC
   9. **Repeat for RPL address** at `https://node.rocketpool.net/rpl-withdrawal-address` if set
   
   **Verification:**
   ```bash
   rocketpool node status  # Should show Tangem address as active withdrawal address
   ```
   - The confirmation transaction originates from your Tangem address (proving you control it), not the node wallet.
   - Purpose: ensure Beacon Chain withdrawals and protocol rewards go to your cold wallet, not the hot node wallet.
8. **Initialize fee distributor & join smoothing pool** ([docs](https://docs.rocketpool.net/guides/node/fee-distrib-sp))
   ```bash
   rocketpool node initialize-fee-distributor
   rocketpool node join-smoothing-pool
   ```
   - Purpose: enable correct EL reward routing/splitting and qualify new minipools for Saturn 0’s dynamic commission boost (requires smoothing pool opt-in).
9. **Enable MEV-Boost relays + verify** ([docs](https://docs.rocketpool.net/guides/node/mev))
   ```bash
   rocketpool service config  # MEV-Boost section
   rocketpool service logs mev-boost --tail 50
   ```
   - Purpose: share MEV/priority fees correctly with rETH stakers and improve returns.
   - Success: logs show relay checks and `POST /eth/v1/builder/validators 200` once validators exist.
10. **Create new minipools (repeat to reach 7× LEB8)**
   ```bash
   rocketpool node deposit
   ```
   - Purpose: deploy a new minipool contract and create a new validator.
   - Success: CLI prints minipool address + validator pubkey; then `rocketpool minipool status` progresses from `initialized` → `prelaunch` → `staking`.

11. **Final mainnet backup (after all minipools created)**
   ```bash
   # Mount Corsair Padlock 3
   sudo mount /dev/sdb1 /mnt/backup-usb
   
   # Complete backup including all validator keystores and slashing protection DB
   sudo tar -czf /mnt/backup-usb/node001-mainnet-final-$(date -I).tgz -C /mnt/validator_keys data
   
   # Also backup Smartnode configuration (settings, custom overrides)
   sudo tar -czf /mnt/backup-usb/node001-smartnode-config-$(date -I).tgz -C ~/.rocketpool user-settings.yml docker-compose.override.yml settings.yml 2>/dev/null || true
   
   # Hash verification
   sha256sum /mnt/backup-usb/node001-mainnet-final-$(date -I).tgz >> /mnt/backup-usb/node001-mainnet.sha256
   sha256sum /mnt/backup-usb/node001-smartnode-config-$(date -I).tgz >> /mnt/backup-usb/node001-mainnet.sha256 2>/dev/null || true
   
   # Unmount
   sync
   sudo umount /mnt/backup-usb
   ```
   - Purpose: comprehensive backup including:
     - All validator keystores (created during minipool deployment)
     - Slashing protection database (`validators/slashing_protection.sqlite`)
     - Node wallet and password files
     - Smartnode configuration files for quick recovery
   - **CRITICAL:** This backup contains all keys needed to recover your validators. Store securely.

### 7C. Node002 only (standby / fallback host)
11. **Keep node002 “no-wallet / no-keys”**
   - Purpose: reduce hot-key exposure; node002’s job is to be fully synced and ready to take over when you intentionally perform failover.
   - Do not run `rocketpool wallet init` or `rocketpool wallet recover` on node002 unless you are actively executing a controlled failover per [node-failover-runbook.md](node-failover-runbook.md).
12. **Recreate HA fallback links**
   - Configure fallback clients so each node can use the other node’s EC/CC endpoints.
   - Purpose: client resilience during pruning/resync or transient failures.

## 8. Saturn 0 Considerations (ETH-only minipools)
- [Saturn 0](https://docs.rocketpool.net/guides/saturn-0/whats-new) removes the mandatory RPL stake for new minipools; you can deploy purely with ETH bonds. This matches the “no additional token” preference.
- Commission model: base 5% from the minipool contract plus a 5% dynamic boost for all nodes (10% total) even without RPL. Opting into the Smoothing Pool remains required to earn the boost.
- Optional RPL staking now provides up to +4% additional dynamic commission when RPL value ≥10% of borrowed ETH and still grants Protocol DAO voting rights. You can defer or skip entirely if you want zero RPL exposure.
- Existing RPL positions continue to qualify for issuance rewards even below the previous 10% cliff; if you retain any RPL, restake at your convenience.

## 9. Tangem Hardware Wallet Considerations
- **Address management**: record Tangem address with checksum (EIP-55). Store as read-only watch-only entry in monitoring tools to confirm rewards.
- **Signing policy**: require on-device verification for every withdrawal change; never export the private key.
- **Funding workflow**: originate all ETH transfers from Tangem to the node wallet inside the Tangem mobile app; no WalletConnect or GUI on the node is required because Rocket Pool signs operations with the local node wallet.
- **WalletConnect usage**: WalletConnect/Tangem is primarily used to confirm pending withdrawal / RPL-withdrawal address changes via the Rocket Pool website.
- **Backup cards**: if Tangem set is 2-of-3, ensure spares stored separately.
- **Fee distributor / fee recipient**: managed automatically by Smartnode as either your Fee Distributor contract (default) or the Smoothing Pool contract (opt-in). Your Tangem address is the withdrawal destination for your share.

## 10. Post-Migration Validation
1. **Service status**
   - `rocketpool service status`
   - `docker logs rocketpool_eth1 --tail 50` (fast sync progress).
2. **Chain sync checkpoints**
   - Execution: `rocketpool service logs eth1` until `Imported new chain segment` with `synced=1`.
   - Consensus: `curl localhost:5052/eth/v1/node/syncing` expecting `is_syncing:false`.
3. **Wallet integrity**
   - `rocketpool wallet status` should show the node wallet on mainnet.
   - `rocketpool node status` should show the configured Primary Withdrawal Address (and RPL Withdrawal Address if set).
4. **Test transactions**
   - Send small ETH from Tangem to node wallet, confirm receipt, send back to ensure signing path works.
5. **Alerting**
   - Repoint Grafana, Alertmanager webhooks, and watchtower notifications to mainnet dashboards.
   - **Grafana password reset:** After network switch, Grafana resets to default credentials:
     - Default login: `admin` / `admin`
     - You'll be prompted to change the password on first login
     - Access: `http://your-node-ip:3100` (or configured port)
   - **Update Beaconcha.in endpoint:** Change monitoring from `hoodi.beaconcha.in` to `beaconcha.in` (mainnet)
     - **API key stays the same** - Beaconcha.in uses one account for all networks
     - Update Grafana dashboards on node001: change endpoint from `https://hoodi.beaconcha.in/api/v1/client/metrics` to `https://beaconcha.in/api/v1/client/metrics` (keep existing API key)
     - **Node002:** Skip Beaconcha.in client metrics (no validators to track); continue using Grafana/Prometheus for basic node health only
     - Add your validator indices to beaconcha.in watchlist once minipools are created
6. **Smoothing pool & MEV verification**
   - `rocketpool node status` should list `Smoothing Pool: opted in`; `rocketpool node join-smoothing-pool` again if necessary (wait one interval if previously opted out).
   - `rocketpool service logs mev-boost --tail 20` should show healthy relay heartbeats; investigate any `status!=200` entries.

## 11. HA & Failover Alignment
- Update [`node-failover-runbook.md`](node-failover-runbook.md) with mainnet specifics (ports, checkpoint URLs, new wallet IDs).
- Ensure both nodes maintain same Smartnode version and client patch levels to prevent drift.
- After production minipools exist and have been stable for at least a day, dry-run failover during a maintenance window using [node-failover-runbook.md](node-failover-runbook.md).

## 12. Operational Follow-Ups
1. Refresh `node001-config.txt` and `node002-config.txt` post-migration via `./scripts/update-config.sh node00{1,2}`.
2. Update `operational-tasks.md` with any lingering TODOs (e.g., Tangem address verification logs, new checkpoint providers).
3. Document Tangem wallet custody procedures (who holds which card, PIN management, NFC security).
4. Schedule quarterly recovery drills: restore from backup tarball to spare machine and confirm you can read encrypted archives (no need to connect to mainnet).
5. Add MEV-Boost relay health and smoothing-pool opt-in state to monitoring dashboards/alerts to detect unexpected opt-outs or relay downtime quickly.

---
This plan keeps both nodes aligned with Rocket Pool's documented migration process while ensuring all future EL/CL rewards land on the Tangem-controlled withdrawal address.
