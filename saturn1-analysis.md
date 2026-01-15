# Saturn 1 Analysis: LEB4 Megapools vs LEB8 Minipools

_Created: 2026-01-15_

## Executive Summary

Saturn 1 introduces **megapools** with 4 ETH minimum bonds (LEB4), replacing the current 8 ETH minipool model. For a 56 ETH allocation, this doubles validator count from 7 to 14.

| Metric | LEB8 (Current) | LEB4 (Saturn 1) | Advantage |
|--------|----------------|-----------------|-----------|
| Bond per validator | 8 ETH | 4 ETH | **LEB4** (2x capital efficiency) |
| Validators from 56 ETH | 7 | 14 | **LEB4** |
| Commission (with smoothing pool) | 10% | 10% | Equal |
| Protocol ETH borrowed | 24 ETH/validator | 28 ETH/validator | **LEB4** (more leverage) |
| Your ETH exposure | 25% of validator | 12.5% of validator | Depends on preference |
| Contract model | 1 minipool = 1 validator | 1 megapool = many validators | **LEB4** (simpler) |

**Recommendation:** Wait for Saturn 1 and use LEB4 megapools for maximum capital efficiency.

---

## Capital Efficiency Comparison

### Your Allocation: 56 ETH

| Model | Validators | Your Bond | Protocol Borrowed | Total Staked |
|-------|------------|-----------|-------------------|--------------|
| LEB8 | 7 | 56 ETH | 168 ETH (7×24) | 224 ETH |
| LEB4 | 14 | 56 ETH | 392 ETH (14×28) | 448 ETH |

**LEB4 doubles your staking exposure** with the same capital.

### Leverage Ratio

| Model | Your Bond | Borrowed ETH | Leverage |
|-------|-----------|--------------|----------|
| LEB8 | 8 ETH | 24 ETH | 4:1 |
| LEB4 | 4 ETH | 28 ETH | 8:1 |

LEB4 provides **2x more leverage** per validator.

---

## Reward Analysis

### Assumptions
- ETH staking APY: ~3.5% (consensus + execution layer)
- MEV boost: ~0.3% additional
- Commission: 10% (5% base + 5% dynamic with smoothing pool)
- All validators active and performing well

### Annual Reward Estimate (56 ETH investment)

**LEB8 (7 validators × 32 ETH each = 224 ETH staked)**
```
Protocol rewards on borrowed ETH (168 ETH × 3.8%):    6.384 ETH
Your commission (10% of 6.384):                       0.638 ETH
Direct rewards on your bond (56 ETH × 3.8%):          2.128 ETH
─────────────────────────────────────────────────────────────
Total annual rewards:                                 2.766 ETH
Effective APY on your 56 ETH:                         4.94%
```

**LEB4 (14 validators × 32 ETH each = 448 ETH staked)**
```
Protocol rewards on borrowed ETH (392 ETH × 3.8%):   14.896 ETH
Your commission (10% of 14.896):                      1.490 ETH
Direct rewards on your bond (56 ETH × 3.8%):          2.128 ETH
─────────────────────────────────────────────────────────────
Total annual rewards:                                 3.618 ETH
Effective APY on your 56 ETH:                         6.46%
```

### Reward Comparison

| Model | Annual Rewards | Effective APY | Difference |
|-------|----------------|---------------|------------|
| LEB8 | ~2.77 ETH | ~4.9% | Baseline |
| LEB4 | ~3.62 ETH | ~6.5% | **+31% more rewards** |

**LEB4 yields approximately 31% more rewards** on the same capital.

---

## Risk Analysis

### Slashing Risk

| Risk Factor | LEB8 | LEB4 | Notes |
|-------------|------|------|-------|
| Validators at risk | 7 | 14 | More validators = more operational surface |
| Slashing penalty per validator | ~1 ETH minimum | ~1 ETH minimum | Same per-validator |
| Your exposure per slash | 8 ETH bond at risk | 4 ETH bond at risk | **LEB4 lower per-incident** |
| Correlation penalty | Lower (fewer validators) | Higher (more validators) | Edge case if many slash simultaneously |

**Slashing assessment:** LEB4 has lower per-validator bond at risk, but more validators means more operational attention needed. With proper slashing protection DB management and failover procedures (per your runbook), risk is manageable.

### Protocol Risk

| Risk | LEB8 | LEB4 |
|------|------|------|
| Smart contract maturity | Proven (years of operation) | Newer (megapool contracts) |
| Bug risk | Lower (battle-tested) | Slightly higher (new code) |
| Protocol upgrade complexity | N/A | Part of Saturn 1 migration |

