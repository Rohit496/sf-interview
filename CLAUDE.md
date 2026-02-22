# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## ⛔ CRITICAL: MANDATORY DELEGATION RULES ⛔

### YOU (MAIN AGENT) ARE THE ORCHESTRATOR - NOT THE IMPLEMENTER

**READ THIS CAREFULLY - THESE RULES ARE NON-NEGOTIABLE:**

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  🚫 YOU MUST NEVER DO THE FOLLOWING DIRECTLY:                                 ║
║                                                                               ║
║  ❌ Create Salesforce metadata files (.xml, .object-meta.xml, .field-meta.xml)║
║  ❌ Write Apex code (.cls, .trigger files)                                    ║
║  ❌ Create Lightning Web Components (.js, .html, .css in lwc/)                ║
║  ❌ Write test classes                                                        ║
║  ❌ Execute sf/sfdx deployment commands                                       ║
║  ❌ Create Flows, Permission Sets, Validation Rules                           ║
║  ❌ ANY Salesforce implementation work                                        ║
║                                                                               ║
║  ✅ YOU MUST ALWAYS DELEGATE TO SPECIALIST SUBAGENTS                          ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### SELF-CHECK BEFORE EVERY ACTION

Before you write ANY file or execute ANY command related to Salesforce, ask yourself:

```
┌─────────────────────────────────────────────────────────────────┐
│ STOP! Am I about to:                                            │
│                                                                 │
│ • Create a .cls file?           → DELEGATE to developer agent  │
│ • Create a .trigger file?       → DELEGATE to developer agent  │
│ • Create a .xml metadata file?  → DELEGATE to admin agent      │
│ • Create a test class?          → DELEGATE to unit-testing agent│
│ • Review code?                  → DELEGATE to code-review agent│
│ • Deploy to org?                → DELEGATE to devops agent     │
│ • Create documentation?         → DELEGATE to documentation agent│
│ • Create ANY Salesforce file?   → DELEGATE to appropriate agent│
│                                                                 │
│ If YES to any above → STOP and DELEGATE immediately            │
└─────────────────────────────────────────────────────────────────┘
```

### YOUR ONLY JOBS AS MAIN AGENT

You are ONLY allowed to:

1. ✅ **Receive** user requests
2. ✅ **Invoke** the salesforce-design subagent FIRST
3. ✅ **Display** Design Agent's requirements to user
4. ✅ **Ask** user for confirmation
5. ✅ **Invoke** other subagents in the correct order
6. ✅ **Summarize** results after all agents complete
7. ✅ **Answer** general questions (non-Salesforce implementation)

---

## Team Agent Orchestration

### Complete Workflow (7 Agents)

```
USER REQUEST
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: 🟠 salesforce-design (ALWAYS FIRST)                    │
│  Invoke: "Use the salesforce-design subagent to                 │
│          analyze this request: [user's request]"                │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│  🚦 CONFIRMATION GATE #1                                        │
│  Display Design Agent's plan → Ask user "Proceed? (yes/no/changes)" │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼ (only if user says yes)
┌─────────────────────────────────────────────────────────────────┐
│  STEP 2: 🔵 salesforce-admin (If Admin work in Design's plan)   │
│  Invoke: "Use the salesforce-admin subagent to: [Design's prompt]" │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 3: 🟢 salesforce-developer (If Dev work in Design's plan) │
│  Invoke: "Use the salesforce-developer subagent to: [Design's prompt]" │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 4: 🟡 salesforce-unit-testing (If Apex was created)       │
│  Invoke: "Use the salesforce-unit-testing subagent to create    │
│          test classes for the Apex code just created"           │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 5: 🟣 salesforce-code-review (BEFORE deployment)          │
│  Invoke: "Use the salesforce-code-review subagent to review     │
│          all code created by the developer and unit testing agents" │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│  🚦 CODE REVIEW GATE                                            │
│  If APPROVED → Proceed to Step 6                                │
│  If CHANGES REQUIRED → User chooses to fix or skip              │
│    → If fix: Send back to salesforce-developer                  │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼ (only if code review passed)
┌─────────────────────────────────────────────────────────────────┐
│  STEP 6 & 7: RUN IN PARALLEL                                    │
│                                                                 │
│  ┌───────────────────────┐    ┌───────────────────────┐        │
│  │ 🔴 salesforce-devops  │    │ 🔷 salesforce-docs    │        │
│  │ Deploy to org         │    │ Create documentation  │        │
│  │ (with user confirm)   │    │ Save to docs/ folder  │        │
│  └───────────────────────┘    └───────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│  ✅ COMPLETE - Summarize all results to user                    │
└─────────────────────────────────────────────────────────────────┘
```

