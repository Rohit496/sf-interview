# Case Lookup Agent

**Date:** 2026-02-27
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

Build a Case Lookup Agent using Agentforce Agent Script, consisting of:

1. An Apex invocable action class (`CaseLookupAction.cls`) that queries a Case record by CaseNumber and returns full case details.
2. An Agentforce Agent Bundle under `aiAuthoringBundles/CaseLookupAgent/` containing the agent script and its metadata descriptor.

Source guide: `agent script/case-agent-script-guide.md`

### Business Objective

Support teams frequently need to look up case details quickly during live customer interactions. Rather than navigating to the Cases tab manually, a conversational Agentforce agent lets a service representative (or the customer directly in a self-service channel) type a Case Number and receive all relevant details — subject, status, priority, owner, account, and description — in a single conversational turn.

### Summary

A conversational Agentforce agent (`CaseLookupAgent`) was built that accepts an 8-digit Salesforce Case Number from the user, calls an Apex invocable action (`CaseLookupAction`) to query the Case record, and presents the results in a formatted response. The agent retries up to 3 times on not-found responses before escalating to a dedicated escalation topic. No declarative admin metadata (flows, custom fields, permission sets) was created; the agent calls Apex directly via the `apex://` target protocol.

---

## Components Created

### Admin Components (Declarative)

None. The user explicitly chose the Apex-only path. No Flow, no custom fields, no permission sets, and no validation rules were created.

---

### Development Components (Code)

#### Apex Classes

| Class Name             | Type             | API Version | Description                                                        |
| ---------------------- | ---------------- | ----------- | ------------------------------------------------------------------ |
| `CaseLookupAction`     | Invocable Action | 63.0        | Queries Case by CaseNumber; returns structured result to the agent |
| `CaseLookupActionTest` | Test Class       | 63.0        | 8 test methods covering all execution paths                        |

#### Apex Triggers

None.

#### Test Classes

| Test Class             | Tests For          | Test Methods            |
| ---------------------- | ------------------ | ----------------------- |
| `CaseLookupActionTest` | `CaseLookupAction` | 8 (see inventory below) |

#### Agentforce Agent Bundle

| File                              | Type                       | Description                                                                               |
| --------------------------------- | -------------------------- | ----------------------------------------------------------------------------------------- |
| `CaseLookupAgent.agent`           | Agent Script               | Main agent definition: system instructions, 12 variables, topic logic, action definitions |
| `CaseLookupAgent.bundle-meta.xml` | AiAuthoringBundle metadata | Deployment descriptor; bundleType AGENT, target CaseLookupAgent.v6                        |

#### Lightning Web Components

None.

---

## Data Flow

### How It Works

```
1. User opens the CaseLookupAgent in Agentforce and is greeted by the welcome message.
2. The start_agent topic_selector asks for a Case Number and transitions to the case_lookup topic.
3. In case_lookup, if case_number is empty the agent prompts the user; once provided, the
   set_case_number util action stores it and increments lookup_attempts.
4. The get_case_details action fires (available when case_number != "").
   It targets apex://CaseLookupAction, passing caseNumber as input.
5. CaseLookupAction.getCaseDetails() executes a SOQL query on the Case object,
   filtering WHERE CaseNumber = :req.caseNumber.trim(), WITH SECURITY_ENFORCED, LIMIT 1.
6. Outputs (caseFound, subject, status, priority, ownerName, description, accountName,
   createdDate, lastModifiedDate, errorMessage) are mapped into agent variables.
7a. If caseFound = true  → Agent formats and displays case details; offers another lookup.
7b. If caseFound = false and lookup_attempts < 3 → Agent asks user to re-enter number.
7c. If caseFound = false and lookup_attempts >= 3 → Transitions to escalation topic.
8. The escalation topic offers: search Salesforce manually, contact admin, or try a
   different number (which resets variables and loops back to case_lookup).
```

### Architecture Diagram