**Protocol assessment:** Megapool contracts are new but will undergo audits. Rocket Pool has a strong security track record. Risk is acceptable.

### Liquidity / Exit Risk

| Factor | LEB8 | LEB4 |
|--------|------|------|
| Exit queue | Per minipool | Per validator in megapool |
| Partial withdrawal | Not supported | Potentially simpler |
| Bond reduction | Complex process | Native to megapool design |

---

## Operational Differences

### Contract Architecture

**LEB8 Minipools:**
- 1 smart contract per validator
- 7 contracts to manage for 7 validators
- Each minipool has separate address

**LEB4 Megapools:**
- 1 smart contract holds multiple validators
- 1 megapool contract for all 14 validators
- Simpler management, single address

### Validator Management

| Operation | LEB8 | LEB4 |
|-----------|------|------|
| Add validator | New minipool contract deployment | Add to existing megapool |
| Gas costs (deposit) | Higher (new contract each time) | Lower (add to existing) |
| Exit validator | Per minipool | Per validator |
| Rewards distribution | Per minipool or smoothing pool | Megapool aggregates |

### Monitoring

| Aspect | LEB8 | LEB4 |
|--------|------|------|
| Validators to monitor | 7 | 14 |
| Contract addresses | 7 | 1 |
| Beaconcha.in watchlist | 7 entries | 14 entries |
| Grafana dashboards | Same | Same |

---

## Migration Path

### Current State (Your Node)
- ✅ Node registered
- ✅ Withdrawal address: `0x803b07DE402Ad93BB4315C0B4D38195e56bf8E7d`
- ✅ Smoothing pool: Opted in
- ✅ MEV-Boost: Configured
- ✅ Fee distributor: `0x5d5BD99F6A078E796a95e0266b6333cbb3bC67C0`
- ⏸️ Minipools: None (deposits paused)

### Saturn 1 Migration

Your existing node configuration carries forward:
- Node registration remains valid
- Withdrawal address stays the same
- Smoothing pool opt-in persists
- MEV-Boost continues working

**New steps for Saturn 1:**
1. Wait for Saturn 1 launch announcement
2. Update Smartnode if required: `rocketpool service install -d`
3. Create megapool: `rocketpool node create-megapool` (or similar command)
4. Deposit validators: likely new command syntax for megapool deposits

---

## Timing Considerations

### Wait for Saturn 1?

**Pros of waiting:**
- 2x capital efficiency (14 vs 7 validators)
- ~31% higher effective APY
- Simpler contract management (1 megapool vs 7 minipools)
- Lower gas costs for multiple validators
- Future-proof architecture

**Cons of waiting:**
- Opportunity cost (not earning while waiting)
- Unknown launch date
- New system may have initial bugs

### Break-Even Analysis

If Saturn 1 launches within **~3 months**, waiting is profitable:
- Lost rewards from 3 months of LEB8: ~0.69 ETH
- Annual gain from LEB4 vs LEB8: ~0.85 ETH
- Break-even: ~10 months

**If Saturn 1 launches within weeks (likely given deposit pause), waiting is clearly beneficial.**

---

## Recommendation

### For Your Setup (56 ETH allocation):

**✅ Wait for Saturn 1 and create LEB4 megapool with 14 validators**

Rationale:
1. Deposits are already paused, so you can't create LEB8 anyway
2. 31% higher rewards with same capital
3. Your node is fully configured and ready
4. Megapool architecture is simpler to manage
5. Break-even is within months even if Saturn 1 delayed

### Action Items While Waiting

1. ✅ Keep node synced: `rocketpool node sync`
2. ✅ Monitor Rocket Pool Discord for Saturn 1 announcements
3. ✅ Backup maintained (you confirmed this)
4. ⏳ Watch for Smartnode updates when Saturn 1 approaches
5. 📖 Review Saturn 1 docs when available: https://docs.rocketpool.net/guides/saturn-1/

---

## Future Scaling

With LEB4 megapools, your scaling path improves:

| Capital | LEB8 Validators | LEB4 Validators |
|---------|-----------------|-----------------|
| 56 ETH | 7 | 14 |
| 80 ETH | 10 | 20 |
| 100 ETH | 12 | 25 |
| 120 ETH | 15 | 30 |

Each additional 4 ETH = 1 more validator (vs 8 ETH currently).

---

## References

- [Saturn 1 Overview](https://docs.rocketpool.net/guides/saturn-1/)
- [RPIP-42: Megapools](https://rpips.rocketpool.net/RPIPs/RPIP-42)
- [Tokenomics Rework Explainer](https://rpips.rocketpool.net/tokenomics-explainers/005-rework-prelude)
- [Rocket Pool Discord](https://discord.gg/rocketpool)