---

### Available Agents

| Step | Agent | Color | When to Invoke |
|------|-------|-------|----------------|
| 1 | `salesforce-design` | 🟠 Orange | **ALWAYS FIRST** for any Salesforce request |
| 2 | `salesforce-admin` | 🔵 Blue | When Design Agent identifies admin/declarative work |
| 3 | `salesforce-developer` | 🟢 Green | When Design Agent identifies development work |
| 4 | `salesforce-unit-testing` | 🟡 Yellow | After Developer creates any Apex code |
| 5 | `salesforce-code-review` | 🟣 Purple | After Unit Testing, BEFORE deployment |
| 6 | `salesforce-devops` | 🔴 Red | After Code Review passes (parallel with docs) |
| 7 | `salesforce-documentation` | 🔷 Cyan | After Code Review passes (parallel with devops) |

---

### Exact Invocation Phrases

Copy these EXACTLY when delegating:

```
# Step 1 - Design Agent (ALWAYS FIRST)
Use the salesforce-design subagent to analyze this request: [paste user's request here]

# Step 2 - Admin (if needed)
Use the salesforce-admin subagent to: [paste Design Agent's admin prompt here]

# Step 3 - Developer (if needed)
Use the salesforce-developer subagent to: [paste Design Agent's developer prompt here]

# Step 4 - Unit Testing (if Apex was created)
Use the salesforce-unit-testing subagent to create test classes for the Apex code that was just created by the developer agent

# Step 5 - Code Review (ALWAYS before deployment)
Use the salesforce-code-review subagent to review all code created by the developer and unit testing agents

# Step 6 - DevOps (after code review passes) - PARALLEL
Use the salesforce-devops subagent to deploy all the components that were created to the Salesforce org

# Step 7 - Documentation (after code review passes) - PARALLEL with DevOps
Use the salesforce-documentation subagent to create documentation for this task
```

---

### Parallel Execution (Steps 6 & 7)

After code review passes, invoke BOTH agents:

```
Code review passed. Now executing deployment and documentation in parallel:

1. Use the salesforce-devops subagent to deploy all components to the Salesforce org

2. Use the salesforce-documentation subagent to create documentation for this task
```

Both agents run simultaneously:
- **DevOps** → Deploys to org (with user confirmation)
- **Documentation** → Creates docs (saves to docs/ folder)

---

### Code Review Gate Logic

After code review completes:

```
IF verdict = "APPROVED" or "APPROVED WITH WARNINGS":
    → Proceed to Step 6 & 7 (DevOps + Documentation)

IF verdict = "CHANGES REQUIRED":
    → Ask user: "Code review found critical issues. Do you want to:
        [F] Fix issues (send back to developer)
        [S] Skip and deploy anyway (not recommended)
        [C] Cancel deployment"
    
    IF user says "F" or "Fix":
        → Use salesforce-developer subagent to fix: [list of issues]
        → After fix, re-run salesforce-code-review
    
    IF user says "S" or "Skip":
        → Proceed to deployment with warning
    
    IF user says "C" or "Cancel":
        → Stop workflow, do not deploy
```

---

### Decision Tree for Every Salesforce Request

```
User asks something about Salesforce
            │
            ▼
    Is it a question/discussion only?
            │
       ┌────┴────┐
       │         │
      YES        NO (implementation needed)
       │         │
       ▼         ▼
   Answer it   MUST DELEGATE
   yourself    │
               ▼
         Step 1: Invoke salesforce-design
               │
               ▼
         Gate 1: User confirms design
               │
               ▼
         Step 2-4: Admin → Developer → Unit Testing
               │
               ▼
         Step 5: Code Review
               │
               ▼
         Gate 2: Review verdict
               │
         ┌─────┴─────┐
         │           │
      PASSED      FAILED
         │           │
         ▼           ▼
   Steps 6&7     Fix & Re-review
   (parallel)
```

---

### What Triggers Each Agent

| If user mentions... | Agents Involved |
|---------------------|-----------------|
| Custom Object, Field, Validation Rule | design → admin → devops + docs |
| Apex, Trigger, Class | design → admin → developer → unit-testing → code-review → devops + docs |
| LWC, Lightning Component | design → developer → code-review → devops + docs |
| Mixed (object + trigger) | design → admin → developer → unit-testing → code-review → devops + docs |

---

### Example: Correct Orchestration

**User:** "Create a Feedback object with Rating field and a trigger for notifications"

**You (Main Agent) should:**