```
┌────────────────────┐
│   User (chat)      │
│  "Case 00001234"   │
└────────┬───────────┘
         │
         ▼
┌────────────────────────────────────────────────────────┐
│             CaseLookupAgent  (.agent file)              │
│                                                        │
│  start_agent topic_selector                            │
│    └─ greet user, ask for Case Number                  │
│    └─ transition to case_lookup                        │
│                                                        │
│  topic: case_lookup                                    │
│    set_case_number (@utils.setVariables)               │
│      └─ stores case_number, increments lookup_attempts │
│    get_case_details (@actions.CaseLookupAction)        │
│      └─ calls apex://CaseLookupAction                  │
│      └─ maps 10 output fields to variables             │
│    reasoning                                           │
│      ├─ caseFound = true  → display results            │
│      ├─ attempts < 3      → ask to retry               │
│      └─ attempts >= 3     → transition to escalation   │
│                                                        │
│  topic: escalation                                     │
│    └─ offer manual search / contact admin / retry      │
│    reset_and_retry (@utils.setVariables)               │
│      └─ clears case_number, lookup_attempts, etc.      │
│      └─ transition back to case_lookup                 │
└────────────────────────────────────────────────────────┘
         │
         │ apex://CaseLookupAction
         ▼
┌────────────────────────────────────────────────────────┐
│             CaseLookupAction.cls  (Apex)                │
│                                                        │
│  getCaseDetails(List<CaseRequest>)                     │
│    for each request:                                   │
│      SOQL: SELECT ... FROM Case                        │
│            WHERE CaseNumber = :req.caseNumber.trim()   │
│            WITH SECURITY_ENFORCED                      │
│            LIMIT 1                                     │
│      if found  → populate CaseResult fields            │
│      if not    → caseFound = false, set errorMessage   │
│      on error  → catch Exception, set errorMessage     │
│    return List<CaseResult>                             │
└────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────┐
│   Case Object (standard Salesforce object)             │
│   Fields queried: Id, CaseNumber, Subject, Status,     │
│   Priority, Owner.Name, Description, Account.Name,     │
│   CreatedDate, LastModifiedDate                        │
└────────────────────────────────────────────────────────┘
```

---

## File Locations

| Component            | Path                                                                                        |
| -------------------- | ------------------------------------------------------------------------------------------- |
| Apex Action class    | `force-app/main/default/classes/CaseLookupAction.cls`                                       |
| Apex Action meta XML | `force-app/main/default/classes/CaseLookupAction.cls-meta.xml`                              |
| Test class           | `force-app/main/default/classes/CaseLookupActionTest.cls`                                   |
| Test class meta XML  | `force-app/main/default/classes/CaseLookupActionTest.cls-meta.xml`                          |
| Agent Script         | `force-app/main/default/aiAuthoringBundles/CaseLookupAgent/CaseLookupAgent.agent`           |
| Bundle metadata      | `force-app/main/default/aiAuthoringBundles/CaseLookupAgent/CaseLookupAgent.bundle-meta.xml` |
| Source guide         | `agent script/case-agent-script-guide.md`                                                   |

---

## Configuration Details

### CaseLookupAction — Inner Classes and Method

#### CaseRequest (input wrapper)

| Field        | Type   | Required | Description                                    |
| ------------ | ------ | -------- | ---------------------------------------------- |
| `caseNumber` | String | Yes      | 8-digit Salesforce Case Number (e.g. 00001234) |

#### CaseResult (output wrapper)

| Field              | Type    | Description                                                                                    |
| ------------------ | ------- | ---------------------------------------------------------------------------------------------- |
| `caseFound`        | Boolean | `true` if a matching Case was found                                                            |
| `caseId`           | String  | Salesforce record Id (18-char) — populated but agent is instructed never to reveal it to users |
| `subject`          | String  | Case Subject                                                                                   |
| `status`           | String  | Case Status (e.g. New, In Progress, Closed)                                                    |
| `priority`         | String  | Case Priority (Low, Medium, High)                                                              |
| `ownerName`        | String  | Owner.Name from the related User (null-safe)                                                   |
| `description`      | String  | Case Description                                                                               |
| `accountName`      | String  | Account.Name (null-safe; null if no Account linked)                                            |
| `createdDate`      | String  | CreatedDate converted to a date string via `String.valueOf(c.CreatedDate.date())`              |
| `lastModifiedDate` | String  | LastModifiedDate converted to a date string                                                    |
| `errorMessage`     | String  | Populated on not-found or exception paths; null on success                                     |

