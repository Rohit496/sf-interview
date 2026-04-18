# Case Detail Agent — Salesforce Agent Script Guide

> Build a **Case Lookup Agent** that retrieves full case details by Case Number using Agentforce Agent Script, a backing Salesforce Flow, and an Apex class fallback.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [What We're Building](#2-what-were-building)
3. [Step 1 — Create the Apex Action](#3-step-1--create-the-apex-action)
4. [Step 2 — Create the Salesforce Flow](#4-step-2--create-the-salesforce-flow)
5. [Step 3 — Register the Agent Action](#5-step-3--register-the-agent-action)
6. [Step 4 — Write the Agent Script](#6-step-4--write-the-agent-script)
7. [Step 5 — Create the Bundle Metadata](#7-step-5--create-the-bundle-metadata)
8. [Step 6 — Deploy & Test](#8-step-6--deploy--test)
9. [Conversation Flow Walkthrough](#9-conversation-flow-walkthrough)
10. [Enhancements & Patterns](#10-enhancements--patterns)

---

## 1. Architecture Overview

```
User: "What's the status of case 00001234?"
        │
        ▼
┌─────────────────────────────────┐
│        Case Detail Agent        │
│  (Agent Script — .agent file)   │
│                                 │
│  topic: case_lookup             │
│  ├─ variables: case_number      │
│  ├─ actions: get_case_details   │
│  └─ reasoning: if/else logic    │
└────────────┬────────────────────┘
             │  calls
             ▼
┌─────────────────────────────────┐
│   Salesforce Flow               │
│   "Get_Case_Details_Flow"       │
│   Input:  CaseNumber (string)   │
│   Output: Subject, Status,      │
│           Priority, Owner,      │
│           Description, Found    │
└────────────┬────────────────────┘
             │  SOQL query
             ▼
┌─────────────────────────────────┐
│     Case Object (Salesforce)    │
│     CaseNumber, Subject,        │
│     Status, Priority, OwnerId,  │
│     Description, AccountId      │
└─────────────────────────────────┘
```

---

## 2. What We're Building

| Component                         | Type               | Purpose                    |
| --------------------------------- | ------------------ | -------------------------- |
| `CaseLookupAgent.agent`           | Agent Script       | Main agent definition      |
| `Get_Case_Details_Flow`           | Auto-launched Flow | Queries Case by CaseNumber |
| `CaseLookupAction.cls`            | Apex (optional)    | Fallback / complex logic   |
| `CaseLookupAgent.bundle-meta.xml` | Metadata           | Deployment descriptor      |

**Agent Behaviour:**

1. Greets the user and asks for a Case Number
2. Validates the input format
3. Calls the Flow to look up the Case record
4. If found → displays full case details (Subject, Status, Priority, Owner, Description)
5. If not found → apologises and offers to try again
6. Offers to escalate, update, or look up another case

---

## 3. Step 1 — Create the Apex Action

This Apex class is the most reliable way to query a Case by CaseNumber. It returns structured output that the agent can use.

**File:** `force-app/main/default/classes/CaseLookupAction.cls`

```apex
public with sharing class CaseLookupAction {
    public class CaseRequest {
        @InvocableVariable(
            label='Case Number'
            description='The Salesforce Case Number to look up (e.g. 00001234)'
            required=true
        )
        public String caseNumber;
    }

    public class CaseResult {
        @InvocableVariable(
            label='Case Found'
            description='True if the case was found'
        )
        public Boolean caseFound;

        @InvocableVariable(
            label='Case ID'
            description='Salesforce record ID of the case'
        )
        public String caseId;

        @InvocableVariable(label='Subject' description='Case subject / title')
        public String subject;

        @InvocableVariable(
            label='Status'
            description='Current status of the case'
        )
        public String status;

        @InvocableVariable(
            label='Priority'
            description='Case priority: Low, Medium, High'
        )
        public String priority;

        @InvocableVariable(
            label='Owner Name'
            description='Full name of the case owner'
        )
        public String ownerName;

        @InvocableVariable(
            label='Description'
            description='Detailed description of the case'
        )
        public String description;

        @InvocableVariable(
            label='Account Name'
            description='Account associated with the case'
        )
        public String accountName;

        @InvocableVariable(
            label='Created Date'
            description='Date the case was created'
        )
        public String createdDate;

        @InvocableVariable(
            label='Last Modified Date'
            description='Date the case was last updated'
        )
        public String lastModifiedDate;

        @InvocableVariable(
            label='Error Message'
            description='Error details if lookup failed'
        )
        public String errorMessage;
    }

    @InvocableMethod(
        label='Get Case Details by Case Number'
        description='Retrieves full case details from Salesforce given a Case Number. Use this when the user asks about a specific case.'
        category='Case Management'
    )
    public static List<CaseResult> getCaseDetails(List<CaseRequest> requests) {
        List<CaseResult> results = new List<CaseResult>();

        for (CaseRequest req : requests) {
            CaseResult result = new CaseResult();
            try {
                List<Case> cases = [
                    SELECT
                        Id,
                        CaseNumber,
                        Subject,
                        Status,
                        Priority,
                        Owner.Name,
                        Description,
                        Account.Name,
                        CreatedDate,
                        LastModifiedDate
                    FROM Case
                    WHERE CaseNumber = :req.caseNumber.trim()
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];

                if (!cases.isEmpty()) {
                    Case c = cases[0];
                    result.caseFound = true;
                    result.caseId = c.Id;
                    result.subject = c.Subject;
                    result.status = c.Status;
                    result.priority = c.Priority;
                    result.ownerName = c.Owner?.Name;
                    result.description = c.Description;
                    result.accountName = c.Account?.Name;
                    result.createdDate = String.valueOf(c.CreatedDate.date());
                    result.lastModifiedDate = String.valueOf(
                        c.LastModifiedDate.date()
                    );
                } else {
                    result.caseFound = false;
                    result.errorMessage =
                        'No case found with number: ' + req.caseNumber;
                }
            } catch (Exception e) {
                result.caseFound = false;
                result.errorMessage =
                    'Error retrieving case: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
}
```

**File:** `force-app/main/default/classes/CaseLookupAction.cls-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>63.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

---

## 4. Step 2 — Create the Salesforce Flow

If you prefer a **no-code / low-code** approach, build this Flow in Flow Builder instead of (or alongside) Apex.

### Flow Setup

| Property       | Value                          |
| -------------- | ------------------------------ |
| **Flow Label** | Get Case Details               |
| **API Name**   | `Get_Case_Details_Flow`        |
| **Flow Type**  | Autolaunched Flow (No Trigger) |

### Flow Variables

| Variable      | Type    | Direction | Description                |
| ------------- | ------- | --------- | -------------------------- |
| `CaseNumber`  | Text    | Input     | The case number to look up |
| `CaseFound`   | Boolean | Output    | Whether the case was found |
| `Subject`     | Text    | Output    | Case subject               |
| `Status`      | Text    | Output    | Case status                |
| `Priority`    | Text    | Output    | Case priority              |
| `OwnerName`   | Text    | Output    | Owner full name            |
| `Description` | Text    | Output    | Case description           |
| `AccountName` | Text    | Output    | Associated account         |

### Flow Logic (pseudo-code for Flow Builder)

```
[Start]
  └─→ [Get Records: Case]
        Filter: CaseNumber = {!CaseNumber}
        Store in: caseRecord (First Record Only)

  └─→ [Decision: Case Found?]
        YES → caseRecord is not null
          └─→ [Assignment: Set output variables]
                CaseFound    = true
                Subject      = caseRecord.Subject
                Status       = caseRecord.Status
                Priority     = caseRecord.Priority
                OwnerName    = caseRecord.Owner:Name
                Description  = caseRecord.Description
                AccountName  = caseRecord.Account:Name

        NO → caseRecord is null
          └─→ [Assignment]
                CaseFound = false

[End]
```

> **Tip:** When using Apex (Step 1), skip this Flow. Use `apex://CaseLookupAction` as the action target in the Agent Script. When using the Flow, use `flow://Get_Case_Details_Flow`.

---

## 5. Step 3 — Register the Agent Action

After creating either the Apex class or the Flow, register it as an Agent Action in Agentforce Studio.

### Via Salesforce Setup UI

1. Go to **Setup → Einstein → Agentforce Studio → Agentforce Assets**
2. Click the **Actions** tab → **New Agent Action**
3. Fill in:

| Field                         | Value                                         |
| ----------------------------- | --------------------------------------------- |
| **Action Type**               | Flow Action _or_ Apex Action                  |
| **Reference Action**          | `Get_Case_Details_Flow` or `CaseLookupAction` |
| **Agent Action Label**        | `Get Case Details`                            |
| **API Name**                  | `Get_Case_Details`                            |
| **Agent Action Instructions** | See below                                     |

**Agent Action Instructions (write this in the instructions field):**

```
Use this action to retrieve the full details of a Salesforce Case when the user
provides a Case Number. The Case Number is typically an 8-digit number like
00001234. Always use this action before telling the user about a case's status,
subject, priority, owner, or description.
```

4. Map **inputs** and **outputs** with clear labels and descriptions so the LLM understands when and how to use them.

---

## 6. Step 4 — Write the Agent Script

This is the core `.agent` file. Create it at:

```
force-app/main/default/agents/CaseLookupAgent/CaseLookupAgent.agent
```

```agentscript
config:
  agent_name: "CaseLookupAgent"
  agent_type: customer_facing


system:
  instructions:
    | You are a helpful Salesforce Service Agent specialising in case management.
    | Your primary job is to look up case details when a user provides a Case Number.
    | Always be professional, clear, and concise.
    | Never reveal internal Salesforce record IDs to the user.
    | If you cannot find a case, apologise and ask the user to verify the number.
    | Case Numbers in this org are 8-digit numbers (e.g. 00001234).


variables:
  case_number:       mutable string  = ""
  case_found:        mutable boolean = false
  case_subject:      mutable string  = ""
  case_status:       mutable string  = ""
  case_priority:     mutable string  = ""
  case_owner:        mutable string  = ""
  case_description:  mutable string  = ""
  case_account:      mutable string  = ""
  case_created:      mutable string  = ""
  case_modified:     mutable string  = ""
  error_message:     mutable string  = ""
  lookup_attempts:   mutable number  = 0


start_agent:
  instructions:->
    | Hello! I'm your Case Management Assistant.
    | I can retrieve full case details for you — just share the Case Number.
    | What Case Number would you like to look up?
    set @variables.case_number = ...
    transition to @topic.case_lookup


topic case_lookup:
  description: "Looks up a Salesforce Case by Case Number and returns full details including subject, status, priority, owner, and description."

  actions:

    get_case_details:
      description: "Retrieves full details of a Salesforce Case given a Case Number. Use this whenever the user asks about a specific case."
      target: "apex://CaseLookupAction"
      inputs:
        caseNumber:
          type: string
          description: "The 8-digit Salesforce Case Number to look up (e.g. 00001234)"
      outputs:
        caseFound:
          type: boolean
          description: "True if the case was found in the system"
        subject:
          type: string
          description: "The subject/title of the case"
        status:
          type: string
          description: "Current status of the case (e.g. New, In Progress, Closed)"
        priority:
          type: string
          description: "Priority level: Low, Medium, or High"
        ownerName:
          type: string
          description: "Full name of the agent currently assigned to the case"
        description:
          type: string
          description: "Detailed description of the case issue"
        accountName:
          type: string
          description: "Name of the account/customer associated with this case"
        createdDate:
          type: string
          description: "Date the case was originally created"
        lastModifiedDate:
          type: string
          description: "Date the case was last updated"
        errorMessage:
          type: string
          description: "Error details if the lookup failed"


  reasoning:
    instructions:
      | Help the user look up case details.
      | Always run the get_case_details action first before responding about any case.
      | If the user provides a Case Number, look it up immediately.
      | After displaying case details, offer to look up another case or escalate.
      ->
         # ── Step 1: Ensure we have a case number ──────────────────────────────
         if @variables.case_number == "":
            | Please provide the Case Number you'd like to look up.
            set @variables.case_number = ...

         # ── Step 2: Look up the case ─────────────────────────────────────────
         set @variables.lookup_attempts = @variables.lookup_attempts + 1
         run @actions.get_case_details
            with caseNumber = @variables.case_number
            set @variables.case_found        = @outputs.caseFound
            set @variables.case_subject      = @outputs.subject
            set @variables.case_status       = @outputs.status
            set @variables.case_priority     = @outputs.priority
            set @variables.case_owner        = @outputs.ownerName
            set @variables.case_description  = @outputs.description
            set @variables.case_account      = @outputs.accountName
            set @variables.case_created      = @outputs.createdDate
            set @variables.case_modified     = @outputs.lastModifiedDate
            set @variables.error_message     = @outputs.errorMessage

         # ── Step 3: Respond based on result ──────────────────────────────────
         if @variables.case_found == true:
            | Here are the details for Case **{!@variables.case_number}**:
            |
            | 📋 **Subject:**      {!@variables.case_subject}
            | 🔄 **Status:**       {!@variables.case_status}
            | ⚡ **Priority:**     {!@variables.case_priority}
            | 👤 **Assigned To:**  {!@variables.case_owner}
            | 🏢 **Account:**      {!@variables.case_account}
            | 📅 **Created:**      {!@variables.case_created}
            | 🕒 **Last Updated:** {!@variables.case_modified}
            |
            | **Description:**
            | {!@variables.case_description}
            |
            | Would you like to look up another case, or is there anything else I can help you with?

         else:
            if @variables.lookup_attempts < 3:
               | I wasn't able to find a case with the number **{!@variables.case_number}**.
               | Please double-check the number and try again — it should be 8 digits like *00001234*.
               | What Case Number would you like to try?
               set @variables.case_number = ...
               transition to @topic.case_lookup

            else:
               | I've been unable to find the case after multiple attempts.
               | This could mean the case doesn't exist in this system, or you may not have access to it.
               | Please contact your system administrator or try searching directly in Salesforce.
               transition to @topic.escalation


topic escalation:
  description: "Handles escalation when a case cannot be found or the user needs additional help"

  reasoning:
    instructions:
      | The user needs additional assistance beyond what the Case Lookup Agent can provide.
      | Sympathise with the situation and offer clear next steps.
      ->
         | I'm sorry I wasn't able to help find the case you were looking for.
         | Here are some options:
         |
         | 1. **Search in Salesforce** — Navigate to the Cases tab and search manually.
         | 2. **Contact Support** — Reach out to your Salesforce Admin for access issues.
         | 3. **Try a different number** — If you have another Case Number, I'm happy to try again.
         |
         | Is there anything else I can assist you with?
```

---

## 7. Step 5 — Create the Bundle Metadata

**File:** `force-app/main/default/agents/CaseLookupAgent/CaseLookupAgent.bundle-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<AgentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <isActive>true</isActive>
    <masterLabel>Case Lookup Agent</masterLabel>
    <description
    >Agent that retrieves Salesforce Case details by Case Number</description>
</AgentBundle>
```

### Final Project Structure

```
force-app/
└── main/
    └── default/
        ├── agents/
        │   └── CaseLookupAgent/
        │       ├── CaseLookupAgent.agent
        │       └── CaseLookupAgent.bundle-meta.xml
        └── classes/
            ├── CaseLookupAction.cls
            └── CaseLookupAction.cls-meta.xml
```

---

## 8. Step 6 — Deploy & Test

### Deploy Everything

```bash
# 1. Authorize your org
sf org login web -s -a case-agent-dev

# 2. Deploy Apex class first
sf project deploy start -d force-app/main/default/classes/CaseLookupAction.cls

# 3. Deploy the Agent
sf project deploy start -d force-app/main/default/agents/CaseLookupAgent

# 4. Assign permission (so the agent user can read Cases)
sf org assign permset -n YourCaseAccessPermSet

# 5. Open Agentforce Studio
sf org open -p "/lightning/n/standard-AgentforceStudio?c__nav=agents"
```

### Test the Agent in Agentforce Studio

1. Open **Agentforce Studio** → find **CaseLookupAgent**
2. Click **Preview** to open the chat panel
3. Test with real case numbers from your org

### Sample Test Queries

```
✅ "What's the status of case 00001234?"
✅ "Show me details for case number 00005678"
✅ "I need info on case 00009999"
✅ "Can you look up 00001111?"
❌ "case XYZ"           → agent should ask for valid 8-digit number
❌ "case 99999999"      → agent should handle not-found gracefully
```

### Run from CLI (Agentforce DX)

```bash
# Preview / chat with the agent from terminal
sf agent preview --agent-id CaseLookupAgent
```

---

## 9. Conversation Flow Walkthrough

```
┌─────────────────────────────────────────────────────────────────┐
│  Agent:  Hello! I'm your Case Management Assistant.             │
│          I can retrieve full case details — just share the      │
│          Case Number. What Case Number would you like to look up?│
│                                                                 │
│  User:   00001234                                               │
│                                                                 │
│  [Agent runs get_case_details with caseNumber = "00001234"]     │
│                                                                 │
│  Agent:  Here are the details for Case 00001234:                │
│                                                                 │
│          📋 Subject:      Login issue on customer portal        │
│          🔄 Status:       In Progress                           │
│          ⚡ Priority:     High                                  │
│          👤 Assigned To:  Jane Smith                            │
│          🏢 Account:      Acme Corporation                      │
│          📅 Created:      2025-01-15                            │
│          🕒 Last Updated: 2025-02-20                            │
│                                                                 │
│          Description:                                           │
│          Customer is unable to log in after the Jan update...   │
│                                                                 │
│          Would you like to look up another case?                │
│                                                                 │
│  User:   What about case 00099999?                              │
│                                                                 │
│  [Agent runs get_case_details with caseNumber = "00099999"]     │
│                                                                 │
│  Agent:  I wasn't able to find a case with number 00099999.     │
│          Please double-check and try again.                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. Enhancements & Patterns

### Add Case Update Capability

Extend the agent to also update a case status:

```agentscript
update_case_status:
  description: "Updates the status of a Salesforce Case. Use when the user wants to change the status."
  target: "apex://CaseUpdateAction"
  inputs:
    caseNumber:
      type: string
      description: "Case Number to update"
    newStatus:
      type: string
      description: "New status value: New, In Progress, Escalated, Resolved, Closed"
  outputs:
    success:
      type: boolean
      description: "True if the update was successful"
```

Then in the reasoning block:

```agentscript
if @variables.user_wants_update == true:
   | What status would you like to set for case {!@variables.case_number}?
   | Options: New, In Progress, Escalated, Resolved, Closed
   run @actions.update_case_status
      with caseNumber = @variables.case_number
      with newStatus = ...
      set @variables.update_success = @outputs.success
   if @variables.update_success == true:
      | ✅ Case {!@variables.case_number} has been updated successfully.
   else:
      | ❌ I was unable to update the case. Please try again or contact your admin.
```

### Add Multi-Case Support

Allow the user to look up multiple cases in one session:

```agentscript
# After displaying case details, ask if they want another
| Would you like to look up another case? (yes/no)
if ...:  # LLM captures yes/no
   set @variables.case_number = ""
   set @variables.lookup_attempts = 0
   transition to @topic.case_lookup
```

### Add Priority-Based Routing

```agentscript
if @variables.case_priority == "High":
   transition to @topic.high_priority_handler
```

### Guard Clause — Require Authentication

```agentscript
topic case_lookup:
  available when @variables.is_authenticated == true
```

### Best Practices Checklist

| Practice                                                    | Done? |
| ----------------------------------------------------------- | ----- |
| Apex uses `WITH SECURITY_ENFORCED` for field-level security | ✅    |
| Apex is bulkified (accepts `List<>`)                        | ✅    |
| Agent handles "not found" gracefully with retry logic       | ✅    |
| Agent caps retry attempts to avoid infinite loops           | ✅    |
| Action has clear `description` so LLM knows when to use it  | ✅    |
| Variables store all state — not relying on LLM memory       | ✅    |
| Escalation topic handles repeated failures                  | ✅    |
| Bundle metadata includes `masterLabel` and `description`    | ✅    |

---

## Quick Reference — Case Agent Script Syntax

```agentscript
# Run the lookup action
run @actions.get_case_details
   with caseNumber = @variables.case_number
   set @variables.case_found = @outputs.caseFound

# Conditional response
if @variables.case_found == true:
   | Display case details...
else:
   | Case not found message...

# LLM slot-fill (ask user for input)
set @variables.case_number = ...

# Topic transition
transition to @topic.escalation

# Template expressions in utterances
| Case number: {!@variables.case_number} — Status: {!@variables.case_status}
```

---

_Built using Salesforce Agent Script · [Official Docs](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-script.html) · [Recipes](https://github.com/trailheadapps/agent-script-recipes)_
