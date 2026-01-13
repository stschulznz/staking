# Persona Integration Guide

## How to Use the Rocket Pool Master Persona

You've created **Dr. Wei Chen**, a structured expert persona optimized for Rocket Pool Ethereum validator operations with production-grade reliability and educational depth.

---

## Option A: Direct Embedding (Recommended for Single Agent)

Copy the entire **"Role and Persona"** section from [rocket-pool-master.md](rocket-pool-master.md) and paste it into your agent's instruction block.

**Where to embed:**
- Open [Staking Expert.agent.md](../Staking%20Expert.agent.md)
- Locate the `## Role & Persona` section (currently lines 10–21)
- Replace the existing persona block with the complete Dr. Wei Chen persona definition

**Result:**
The agent will immediately adopt Dr. Wei Chen's credentials, methodology, communication style, and quality standards in all responses.

---

## Option B: External File Reference (Recommended for Multi-Agent Setups)

If you have multiple agents that need to reference or share personas:

1. **Keep the persona file in the personas directory** (already done):
   ```
   .github/agents/personas/rocket-pool-master.md
   ```

2. **In your agent instructions**, add this reference block at the top of the `## Role & Persona` section:

   ```markdown
   ---
   **Persona Reference:**
   Load and adopt the complete persona defined in: [.github/agents/personas/rocket-pool-master.md](personas/rocket-pool-master.md)

   You MUST embody this persona's credentials, methodology, communication style, quality standards, and interaction protocols in all responses.
   ---
   ```

3. **The agent will:**
   - Access the persona file content when processing instructions
   - Maintain consistency with the defined expert identity
   - Apply the Five-Layer Validator Resilience Framework
   - Follow the documentation-first rule and safety gates

---

## Option C: Hybrid Approach (Maximum Flexibility)

Use external reference for the full persona, but extract key **Decision Heuristics** and **Safety Gates** directly into the agent instructions for quick reference:

**In Staking Expert.agent.md:**
```markdown
## Role & Persona
[External reference block from Option B]

## Quick Reference Decision Framework
*(Extracted from Dr. Wei Chen persona for rapid consultation)*

**Safety Gates (ALWAYS apply):**
- ✓ Keys exist on exactly ONE node at a time
- ✓ Verify sync health before validator operations
- ✓ Purge + wait for finalized miss before key migration
- ✓ Check official Rocket Pool docs before troubleshooting
- ✓ Provide rollback steps for irreversible operations

**Response Priority:**
1. Quick-action commands (copy-paste ready)
2. Brief technical explanation (why it works)
3. Safety validation steps
4. Educational follow-up offer
```

---

## Implementation Checklist

After integrating the persona, verify the agent exhibits these behaviors:

### Context Loading
- [ ] Agent loads `node001-config.txt` and `node002-config.txt` at conversation start
- [ ] Agent acknowledges current configuration state (which node is active, client versions, network)
- [ ] Agent references actual environment details in commands (paths, container names, client versions)

### Documentation-First Rule
- [ ] Agent uses `fetch_webpage` to verify guidance from https://docs.rocketpool.net/guides/ before troubleshooting
- [ ] Agent cites specific documentation sections in responses
- [ ] Agent explicitly states when official docs are silent on a topic

### Communication Style
- [ ] Responses follow the [Command Block → Why This Works → Safety Note] format
- [ ] Commands are copy-paste ready with inline comments
- [ ] Educational context is concise (2–3 sentences) but informative
- [ ] Agent offers follow-up depth: "Want me to explain why [X works this way]?"

### Safety Validation
- [ ] Agent blocks irreversible operations (key purging, minipool exits, network migrations) until operator confirms understanding
- [ ] Agent enforces slashing-prevention protocols (purge-verify-wait-load sequences for failovers)
- [ ] Agent provides validation steps after critical commands
- [ ] Agent flags risks early and clearly ("⚠️ Safety Check Failed: ...")

### Quality Standards
- [ ] Agent validates recommendations against the Six Quality Criteria (documentation alignment, slashing prevention, idempotency, testability, Debian 13 compatibility, operational context)
- [ ] Agent provides rollback procedures for complex operations
- [ ] Agent measures downtime in "missed attestation epochs" and justifies maintenance windows
- [ ] Agent applies the Five-Layer Validator Resilience Framework systematically

---

## Testing the Integration

Run these sample queries to verify the persona is active:

**Test 1: Context Awareness**
> "What execution client am I running?"

**Expected:** Agent answers directly from `node001-config.txt` without asking clarifying questions (Reth on node001, Nethermind on node002).

---

**Test 2: Documentation-First Rule**
> "How do I upgrade my Rocket Pool Smartnode?"

**Expected:** Agent uses `fetch_webpage` to check https://docs.rocketpool.net/guides/, cites the official upgrade procedure, then provides commands tailored to your Debian 13 + Docker setup.

---

**Test 3: Safety Gates**
> "I want to switch from node001 to node002 for validation."

**Expected:** Agent presents the failover runbook steps, blocks until you confirm understanding of key purging requirements, enforces the "wait for finalized missed attestation" rule, and provides validation commands after each phase.

---

**Test 4: Communication Style**
> "My beacon chain is out of sync. What do I do?"

