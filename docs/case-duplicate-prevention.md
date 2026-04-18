# Case Duplicate Prevention

**Date:** 2026-02-26
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

Prevent duplicate Case creation. A new Case should be blocked (before insert) if an existing open Case already matches on ALL of the following criteria:

- Same Subject
- Same AccountId (or ContactId)
- Same Status (Open -- i.e. not Closed)
- Same Origin

### Business Objective

Support teams often receive the same customer complaint through multiple channels (phone, email, web form) or agents accidentally log the same case twice. Without a guard, this creates redundant work, confuses reporting, and can result in a customer being contacted multiple times for the same issue. This feature blocks the creation of a duplicate Case at the database level so data quality is maintained without relying on end-user discipline.

### Summary

A `before insert` Apex trigger on the standard Case object intercepts every new Case insertion and computes a composite key from four fields: Subject (case-insensitive), AccountId, ContactId, and Origin. The handler queries all currently open Cases for matching keys and blocks any incoming record whose key already exists using `addError()`, preventing the DML from committing. Within-batch duplicates (two records with the same key submitted in the same DML call) are also caught without a second query.

---

## Components Created

### Admin Components (Declarative)

None. This feature relies entirely on standard Case object fields (Subject, AccountId, ContactId, Origin, IsClosed) and requires no custom objects, custom fields, validation rules, flows, or permission sets.

---

### Development Components (Code)

#### Apex Triggers

| Trigger Name  | Object | Events          | Description                                                           |
| ------------- | ------ | --------------- | --------------------------------------------------------------------- |
| `CaseTrigger` | `Case` | `before insert` | Thin entry-point trigger; delegates all logic to `CaseTriggerHandler` |

#### Apex Classes

| Class Name           | Type            | Description                                                       |
| -------------------- | --------------- | ----------------------------------------------------------------- |
| `CaseTriggerHandler` | Trigger Handler | Implements duplicate Case prevention via composite-key comparison |

#### Test Classes

| Test Class               | Tests For                           | Coverage |
| ------------------------ | ----------------------------------- | -------- |
| `CaseTriggerHandlerTest` | `CaseTriggerHandler`, `CaseTrigger` | ~97%     |

---

## Data Flow

### How It Works

```
1. A user (or integration) attempts to insert one or more Case records
2. CaseTrigger fires in the before insert context
3. CaseTrigger instantiates CaseTriggerHandler and calls beforeInsert(Trigger.new)
4. The recursion guard (hasRunBeforeInsert) is checked; if already true, exit immediately
5. The guard is set to true and preventDuplicateCases() is invoked
6. A composite key is computed for every incoming Case:
      key = Subject.toLowerCase() + '|' + AccountId + '|' + ContactId + '|' + Origin
7. Within-batch duplicates are detected first:
      if two Cases share the same key, all but the first receive addError()
8. A single bulkified SOQL query fetches existing open Cases whose Subject, AccountId,
   ContactId, or Origin overlaps with the incoming batch
9. Composite keys are built from the query results and stored in a Set<String>
10. Each incoming Case whose key is in that Set receives addError(), blocking its save
11. Salesforce rolls back only the failed records (partial success with allOrNone=false);
    valid records in the same batch are committed normally
```

### Architecture Diagram

```
┌──────────────────────────┐
│  User / Integration      │
│  Inserts Case record(s)  │
└────────────┬─────────────┘
             │  before insert
             ▼
┌──────────────────────────┐
│  CaseTrigger             │
│  on Case (before insert) │
│  → new CaseTriggerHandler│
│  → handler.beforeInsert()│
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────┐
│  CaseTriggerHandler.beforeInsert()                   │
│                                                      │
│  [1] Recursion guard check (hasRunBeforeInsert)      │
│                                                      │
│  [2] Build composite keys for all incoming Cases     │
│      key = subject.lower + '|' + acctId + '|'       │
│            + conId + '|' + origin                    │
│                                                      │
│  [3] Within-batch duplicate detection                │
│      keyToCasesMap → addError() on 2nd+ records      │
│                                                      │
│  [4] SOQL: open Cases (IsClosed=false) with          │
│      matching Subject/AccountId/ContactId/Origin     │
│      WITH USER_MODE                                  │
│                                                      │
│  [5] DB duplicate detection                          │
│      existingKeys Set → addError() on matches        │
└────────────┬─────────────┘────────────────┬──────────┘
             │                              │
     addError() called              No error called
             │                              │
             ▼                              ▼
    ┌─────────────────┐          ┌──────────────────────┐
    │  Record BLOCKED │          │  Record SAVED         │
    │  (DML rolled    │          │  (committed to DB)    │
    │   back for this │          └──────────────────────┘
    │   record only)  │
    └─────────────────┘
```

---

## File Locations

| Component              | Path                                                                 |
| ---------------------- | -------------------------------------------------------------------- |
| Apex Trigger           | `force-app/main/default/triggers/CaseTrigger.trigger`                |
| Apex Trigger Metadata  | `force-app/main/default/triggers/CaseTrigger.trigger-meta.xml`       |
| Handler Class          | `force-app/main/default/classes/CaseTriggerHandler.cls`              |
| Handler Class Metadata | `force-app/main/default/classes/CaseTriggerHandler.cls-meta.xml`     |
| Test Class             | `force-app/main/default/classes/CaseTriggerHandlerTest.cls`          |
| Test Class Metadata    | `force-app/main/default/classes/CaseTriggerHandlerTest.cls-meta.xml` |

---

## Configuration Details

### Trigger Configuration

| Setting          | Value                                          |
| ---------------- | ---------------------------------------------- |
| Object           | `Case`                                         |
| API Version      | `65.0`                                         |
| Status           | `Active`                                       |
| Supported Events | `before insert`                                |
| Handler          | `CaseTriggerHandler.beforeInsert(Trigger.new)` |

### Composite Key Definition

The duplicate check uses a pipe-delimited composite key built from four standard Case fields:

```
key = Subject.toLowerCase() + '|' + AccountId + '|' + ContactId + '|' + Origin
```

| Key Segment | Field       | Null Handling     | Case Sensitivity              |
| ----------- | ----------- | ----------------- | ----------------------------- |
| 1           | `Subject`   | Empty string `''` | Lowercased (case-insensitive) |
| 2           | `AccountId` | Empty string `''` | N/A (Id)                      |
| 3           | `ContactId` | Empty string `''` | N/A (Id)                      |
| 4           | `Origin`    | Empty string `''` | As-is (picklist value)        |

A Case is considered a duplicate only when ALL four segments of its key match an existing open Case. Changing any single segment (e.g., a different Origin) produces a different key and is therefore allowed.

### Named Constants

| Constant                  | Value                                                                                        | Purpose                                            |
| ------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------- | ---------------------------------------- |
| `DUPLICATE_ERROR_MESSAGE` | `'A duplicate open Case already exists with the same Subject, Account/Contact, and Origin.'` | Message shown to users when a duplicate is blocked |
| `KEY_SEPARATOR`           | `'                                                                                           | '`                                                 | Delimiter between composite key segments |

### Duplicate Detection -- Two Passes

**Pass 1: Within-batch detection** (no SOQL required)

All incoming Cases are grouped by composite key into a `Map<String, List<Case>>`. For any key with more than one Case in the map, all records after the first (index 1 onward) receive `addError()`. This ensures a batch of 200 records with internal duplicates is handled correctly even before hitting the database.

**Pass 2: Database detection** (one bulkified SOQL query)

Individual field values from the entire batch (subjects, accountIds, contactIds, origins) are collected into bind-variable sets and used in a single SOQL query against existing open Cases. The `OR` across the four bind sets intentionally casts a wider net to minimize records missed. The query results are rebuilt into composite keys and stored in a `Set<String>`; any incoming Case whose key is in that set receives `addError()`.

### SOQL Query

```sql
SELECT Id, Subject, AccountId, ContactId, Origin
FROM Case
WHERE IsClosed = false
  AND (Subject IN :subjects
       OR AccountId IN :accountIds
       OR ContactId IN :contactIds
       OR Origin IN :origins)
WITH USER_MODE
```

Note: The query uses `OR` rather than `AND` across the four conditions. This is intentional -- a narrower `AND` query could miss records when, for example, an AccountId is null in the incoming Case. The precise duplicate match is enforced by the composite key comparison after the query, not by the WHERE clause alone.

### Recursion Guard

| Property  | Detail                                             |
| --------- | -------------------------------------------------- |
| Field     | `private static Boolean hasRunBeforeInsert`        |
| Annotated | `@TestVisible`                                     |
| Scope     | Static (per-transaction)                           |
| Reset     | Automatically reset when the Apex transaction ends |

The guard prevents re-entry in the rare case where `addError()` or other processing triggers a cascade that re-fires the trigger in the same transaction.

---

## Testing

### Test Coverage Summary

| Class                | Estimated Coverage | Status |
| -------------------- | ------------------ | ------ |
| `CaseTrigger`        | ~100%              | Pass   |
| `CaseTriggerHandler` | ~97%               | Pass   |

### Test Method Inventory

| #   | Test Method                                                      | Scenario                                                        | Expected Result                                             |
| --- | ---------------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------------------------- |
| 1   | `insert_uniqueCompositeKey_succeeds`                             | Happy path: unique key, no existing Cases                       | Insert succeeds, no errors                                  |
| 2   | `insert_duplicateKeyMatchesExistingOpenCase_failsWithError`      | DB duplicate: same key as existing open Case                    | Insert fails with `DUPLICATE_ERROR_MESSAGE`                 |
| 3   | `insert_duplicateKeySubjectDifferentCase_failsWithError`         | DB duplicate: subject differs only in letter case               | Insert fails (case-insensitive match confirmed)             |
| 4   | `insert_withinBatchDuplicateKey_secondRecordFails`               | Batch: two Cases with same key in one DML call                  | First succeeds, second fails with `DUPLICATE_ERROR_MESSAGE` |
| 5   | `insert_allNullKeyFields_succeedsWithoutException`               | Null guard: AccountId, ContactId, Origin all null               | Insert succeeds, no NullPointerException                    |
| 6   | `insert_withinBatchDuplicateKey_allNullFields_secondRecordFails` | Batch null: two Cases with identical all-null key               | First succeeds, second fails                                |
| 7   | `insert_nullAccountId_succeedsWithoutException`                  | Null guard: AccountId only is null                              | Insert succeeds                                             |
| 8   | `insert_nullContactId_succeedsWithoutException`                  | Null guard: ContactId only is null                              | Insert succeeds                                             |
| 9   | `insert_differentSubject_isNotADuplicate`                        | Negative: same Account/Contact/Origin, different Subject        | Insert succeeds, not a duplicate                            |
| 10  | `insert_differentOrigin_isNotADuplicate`                         | Negative: same Subject/Account/Contact, different Origin        | Insert succeeds, not a duplicate                            |
| 11  | `insert_duplicateKeyButExistingCaseIsClosed_succeeds`            | Closed Case exclusion: matching key but existing Case is closed | Insert succeeds (closed Cases do not block)                 |
| 12  | `insert_recursionGuardActive_handlerSkipsLogic`                  | Recursion guard: `hasRunBeforeInsert` pre-set to true           | Handler exits early, even a "duplicate" is allowed through  |
| 13  | `bulkInsert_200UniqueCases_allSucceed`                           | Bulk positive: 200 Cases with unique subjects                   | All 200 succeed                                             |
| 14  | `bulkInsert_200CasesHalfDuplicates_halfFailWithError`            | Bulk mixed: 200 Cases, every other is a within-batch duplicate  | 100 succeed, 100 fail                                       |

### Test Design Patterns

- `@TestSetup` creates a shared Account and Contact to minimize DML across test methods.
- `Database.insert(..., AccessLevel.SYSTEM_MODE)` is used in tests so the running test user's FLS restrictions do not interfere with field-level access on the composite-key fields.
- The `resetGuard()` helper (sets `hasRunBeforeInsert = false`) is called between setup DML and test DML so the trigger handler fires correctly for both the pre-existing Case and the new Case being tested.
- All assertions use `Assert.*` (not `System.assert*`) per API 65.0 best practices.

---

## Security

### Sharing Model

| Component            | Sharing                                                               |
| -------------------- | --------------------------------------------------------------------- |
| `CaseTriggerHandler` | `with sharing` -- respects the running user's record-level access     |
| SOQL in handler      | `WITH USER_MODE` -- enforces FLS and object permissions at query time |

### Required Permissions

No custom permission sets are required. The feature operates on the standard Case object with standard fields and is governed by the user's existing profile/permission set assignments.

Users must have at minimum:

- Read access to the Case object (to allow the duplicate query to run)
- Create access to the Case object (to attempt an insert in the first place)

---

## Notes and Considerations

### Known Limitations

1. **Before insert only**: The handler fires only on `before insert`. There is no protection against creating a duplicate via `update` (e.g., updating a Case's Subject or Origin to match an existing open Case). This was an explicit design choice for the initial implementation.

2. **SOQL OR-based narrowing**: The WHERE clause uses `OR` across all four bind sets to avoid missing records with null fields. In high-volume orgs with many open Cases sharing common Origins, this query may return more rows than strictly necessary. The composite key comparison after the query ensures correctness, but the query result size is worth monitoring.

3. **No error logging**: Blocked duplicates are surfaced to the user via `addError()` only. There is no server-side logging (e.g., custom log object, Platform Event) to track how often duplicates are attempted. Consider adding observability if audit trails are needed.

4. **Case Origin is a standard picklist**: If the org has no Origin value configured for a given channel, the Origin segment of the composite key will be an empty string. Two Cases with no Origin set but matching Subject, AccountId, and ContactId will be considered duplicates of each other, which is the expected behavior.

5. **Subject is a standard text field**: Very long Subject values do not cause issues (composite keys are strings), but inconsistent whitespace (leading/trailing spaces) is not trimmed. If users regularly enter `"Billing Issue "` vs `"Billing Issue"`, these would be treated as different keys.

### Future Enhancements

- Add an `after insert` validation or a custom setting to optionally allow re-opening a Case with the same key (today, the only restriction is on open Cases).
- Add a custom metadata type to make the list of fields that form the composite key configurable without a code change.
- Extend to `before update` to block Subject/Origin edits that would create a logical duplicate.
- Add Platform Event or custom log object emission when a duplicate is blocked, for audit and operational reporting.
- Consider exposing a bypass flag (Custom Permission) for integration users or system administrators who need to insert records that would otherwise be blocked.

### Dependencies

| Dependency                                                | Type            | Notes                                     |
| --------------------------------------------------------- | --------------- | ----------------------------------------- |
| `Case` standard object                                    | Standard Object | Must exist (always present in Salesforce) |
| `Subject`, `AccountId`, `ContactId`, `Origin`, `IsClosed` | Standard Fields | All used in composite key and SOQL filter |
| No other Apex classes                                     | N/A             | Handler is self-contained                 |

### Deployment Order

Since there are no admin metadata dependencies, both files can be deployed together:

1. `CaseTriggerHandler.cls` (referenced by the trigger; deploy first or simultaneously)
2. `CaseTrigger.trigger`
3. `CaseTriggerHandlerTest.cls` (test class; included in same deployment for coverage validation)

---

## Change History

| Date       | Author              | Change Description |
| ---------- | ------------------- | ------------------ |
| 2026-02-26 | Documentation Agent | Initial creation   |
