# Current Rocket Pool Configuration

> **Last Updated:** [Run ./update-config.sh on each node to refresh]

---

## Architecture Overview
- **Primary Node:** node001 (active)
- **Standby Node:** node002 (hot standby for hardware failover)
- **Failover Strategy:** Manual switchover if node001 hardware fails

---

## Node001 (Primary)

### Rocket Pool
- **Version:** 
- **Network:** 
- **Node Address:** 
- **Withdrawal Address:** 
- **Fee Recipient:** 

### Minipools
- **Active Count:** 
- **Status:** 

### Client Configuration
**Execution Client:**
- **Client:** 
- **Version:** 
- **Sync Mode:** 
- **Port:** 

**Consensus Client:**
- **Client:** 
- **Version:** 
- **Port:** 

**MEV-Boost:**
- **Enabled:** 
- **Relays:** 

### System Environment
- **Distribution:** Debian 13
- **Kernel:** 
- **Architecture:** 
- **Hardware:**
  - CPU: 
  - RAM: 
  - Storage: 
- **Network:**
  - External IP: 
  - Firewall: 
  - SSH Port: 

---

## Node002 (Standby)

### Rocket Pool
- **Version:** 
- **Network:** 
- **Node Address:** [Same as node001]
- **Withdrawal Address:** [Same as node001]
- **Fee Recipient:** [Same as node001]

### Minipools
- **Status:** Standby (validator keys present but not active)

### Client Configuration
**Execution Client:**
- **Client:** 
- **Version:** 
- **Sync Mode:** 
- **Port:** 

**Consensus Client:**
- **Client:** 
- **Version:** 
- **Port:** 

**MEV-Boost:**
- **Enabled:** 
- **Relays:** 

### System Environment
- **Distribution:** Debian 13
- **Kernel:** 
- **Architecture:** 
- **Hardware:**
  - CPU: 
  - RAM: 
  - Storage: 
- **Network:**
  - External IP: 
  - Firewall: 
  - SSH Port: 

---

## Failover Procedures

### Triggering Failover (node001 → node002)
1. [Document your process]
2. 
3. 

### Failback (node002 → node001)
1. [Document your process]
2. 
3. 

### Slashing Prevention
- **Safety Gap:** [time to wait between shutting down node001 and starting node002]
- **Verification Steps:** [what to check before activating standby]

---

## Monitoring & Backups

### Monitoring
- **Tools:** 
- **Alerts:** 
- **Metrics tracked:** 

### Backups
- **Wallet Backup:** 
- **Validator Keys:** [synced to both nodes]
- **Config Backup:** 

---

## Notes
<!-- Add any custom setup notes, quirks, or reminders here -->

**HA Considerations:**
- Both nodes kept in sync for client versions
- Only one node actively validating at a time (critical for slashing prevention)
- Standby node keeps clients synced and ready