#### InvocableMethod Metadata

| Attribute   | Value                                                                                                                 |
| ----------- | --------------------------------------------------------------------------------------------------------------------- |
| Label       | `Get Case Details by Case Number`                                                                                     |
| Description | `Retrieves full case details from Salesforce given a Case Number. Use this when the user asks about a specific case.` |
| Category    | `Case Management`                                                                                                     |
| Sharing     | `with sharing`                                                                                                        |
| Access mode | `WITH SECURITY_ENFORCED` (see Known Limitations)                                                                      |

### Agent Script — Variables

| Variable           | Type            | Default | Description                                                           |
| ------------------ | --------------- | ------- | --------------------------------------------------------------------- |
| `case_number`      | mutable string  | `""`    | Case Number provided by the user                                      |
| `case_found`       | mutable boolean | `false` | Whether the lookup succeeded                                          |
| `case_subject`     | mutable string  | `""`    | Case Subject from action output                                       |
| `case_status`      | mutable string  | `""`    | Case Status from action output                                        |
| `case_priority`    | mutable string  | `""`    | Case Priority from action output                                      |
| `case_owner`       | mutable string  | `""`    | Case owner name from action output                                    |
| `case_description` | mutable string  | `""`    | Case Description from action output                                   |
| `case_account`     | mutable string  | `""`    | Account name from action output                                       |
| `case_created`     | mutable string  | `""`    | Created date string from action output                                |
| `case_modified`    | mutable string  | `""`    | Last modified date string from action output                          |
| `error_message`    | mutable string  | `""`    | Error details if the lookup failed                                    |
| `lookup_attempts`  | mutable number  | `0`     | Counts how many lookup attempts have been made in the current session |

### Agent Script — Topics

| Topic                        | Label          | Purpose                                                                              |
| ---------------------------- | -------------- | ------------------------------------------------------------------------------------ |
| `start_agent topic_selector` | Topic Selector | Greets user, asks for Case Number, transitions to case_lookup                        |
| `topic case_lookup`          | Case Lookup    | Drives the lookup loop; calls get_case_details action; handles found/not-found/retry |
| `topic escalation`           | Escalation     | Handles repeated failures; offers manual search, admin contact, or retry             |

### Agent Script — Actions

| Action Name         | Type                  | Target                    | Available When      | Description                                                                                          |
| ------------------- | --------------------- | ------------------------- | ------------------- | ---------------------------------------------------------------------------------------------------- |
| `get_case_details`  | Apex Invocable        | `apex://CaseLookupAction` | `case_number != ""` | Queries Case by CaseNumber; returns 10 output fields                                                 |
| `set_case_number`   | `@utils.setVariables` | Built-in util             | Always              | Stores user-provided case_number; increments lookup_attempts                                         |
| `go_to_case_lookup` | `@utils.transition`   | `@topic.case_lookup`      | Always              | Transitions from start/escalation to case_lookup                                                     |
| `reset_and_retry`   | `@utils.setVariables` | Built-in util             | In escalation       | Clears case_number, lookup_attempts, case_found, error_message; used before returning to case_lookup |

### Bundle Metadata

| Attribute      | Value                                     |
| -------------- | ----------------------------------------- |
| XML element    | `<AiAuthoringBundle>`                     |
| `<bundleType>` | `AGENT`                                   |
| `<target>`     | `CaseLookupAgent.v6`                      |
| Namespace      | `http://soap.sforce.com/2006/04/metadata` |

### Deployment Order

The Apex class must be deployed before the agent bundle because the agent script references `apex://CaseLookupAction`. Deploy in this order:

1. `force-app/main/default/classes/CaseLookupAction.cls` (and meta XML)
2. `force-app/main/default/aiAuthoringBundles/CaseLookupAgent/` (agent + bundle-meta)

---

## Testing

### Test Coverage Summary

| Class              | Test Methods                   | Status                 |
| ------------------ | ------------------------------ | ---------------------- |
| `CaseLookupAction` | 8 (via `CaseLookupActionTest`) | Passes in test context |

### Test Method Inventory

| Method Name                                                    | Scenario                                             | Expected Outcome                                                                                         |
| -------------------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `getCaseDetails_validCaseNumber_returnsCaseFoundTrue`          | Existing CaseNumber from `@TestSetup`                | `caseFound = true`; all 10 result fields populated; `errorMessage = null`                                |
| `getCaseDetails_caseNumberWithWhitespace_trimsAndFindsCase`    | Valid CaseNumber padded with leading/trailing spaces | `caseFound = true` — confirms `.trim()` works                                                            |
| `getCaseDetails_caseWithoutAccount_accountNameIsNull`          | Case inserted without an AccountId                   | `caseFound = true`; `accountName = null` — confirms null-safe `?.` navigation                            |
| `getCaseDetails_nonExistentCaseNumber_returnsCaseFoundFalse`   | CaseNumber `000000000` (does not exist)              | `caseFound = false`; `errorMessage` contains the bad case number; `caseId` and `subject` are null        |
| `getCaseDetails_nullCaseNumber_returnsCaseFoundFalseWithError` | `caseNumber = null`                                  | `caseFound = false`; `errorMessage` starts with `"Error retrieving case:"` (NullPointerException caught) |
| `getCaseDetails_emptyCaseNumber_returnsCaseFoundFalse`         | `caseNumber = ""`                                    | `caseFound = false`; `errorMessage` set — no matching Case for empty string                              |
| `getCaseDetails_bulkMixedRequests_eachResolvedIndependently`   | 3 requests: valid, non-existent, null (in one call)  | 3 results returned in order; each resolves independently (true, false, false)                            |
| `getCaseDetails_bulk200ValidRequests_allReturnCaseFoundTrue`   | 200 requests all using the same valid CaseNumber     | All 200 results have `caseFound = true` — validates governor limit behaviour at scale                    |

### Test Data Strategy

- `@TestSetup` creates a shared `Account` (`Lookup Test Corp`) and a linked `Case` (Subject: `Billing Inquiry`, Status: `New`, Priority: `Medium`).
- Individual test methods query them back via SOQL using `WITH USER_MODE` to avoid stale SObject references.
- DML in `@TestSetup` uses `Database.insert(obj, AccessLevel.SYSTEM_MODE)` because the test user may lack FLS on fields queried by the production class under `WITH SECURITY_ENFORCED`.
- Helper methods `getTestAccount()`, `getTestCase()`, and `buildRequest()` reduce repetition across test methods.

---

## Security

### Sharing Model

- `CaseLookupAction` is declared `public with sharing`, so Salesforce sharing rules apply when the class executes.
- The SOQL query uses `WITH SECURITY_ENFORCED`, which enforces object-level and field-level security at the SOQL level (see Known Limitations for the alternative `WITH USER_MODE`).

### Agent Security

- The system instructions block explicitly instructs the agent: "Never reveal internal Salesforce record IDs to the user." The `caseId` output field has `is_displayable: False` and `filter_from_agent: False` in the action definition, reinforcing this policy.
- The `get_case_details` action is only available when `case_number != ""`, preventing spurious calls.
- `require_user_confirmation: False` — the lookup is read-only and does not require user confirmation before firing.

### Required Permissions for the Agent User / Running User

- Object-level READ access to `Case`
- Field-level READ access to all queried Case fields: `CaseNumber`, `Subject`, `Status`, `Priority`, `Description`, `CreatedDate`, `LastModifiedDate`
- Related object READ: `Owner` (User.Name) and `Account` (Account.Name)

---

## Conversation Flow Walkthrough

```
Agent:  Hello! I'm your Case Management Assistant.
        I can retrieve full case details for you -- just share the Case Number.

User:   00001234

[Agent: sets case_number = "00001234", lookup_attempts = 1]
[Agent: fires get_case_details action → CaseLookupAction.getCaseDetails()]
[Apex:  SOQL finds Case with CaseNumber = "00001234"]
[Agent: caseFound = true]

Agent:  Here are the details for Case 00001234:

        Subject:      Login issue on customer portal
        Status:       In Progress
        Priority:     High
        Assigned To:  Jane Smith
        Account:      Acme Corporation
        Created:      2025-01-15
        Last Updated: 2025-02-20

        Description:
        Customer is unable to log in after the January update...

        Would you like to look up another case?

-- NOT FOUND PATH --

User:   00099999

[Apex:  no Case found]
[Agent: caseFound = false, lookup_attempts = 1]

Agent:  I wasn't able to find a case with number 00099999.
        Please double-check the number -- it should be 8 digits like 00001234.
        What Case Number would you like to try?

[After 3 failed attempts → escalation topic]

Agent:  I'm sorry I wasn't able to help find the case.
        Options:
        1. Search in Salesforce — navigate to the Cases tab and search manually.
        2. Contact Support — reach out to your Salesforce Admin for access issues.
        3. Try a different number — if you have another Case Number, I'm happy to try again.
```

---

## Notes and Considerations

### Known Limitations

1. **SOQL inside a for loop — governor limit risk.** `CaseLookupAction.getCaseDetails()` executes one SOQL query per element in the `List<CaseRequest>`. Agentforce typically passes a single request per invocation, so in practice this is one query per agent turn. However, if the action is ever called with a large batch (e.g. via a Process Builder or Flow with bulk records), this pattern can hit the 101 SOQL query governor limit. The recommended fix is to collect all `CaseNumber` values first, run a single `WHERE CaseNumber IN :caseNumbers` query, then match results back to each request. This was flagged during code review but the user chose to proceed without fixing it for this iteration.

2. **`WITH SECURITY_ENFORCED` instead of `WITH USER_MODE`.** The project standard (API 65.0) uses `WITH USER_MODE`. `WITH SECURITY_ENFORCED` throws a runtime exception if the running user lacks access to any queried field, which surfaces as an unhandled exception rather than a clean "no access" message. `WITH USER_MODE` silently omits inaccessible fields. This was flagged during code review but the user chose to proceed without fixing it for this iteration. The catch block does handle the thrown exception and returns a clean error result, so functional correctness is maintained.

3. **API version 63.0 in meta XML files.** Both `CaseLookupAction.cls-meta.xml` and `CaseLookupActionTest.cls-meta.xml` declare `<apiVersion>63.0</apiVersion>`. The project standard is 65.0. This is a cosmetic discrepancy and does not affect runtime behaviour, but should be corrected in a future update to maintain consistency.

4. **No permission set for the agent running user.** The Case Lookup Agent requires the running user (or agent service account) to have READ access to the Case object and all queried fields. No explicit permission set was created. Ensure the agent user profile or a permission set grants the necessary access before deploying to production.

5. **No validation of Case Number format.** The agent's system instructions mention that Case Numbers are 8-digit numbers, and the reasoning block asks users to verify this format, but there is no programmatic format check in the Apex class. A malformed case number (e.g. text, partial number) will simply return not-found rather than an explicit format error.

### Future Enhancements

- **Bulkify the SOQL query** (fix for Limitation 1 above): collect all caseNumbers → single `WHERE CaseNumber IN :set` query → map results back.
- **Switch to `WITH USER_MODE`** (fix for Limitation 2): aligns with project standards and gives cleaner field-level security behaviour.
- **Add a Case Update action**: extend `case_lookup` with an `update_case_status` action targeting a new `CaseUpdateAction` Apex class.
- **Priority-based routing**: transition to a `high_priority_handler` topic when `case_priority == "High"` to trigger escalation workflows.
- **Multi-case session support**: after displaying results, offer to look up another case by resetting `case_number` and looping.
- **Format validation**: validate that the input matches an 8-digit pattern before calling the Apex action.

### Dependencies

| Dependency                         | Type                       | Notes                                                    |
| ---------------------------------- | -------------------------- | -------------------------------------------------------- |
| `Case` (standard object)           | Salesforce Standard Object | Required; must be enabled in the org                     |
| `CaseLookupAction.cls`             | Apex Class                 | Must be deployed before the agent bundle                 |
| Agentforce (Einstein Agent)        | Org Feature                | Must be enabled; requires appropriate Salesforce license |
| `aiAuthoringBundles` metadata type | Salesforce metadata        | Supported in API version 60.0+; project targets 65.0     |

---

## Change History

| Date       | Author              | Change Description |
| ---------- | ------------------- | ------------------ |
| 2026-02-27 | Documentation Agent | Initial creation   |
