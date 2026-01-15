# Rocket Pool Operational Tasks

> **Purpose:** Track operational improvements, pending tasks, and infrastructure changes  
> **Last Updated:** 2026-01-11

---

## Task Overview

| Task | Status | Priority | Target Date |
|------|--------|----------|-------------|
| Buy PCIe adapter + 2TB NVMe for node002 | 🟢 To Do | High | 2026-01-20 |
| Install and configure additional storage on node002 | 🟢 To Do | High | After hardware arrives |
| Configure NUT on node002 (remote UPS client) | 🟢 To Do | Medium | TBD |
| Secure Grafana Access via NPM Proxy | 🟢 To Do | High | TBD |
| Secure Uptime Kuma Access via NPM Proxy | 🟢 To Do | High | TBD |
| Post-migration docs & config refresh | 🟢 To Do | Medium | After mainnet cutover |
| Document Beaconcha.in Machine Name for node001 | ✅ Done | - | 2025-12-20 |
| Complete Troubleshooting Commands Documentation | 🟢 To Do | Medium | - |
| Implement Automated Backup Verification | 🟢 To Do | Low | - |
| Centralize Log Aggregation | 🟢 To Do | Low | - |
| Create Configuration Auto-Generation Script | ✅ Done | - | 2025-12-20 |
| Document Encrypted USB Setup | ✅ Done | - | 2025-12-20 |
| Update Staking Expert Agent to Use Config Files | ✅ Done | - | 2025-12-20 |

---

## Task Status Legend
- 🔴 **Blocked** - Cannot proceed due to dependency or issue
- 🟡 **In Progress** - Currently working on this
- 🟢 **To Do** - Planned, ready to start
- ✅ **Done** - Completed
- ❌ **Cancelled** - No longer needed

---

## High Priority Tasks

### 🟢 Buy PCIe adapter + 2TB NVMe for node002
**Status:** To Do  
**Priority:** High  
**Target Date:** 2026-01-20

**Current State:**
- node002 execution disk (ethereum-lv) at 75% capacity (1.3TB used / 1.8TB total)
- Mainnet Nethermind expected to grow to 1.5TB+ when fully synced
- Risk of running out of space during mainnet migration

**Desired State:**
- Additional 2TB NVMe installed in available PCIe x4 slot (PCIEX16_2)
- Total execution storage capacity increased to ~4TB
- Adequate headroom for mainnet growth

**Selected Components:**
1. **Silverstone SST-ECM28** - 1 x NVMe & 1 x SATA M.2 SSD to PCIe x4 adapter
   - Supports both NVMe and SATA M.2 drives concurrently
   - Will use NVMe slot for execution storage
2. **Samsung 990 PRO 2TB with Heatsink** - PCIe Gen 4 x4 NVMe SSD
   - Price: $279.30 NZD (Microsoft employee discount)
   - ~7,450 MB/s read, ~6,900 MB/s write
   - Includes heatsink (may need removal to fit adapter)
   - Matches/exceeds existing Samsung 980 PRO performance

**Total Cost:** ~$279.30 NZD + adapter price

**Steps:**
1. [x] Research and select specific adapter model
2. [x] Research and select specific NVMe drive
3. [ ] Purchase Samsung 990 PRO from Samsung Store (Microsoft employee discount)
4. [ ] Purchase Silverstone ECM28 adapter
5. [ ] Track delivery

