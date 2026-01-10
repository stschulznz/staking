# LEB8 vs LEB16 Deployment Analysis

_Last updated: 2026-01-10_

## 1. Inputs & Context
- Available self-bond capital today: **65 ETH**; target accumulation: **100 ETH**.
- Current hardware (per [node001-config.txt](node001-config.txt) and [node002-config.txt](node002-config.txt)):
  - **node001 (planned primary)**: 12th Gen Intel i5-1235U, 62 GiB RAM, 3.6 TB storage, Debian 13.
  - **node002 (standby)**: AMD Ryzen 7 5800X, 62 GiB RAM, 433 GB storage, Debian 13.
- Network: migrating from Hoodi testnet to Ethereum mainnet with dual-node HA design.
- Saturn 0 changes ([docs](https://docs.rocketpool.net/guides/saturn-0/whats-new)) remove mandatory RPL staking; commissions are 10% base with optional +4% dynamic boost if you later stake RPL (node must remain in the smoothing pool).
- Goal: maximize ETH-only staking yield while keeping hardware footprint manageable and maintaining failover safety.

## 2. Bond Options Overview
- **LEB8** (8 ETH bond): capital efficient, 24 ETH borrowed per validator. Base 10% commission, optional RPL boost. Higher dependency on deposit pool liquidity and slightly higher RPL requirement if you ever opt into boosts (>10% borrowed ETH) but optional now.
- **LEB16** (16 ETH bond): lower reliance on deposit pool (16 ETH borrowed). Fewer validators for same capital, but each earns 50% of EL rewards instead of 25% for LEB8.
- Hardware/operational load per validator is identical regardless of bond size; differences are strictly financial and liquidity-related.

## 3. Capital-to-Validator Mapping
| Self-Bond | LEB8 Validators (8 ETH each) | LEB16 Validators (16 ETH each) | Notes |
|-----------|-----------------------------|--------------------------------|-------|
| 65 ETH    | 8 validators (64 ETH) + 1 ETH reserve | 4 validators (64 ETH) + 1 ETH reserve | Leaves ~1 ETH buffer for gas. Consider keeping ≥2 ETH for tx fees, so practical count: 7 LEB8 or 4 LEB16. |
| 100 ETH   | 12 validators (96 ETH) + 4 ETH reserve | 6 validators (96 ETH) + 4 ETH reserve | Reserve covers gas + MEV distributor payouts. Conservative counts: 11 LEB8 or 6 LEB16 depending on queue tolerance. |

**Reward share implications**:
- EL rewards per validator scale with bond share: $\text{EL Share} = \frac{\text{Bond}}{32}$. LEB8 = 25%, LEB16 = 50%. With equivalent total capital (e.g., 96 ETH), LEB8 yields 12 validators each at 25% share, LEB16 yields 6 validators each at 50% share — aggregate EL exposure identical, but LEB8 spreads risk across more validators and benefits more from activation queue batching.

## 4. Operational Considerations
- **Deposit Queue & Liquidity**: LEB8 consumes 24 ETH from the deposit pool per validator, so deployments may pause during low deposit-pool liquidity. LEB16 consumes 16 ETH, generally facing shorter queue delays. Monitor `rocketpool network status` before launching large batches.
- **Gas & Buffering**: Retain ≥1–2 ETH per node to fund transactions (minipool creation, exits, fee distributor payouts). Deduct this from totals above when planning actual bond counts.
- **Smoothing Pool Requirement**: Both bond types must opt into the smoothing pool to receive the 5% dynamic boost (part of the 10% base commission under Saturn 0). Ensure smoothing pool participation stays enabled post-migration.
- **RPL Optionality**: With Saturn 0, zero-RPL nodes still earn the base 10% commission. Optional RPL staking (even minimal) now qualifies for issuance rewards and higher commission. You can defer indefinitely while avoiding exposure to RPL volatility.

## 5. Hardware Scaling & Need for Additional Nodes
- **node001**: 12-core (10 threads) mobile CPU but ample RAM and NVMe space (6% used of 3.6 TB). Suitable for >16 validators provided MEV-boost and Grafana loads stay moderate. Consider enabling CPU performance governor to prevent throttling if validators exceed ~20.
- **node002**: Desktop-grade Ryzen 7 5800X provides headroom for dozens of validators. Storage at 1% utilization (433 GB) is tight for full Geth but fine for Nethermind; monitor growth and consider adding SSD if execution client history expands beyond ~800 GB.
- **HA Strategy**: With dual nodes, you can distribute validators (e.g., primary handles majority, standby syncs and ready for failover). Saturn 0 doesn’t change validator-per-node limits.
- **Additional Node Need?** For 100 ETH (≤12 LEB8 validators), existing hardware suffices. Only consider a third node if you push beyond ~24 validators or want geographic diversity. Current hardware plus failover design is adequate; focus on optimizing monitoring and storage before buying new equipment.

## 6. Recommendation
1. **Short term (65 ETH)**: Deploy **7 LEB8** validators (56 ETH) on node001 post-migration, keep 9 ETH buffer (exit gas + deposits) while node002 mirrors as standby. This maximizes capital efficiency and leverages Saturn 0’s ETH-only model.
2. **Scale-up plan (toward 100 ETH)**: Gradually add up to **11–12 LEB8** validators across both nodes, staggering creations to avoid deposit-pool queue spikes. Consider splitting 8 on node001, 4 on node002 for balanced failover.
3. **Fallback to LEB16 only if** deposit-pool liquidity becomes a bottleneck or you deliberately want fewer validators to simplify monitoring. With your ETH-only preference, LEB8 remains the better fit unless queue delays exceed your tolerance.
4. **No new hardware required now**. Re-evaluate if you approach 20+ active validators or if storage utilization exceeds 70% on either node.

Let me know if you’d like projected APR comparisons or cash-flow modeling under different ETH price scenarios.