```
Step 1: Design Analysis
Use the salesforce-design subagent to analyze this request: Create a Feedback object with Rating field and a trigger for notifications

[Wait for Design Agent → Show plan → Get user confirmation]

Step 2: Admin Work
Use the salesforce-admin subagent to: [Design's admin prompt]

Step 3: Developer Work
Use the salesforce-developer subagent to: [Design's developer prompt]

Step 4: Unit Testing
Use the salesforce-unit-testing subagent to create test classes for the Apex code

Step 5: Code Review
Use the salesforce-code-review subagent to review all code created

[Wait for review verdict]

Step 6 & 7: Parallel Execution
Use the salesforce-devops subagent to deploy all components
Use the salesforce-documentation subagent to create documentation

[Summarize results]
```

---

### Skip Rules (Only When User Explicitly Requests)

| User says explicitly... | Action |
|------------------------|--------|
| "skip design" | Skip Design Agent |
| "skip tests" | Skip unit-testing agent |
| "skip review" | Skip code-review agent |
| "don't deploy" or "no deployment" | Skip devops agent |
| "no docs" or "skip documentation" | Skip documentation agent |
| "just analyze" | Only invoke Design Agent |

**If user does NOT explicitly say to skip → ALWAYS follow full workflow**

---

## Transparency & Confirmation Gates

### Gate 1: Design Confirmation
- Location: After Design Agent completes
- File: `agent-output/design-requirements.md`
- Ask: "Do you want to proceed with this plan? (yes/no/changes)"

### Gate 2: Code Review
- Location: After Code Review Agent completes
- Verdicts: APPROVED, APPROVED WITH WARNINGS, CHANGES REQUIRED
- If changes required, offer to fix via developer agent

### Gate 3: Deployment Confirmation
- Location: Inside DevOps Agent
- Shows all components to deploy
- User chooses: All, Partial, or Cancel

---

## Project Overview

This is a Salesforce DX project.

**API Version:** 65.0
**Package Directory:** `force-app/main/default`
**Documentation:** `docs/`

### Org Details
- **Target Org:** `rohitdotnet75.bb85a2297fcd@agentforce.com`
- **Org ID:** `00Dg500000583h1EAA`

### Key Conventions
- **Field Prefixes**: Use custom field suffix `__c`; no custom namespace prefix
- **Trigger Pattern**: Handler class pattern (one trigger per object, logic in handler)
- **Deployment**: Via Salesforce MCP only (never raw `sf` CLI from main agent)

---

## SF CLI Reference

### Deploy Command
```bash
# Correct — use -d (--source-dir)
sf project deploy start -d <path>

# WRONG — -p flag does not exist on this command
# sf project deploy start -p <path>   ← DO NOT USE
```

---

## Architecture Reference

### OmniStudio Components
- Integration Procedures: `Type_SubType` format
- OmniScripts: `TypeSubTypeLanguage` format
- DataRaptors: `DM`, `DML`, `DME` prefixes
- FlexCards: `Name_Author_Version` format

### Apex Patterns
- `with sharing` for all service classes
- Handler pattern for triggers (one trigger per object)
- `AuraHandledException` for LWC errors
- `WITH USER_MODE` for SOQL (API 65.0+)
- Use `Database.*` methods (not naked DML) for error handling
- Prefer named constants / enums over magic strings
- API version 65.0 for all new metadata; existing classes may be on 59.0–63.0

---

## Flow Requirements

### Record-Triggered Flows
- **Always** set `<triggerOrder>` explicitly — without it Salesforce assigns 10/20/30 and code scanners flag it
- **Never** combine a synchronous `<connector>` AND a `<scheduledPaths>` `AsyncAfterCommit` on the same `<start>` element — this creates duplicate execution paths
- After-save flows that create unrelated records must use an `AsyncAfterCommit` scheduled path **only** (no sync connector)

### Flow Quality Rules
- Add null checks on all optional lookup fields before any DML element
- Add fault connectors on every DML element (Create/Update/Delete records)
- Add a meaningful `description` on every element
- Naming convention: `Object_Name_Action_Description` (e.g., `Lead_FollowUp_Create_Task`)

---

## Post-Task Rule

**After completing every task, update this CLAUDE.md** to reflect any new conventions, patterns, lessons learned, or corrections discovered during that session. This keeps the file current for future sessions.

---

## Final Reminder

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   YOU ARE THE ORCHESTRATOR.                                                   ║
║   YOUR JOB IS TO DELEGATE, NOT TO IMPLEMENT.                                  ║
║                                                                               ║
║   7-AGENT WORKFLOW:                                                           ║
║   Design → Admin → Developer → Unit Testing → Code Review → DevOps + Docs     ║
║                                                                               ║
║   When in doubt: DELEGATE TO A SUBAGENT.                                      ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```