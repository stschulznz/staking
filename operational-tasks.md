# Rocket Pool Operational Tasks

> **Purpose:** Track operational improvements, pending tasks, and infrastructure changes  
> **Last Updated:** 2025-12-20

---

## Task Status Legend
- 🔴 **Blocked** - Cannot proceed due to dependency or issue
- 🟡 **In Progress** - Currently working on this
- 🟢 **To Do** - Planned, ready to start
- ✅ **Done** - Completed
- ❌ **Cancelled** - No longer needed

---

## High Priority Tasks

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

### 🟢 Document Beaconcha.in Machine Name for node001
**Status:** To Do  
**Priority:** Medium

**Task:**
- Currently node002 has machine name "node02" configured
- Need to verify/document node001's machine name in operations.md

**Steps:**
1. [ ] Check `~/.rocketpool/user-settings.yml` on node001 for `bitflyMachineName`
2. [ ] Update operations.md with the machine name
3. [ ] Verify metrics are being sent to Beaconcha.in from node001

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

### ✅ Document Encrypted USB Setup
**Status:** Done  
**Completed:** 2025-12-20

**Task:**
- Documented LUKS encrypted USB configuration in operations.md
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