**Related Tasks:**
- After purchase: [Install and configure additional storage on node002](#🟢-install-and-configure-additional-storage-on-node002)

**Related Documentation:**
- [add-disk.md](add-disk.md) - Detailed installation and configuration guide

**Notes:**
- Available slot confirmed: PCIEX16_2 (PCIe Gen 4 x4, ~8GB/s bandwidth)
- Cheaper/safer than replacing existing 2TB with 4TB drive
- Much safer than LVM resize operations on live system

---

### 🟢 Install and configure additional storage on node002
**Status:** To Do  
**Priority:** High  
**Target Date:** After hardware arrives

**Current State:**
- Hardware not yet purchased
- node002 currently syncing mainnet on existing 2TB ethereum-lv

**Desired State:**
- New 2TB NVMe drive installed in PCIe adapter
- LVM extended to use new disk
- Execution data migrated or continued on expanded volume
- Total ~4TB capacity for execution client

**Prerequisites:**
- [ ] PCIe adapter and NVMe drive purchased and delivered
- [ ] node002 is in standby mode (not actively validating)

**Steps:**
See detailed procedure in [add-disk.md](add-disk.md)

**Summary:**
1. [ ] Shut down node002 services
2. [ ] Install hardware (adapter + NVMe)
3. [ ] Boot and verify drive detection
4. [ ] Create physical volume on new drive
5. [ ] Extend ethereum-vg volume group
6. [ ] Extend ethereum-lv logical volume
7. [ ] Resize filesystem
8. [ ] Restart services and verify

**Related Documentation:**
- [add-disk.md](add-disk.md) - Complete installation guide
- [node002-config.txt](node002-config.txt) - Current node configuration
- [node-failover-runbook.md](node-failover-runbook.md) - Reference for service management

**Notes:**
- CRITICAL: node002 must be in standby mode (no active validators)
- Estimated downtime: 30-60 minutes for hardware + configuration
- No data migration required if extending existing LVM volume
- Test thoroughly before promoting node002 to active

---

### 🟢 Secure Grafana Access via NPM Proxy
**Status:** To Do  
**Priority:** High  
**Target Date:** TBD

**Current State:**
- Grafana accessed directly via IP:
  - node001: http://192.168.60.101:3100
  - node002: http://192.168.60.102:3100
- No TLS encryption on local network
- Direct IP access not ideal for remote monitoring

**Desired State:**
- Access Grafana through Nginx Proxy Manager (NPM)
- HTTPS with valid certificates
- Single unified dashboard URL (or separate secured URLs per node)

**Steps Required:**
1. [ ] Obtain SSL certificates for Grafana endpoints
   - Option A: Let's Encrypt via NPM
   - Option B: Self-signed certificates
   - Option C: Wildcard certificate for *.yourdomain.com
2. [ ] Configure NPM proxy hosts
   - [ ] grafana-node001.yourdomain.com → http://192.168.60.101:3100
   - [ ] grafana-node002.yourdomain.com → http://192.168.60.102:3100
3. [ ] Update Grafana configuration to allow proxy
   - [ ] Update `~/.rocketpool/user-settings.yml` on both nodes
   - [ ] Set `root_url` in Grafana config
4. [ ] Test access via new URLs
5. [ ] Update Surface monitoring setup to use new URLs
6. [ ] Document new URLs in operations.md

**Related Documentation:**
- [operations.md](operations.md) - Update Monitoring Dashboard section
- Grafana proxy configuration docs
- NPM documentation

**Notes:**
- Consider whether remote access is needed or LAN-only
- Ensure Grafana ports remain closed on WAN firewall

---

### 🟢 Secure Uptime Kuma Access via NPM Proxy
**Status:** To Do  
**Priority:** High  
**Target Date:** TBD

**Current State:**
- Uptime Kuma accessed directly via IP (not documented)
- No TLS encryption
- Direct IP access not ideal for secure remote monitoring

**Desired State:**
- Access Uptime Kuma through Nginx Proxy Manager (NPM)
- HTTPS with valid certificate
- Secure URL: uptime.yourdomain.com (or similar)

**Steps Required:**
1. [ ] Obtain SSL certificate for Uptime Kuma endpoint
   - Option A: Let's Encrypt via NPM
   - Option B: Self-signed certificate
   - Option C: Use wildcard certificate if obtained for Grafana
2. [ ] Configure NPM proxy host
   - [ ] uptime.yourdomain.com → http://[uptime-kuma-ip]:[port]
3. [ ] Update Uptime Kuma configuration if needed
   - [ ] Check if base URL needs to be set
4. [ ] Test access via new URL
5. [ ] Update monitoring documentation in operations.md

**Related Documentation:**
- [operations.md](operations.md) - Update Monitoring Setup section
- Uptime Kuma proxy configuration docs
- NPM documentation

**Notes:**
- Consider consolidating with Grafana certificate work
- May be able to use same wildcard certificate
- Verify Uptime Kuma port remains closed on WAN firewall if LAN-only access

---

## Medium Priority Tasks

### 🟢 Configure NUT on node002 (remote UPS client)
**Status:** To Do  
**Priority:** Medium  
**Target Date:** TBD

**Current State:**
- node001 has NUT configured with local Eaton 5E 2200 UPS (USB connection)
- node002 has no UPS monitoring configured
- node002 would not gracefully shut down during extended power outage

**Desired State:**
- node002 runs NUT in "netclient" mode, connecting to node001's upsd (or another UPS server)
- node002 shuts down gracefully when UPS battery is low
- Rocket Pool services stop cleanly before shutdown

**Prerequisites:**
- [ ] Confirm network topology: can node002 reach node001:3493?
- [ ] Decide if node002 connects to node001's UPS or a separate UPS server

**Steps:**
1. [ ] On node001: Update `/etc/nut/upsd.conf` to listen on LAN IP (not just 127.0.0.1)
2. [ ] On node001: Add a `upsmon slave` user in `/etc/nut/upsd.users`
3. [ ] On node001: Open firewall port 3493 for node002's IP only
4. [ ] On node002: Install NUT (`sudo apt install nut`)
5. [ ] On node002: Set `MODE=netclient` in `/etc/nut/nut.conf`
6. [ ] On node002: Configure `/etc/nut/upsmon.conf` to monitor `eaton@node001-ip`
7. [ ] On node002: Create shutdown script `/usr/local/bin/nut-shutdown.sh` (same as node001)
8. [ ] Test by unplugging UPS briefly and confirming node002 sees status change
9. [ ] Document in [operations.md](operations.md)

**Related Documentation:**
- [operations.md](operations.md) - UPS / Power Protection section
- NUT netclient documentation: https://networkupstools.org/docs/user-manual.chunked/ar01s06.html

**Notes:**
- Alternative: if node002 has its own local UPS, configure as standalone instead
- Security: only allow node002's IP to connect to upsd on node001
- Consider: should node002 shut down earlier than node001 to preserve runtime for active validator?

---

### 🟢 Post-migration docs & config refresh
**Status:** To Do  
**Priority:** Medium  
**Target Date:** After mainnet cutover

**Goal:** Ensure all runbooks reflect the new mainnet steady state.

**Steps:**
1. [ ] Run `scripts/update-config.sh` on node001 and node002 and refresh [node001-config.txt](node001-config.txt) / [node002-config.txt](node002-config.txt).
2. [ ] Update [operations.md](operations.md) “Current status” line and remove Hoodi-only reminders.
3. [ ] Update [mainnet-reference.md](mainnet-reference.md) with mainnet validator indices once minipools are created.

**Notes:**
- Documentation-only; no validator-impacting changes.

---

### 🟢 Complete Troubleshooting Commands Documentation
**Status:** To Do  
**Priority:** Medium

**Task:**
- Document how to check peer counts for Reth, Nethermind, and Lighthouse
- Document restart procedures for individual services

**Steps:**
1. [ ] Test peer count commands on both nodes
2. [ ] Document restart commands (rocketpool service restart vs docker restart)
3. [ ] Update operations.md troubleshooting section

---

## Low Priority / Future Improvements

### 🟢 Implement Automated Backup Verification
**Status:** To Do  
**Priority:** Low

**Idea:**
- Monthly script to verify backup USB drives are readable
- Test recovery of wallet from backup (on test system)
- Alert if backups are older than X days

**Steps:**
- [ ] Design backup verification procedure
- [ ] Create script to automate checks
- [ ] Set up monthly reminder/alert

---

### 🟢 Centralize Log Aggregation
**Status:** To Do  
**Priority:** Low

**Idea:**
- Send logs from both nodes to centralized logging system
- Easier troubleshooting and historical analysis
- Consider Loki + Grafana or similar

**Steps:**
- [ ] Research logging solutions compatible with Rocket Pool
- [ ] Test on node001 (standby)
- [ ] Deploy to node002 if successful

---

## Completed Tasks

### ✅ Create Configuration Auto-Generation Script
**Status:** Done  
**Completed:** 2025-12-20

**Task:**
- Created `scripts/update-config.sh` to automatically generate node configuration files
- Eliminated manual copying into my-config.md
- Agent now reads auto-generated node001-config.txt and node002-config.txt

---

### ✅ Document Beaconcha.in Machine Name for node001
**Status:** Done  
**Completed:** 2025-12-20

**Task:**
- Documented node001 machine name "node01" in operations.md
- Verified both nodes sending metrics to Beaconcha.in

---

### ✅ Document Encrypted USB Setup
**Status:** Done  
**Completed:** 2025-12-20

**Task:**
- Documented LUKS encrypted USB configuration
- Included boot sequence and troubleshooting
- Noted requirement to unlock USB before services start

---

### ✅ Update Staking Expert Agent to Use Config Files
**Status:** Done  
**Completed:** 2025-12-20

**Task:**
- Modified agent to read node001-config.txt, node002-config.txt, fail-over-guidance.md, and operations.md
- Agent now has full context without asking redundant questions

---

## Template for New Tasks

```markdown
### 🟢 [Task Title]
**Status:** To Do  
**Priority:** High/Medium/Low  
**Target Date:** YYYY-MM-DD (optional)

**Description:**
[What needs to be done and why]

**Current State:**
[How things are now]

**Desired State:**
[How things should be]

**Steps:**
1. [ ] Step 1
2. [ ] Step 2
3. [ ] Step 3

**Related Documentation:**
- [Link to relevant docs]

**Notes:**
[Any additional context, blockers, or considerations]
```

---

## Notes

- Update this file as tasks progress
- Move completed tasks to the "Completed Tasks" section
- Archive old completed tasks periodically (quarterly?)
- Link to this file from operations.md for visibility