**Expected:** Response structure:
1. Command block: `rocketpool node sync` and `docker logs rocketpool_eth2`
2. Why this works: "Beacon sync failures typically stem from [3 common causes]..."
3. Safety note: "Don't restart the validator yet — we need to check if..."
4. Follow-up offer: "Want me to diagnose further or explain checkpoint sync?"

---

**Test 5: Operational Context**
> "Can my hardware handle 12 validators?"

**Expected:** Agent references `node001-config.txt` hardware specs (i5-1235U, 62GB RAM, 3.6TB storage), calculates validator load against client resource profiles, cites the LEB bond analysis recommendation (11–12 LEB8 validators), and suggests monitoring thresholds.

---

## Maintenance

**When to Update the Persona:**

1. **Rocket Pool Protocol Upgrades** (e.g., Saturn 1, future changes to commission structure or bond mechanics)
   - Update the "Core Competencies" section with new protocol mechanics
   - Add new decision heuristics if the upgrade changes operational procedures
   - Refresh "Example Interaction" to reflect current workflows

2. **Client Software Changes** (e.g., new execution/consensus clients, deprecated clients)
   - Update the "Ethereum Client Operations" competency
   - Adjust command examples if CLI syntax changes

3. **Infrastructure Evolution** (e.g., migration from Debian 13 to Debian 14, new backup tools, monitoring stack changes)
   - Update the "Linux System Administration" competency
   - Revise file paths, systemd unit names, or package manager commands

4. **Official Documentation Overhaul** (e.g., Rocket Pool docs restructure URLs or best practices)
   - Verify all https://docs.rocketpool.net/guides/ references remain valid
   - Update the "Documentation sources" priority order if new authoritative resources emerge

**Version Control:**
- Increment the `version:` field in the YAML front matter
- Document major changes in a changelog comment at the bottom of the persona file

---

## Troubleshooting

**Problem:** Agent ignores the persona and responds generically.

**Solution:**
- Verify the persona reference is in the agent's `## Role & Persona` section (not buried in a different section)
- Check that the agent has `read` tool access to load the persona file
- Explicitly prompt: "Adopt the Dr. Wei Chen persona from [rocket-pool-master.md] and respond as him"

---

**Problem:** Agent provides commands but skips educational context.

**Solution:**
- Remind the agent: "Follow the [Command Block → Why This Works → Safety Note] format from the Dr. Wei Chen persona"
- Check that the "Communication Style" section is fully included in the integration

---

**Problem:** Agent doesn't check official Rocket Pool documentation before responding.

**Solution:**
- Verify the agent has `web` tool access enabled (required for `fetch_webpage`)
- Explicitly instruct: "Before answering, check https://docs.rocketpool.net/guides/ per the Documentation-First Rule"
- Add a standing instruction at the top of the agent config: "ALWAYS use fetch_webpage to verify Rocket Pool documentation before troubleshooting"

---

## Advanced Customization

### Creating Persona Variants

If you need specialized variations (e.g., "Dr. Wei Chen — MEV-Focused" or "Dr. Wei Chen — Testnet Onboarding"):

1. **Copy the base persona file:**
   ```bash
   cp personas/rocket-pool-master.md personas/rocket-pool-master-mev.md
   ```

2. **Modify the relevant competency sections:**
   - For MEV focus: Expand "Rocket Pool Protocol Mastery" to include relay selection criteria, block builder reputation tracking, and MEV-boost configuration tuning
   - For testnet focus: Add "Testnet Network Idiosyncrasies" competency with Hoodi-specific quirks, faucet workflows, and reset procedures

3. **Update the "Boundaries" section** to reflect the narrowed scope

4. **Reference the variant in the appropriate agent:**
   ```markdown
   **Persona Reference:**
   Load and adopt the complete persona defined in: [personas/rocket-pool-master-mev.md]
   ```

### Layering Multiple Personas

If you want the agent to consult both a general SRE persona and the Rocket Pool persona:

```markdown
## Role & Persona

You embody TWO expert personas and synthesize their guidance:

**Primary Persona (Rocket Pool Operations):**
[Reference to rocket-pool-master.md]

**Secondary Persona (General SRE Principles):**
[Reference to sre-master.md — create this if needed]

**Synthesis Protocol:**
When responding, first apply Dr. Wei Chen's Rocket Pool-specific expertise. If the query extends beyond validator operations (e.g., general Linux kernel tuning, non-Ethereum monitoring), consult the SRE persona for broader systems engineering principles. Always prioritize Rocket Pool domain knowledge for staking-specific decisions.
```

---

## Support

If you encounter issues integrating or using this persona:

1. **Check the verification checklist** (above) to ensure all expected behaviors are present
2. **Run the test queries** to identify which aspect of the persona isn't activating
3. **Review the agent's actual responses** against the "Example Interaction" in the persona file — they should match in structure and depth
4. **Iterate the prompt:** Sometimes agents need explicit reminders like "Respond as Dr. Wei Chen would, following his Five-Layer Resilience Framework"

**Persona is ready for integration.** Choose your preferred option (A, B, or C) and proceed with embedding in [Staking Expert.agent.md](../Staking%20Expert.agent.md).
