# Incident Log Template

Use this for every production-impacting or safety-relevant event (missed attestations, client crashes, failovers, security events). Add a summary row for fast review, then fill the detailed section.

## Summary Table (newest first)
| Incident ID | Date/Time (local+UTC) | Sev | Nodes | Symptom | Status | Impact est. | Details |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INC-YYYYMMDD-01 | yyyy-mm-dd hh:mm TZ / yyyy-mm-dd hh:mm UTC | S2 | node002 | missed attestations spike | Resolved | ~6 attestations | [INC-YYYYMMDD-01](#inc-yyyymmdd-01) |

## Detailed Section Template

### INC-YYYYMMDD-01
- Date/Time (local + UTC):
- Reporter:
- Affected node(s): node001 / node002 / both
- Network: Hoodi Test
- Severity (S1-S4):
- Status: Open / Monitoring / Resolved

Summary
- One-line description:
- Primary symptom (e.g., missed attestations %, client offline, disk full):

Timeline (UTC)
- t0 detected:
- Key actions (with commands run):
- Failover/failback executed? (reference node-failover-runbook.md):
- Restoration time:

Impact
- Validators affected (indices):
- Attestations missed (approx):
- Any proposals missed:
- Estimated loss (if any):

Root Cause / Contributing Factors
- Root cause:
- Contributing factors (config, infra, external):

Resolution
- Actions taken (ordered):
- Verification (commands / explorer links):

Follow-ups / Tasks (add to operational-tasks.md)
- [ ]
- Due date / owner:

Evidence
- Key log excerpts (paths, timestamps):
- Screenshots/URLs (Grafana/Alertmanager/Beaconcha.in):

Lessons Learned
- What worked:
- What failed:
- Prevent/Detect/Respond improvements:
