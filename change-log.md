# Change Log (Rocket Pool HA)

Record every change that could impact validation safety or availability. One entry per change window. Add a table row for quick scan, then append the detailed section.

## Summary Table (newest first)
| Date/Time (local+UTC) | Type | Nodes | Validation | Versions before→after | Outcome/Notes | Details |
| --- | --- | --- | --- | --- | --- | --- |
| yyyy-mm-dd hh:mm TZ / yyyy-mm-dd hh:mm UTC | Smartnode update | node002 | paused | SM 1.18.5→1.18.6; LH 7.2→8.0 | OK, no misses | [Entry yyyy-mm-dd](#entry-yyyy-mm-dd) |

## Entry Template (detailed section)

### Entry yyyy-mm-dd
- Date/Time (local + UTC):
- Change type: Smartnode update / Client update / OS patch / Config change / Infra / Runbook change
- Nodes: node001 / node002
- Summary:
- Planned? (Y/N):
- Commands executed (ordered):
- Versions before → after (CLI, EC, CC, MEV-Boost, OS kernel):
- Validation state during change: online / paused / failover
- Verification: `rocketpool service version`, `rocketpool node sync`, explorer duties ok (link)
- Issues encountered:
- Rollback needed? (Y/N) details:
- Next actions / tasks (copy to operational-tasks.md):
