# Duplicate Account Name Prevention

**Date:** 2026-02-22
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

> Create a duplicate prevention trigger on the Account object that blocks insert and update of Account records when a duplicate Account Name already exists (case-insensitive). Follow the existing handler class pattern. Use API version 65.0.

### Business Objective

Salesforce does not enforce uniqueness on the standard Account Name field by default, which means the org can accumulate multiple records representing the same company under slightly different capitalisation (e.g., "Acme Corp" and "ACME CORP"). This leads to data quality issues such as duplicate reporting, split opportunity pipelines, and conflicting record ownership. This feature prevents that problem at the point of entry by blocking any insert or update that would create a name collision, regardless of case.

### Summary

The `AccountTriggerHandler` class was extended with a new private method, `preventDuplicateAccounts`, that performs a single bulkified SOQL query for all incoming Account Names, compares the results case-insensitively, and calls `addError()` on any record whose name already exists in the database or collides with another record in the same DML batch. No new metadata files, permission sets, or declarative components were required. The feature rides entirely on the existing `AccountTrigger` and `AccountTriggerHandler` infrastructure.

---

## Components Modified

### Admin Components

None. No custom fields, custom objects, validation rules, flows, or permission sets were created. The Account object's standard `Name` field is used for the duplicate check.

### Development Components (Code)

#### Modified Apex Classes

| Class | Change Type | Description |
|-------|-------------|-------------|
| `AccountTriggerHandler` | Modified | Added `preventDuplicateAccounts` private method and `DUPLICATE_NAME_ERROR` named constant |
| `AccountTriggerHandlerTest` | Modified | Added 7 new test methods covering all duplicate-prevention scenarios |

#### Unchanged Files (Referenced, Not Modified)

| File | Reason Not Modified |
|------|---------------------|
| `AccountTrigger.trigger` | Already handles `before insert` and `before update`; no changes needed |

---

## Implementation Details

### New Named Constant

```apex
@TestVisible
private static final String DUPLICATE_NAME_ERROR =
    'A duplicate Account with this name already exists.';
```

Declared `@TestVisible` so test methods can assert on the exact error text without duplicating a hard-coded string literal across multiple test methods.

### New Method: `preventDuplicateAccounts`

**Signature:**
```apex
private void preventDuplicateAccounts(List<Account> newAccounts, Map<Id, Account> oldMap)
```

Also declared `@TestVisible` on the method signature so unit tests can exercise it directly if needed.

**Called from:**

| Context Method | `oldMap` Value Passed |
|----------------|-----------------------|
| `beforeInsert(List<Account>)` | `null` |
| `beforeUpdate(List<Account>, Map<Id,Account>)` | `Trigger.oldMap` |

### Detection Logic (Step-by-Step)

```
Step 1: Collect all non-blank Names from Trigger.new, lowercased,
        into incomingNamesLower (a Set<String>).
        If the set is empty, return immediately.

Step 2: On update, collect all record Ids being updated into
        excludeIds (from oldMap.keySet()). On insert, excludeIds
        is empty.

Step 3: Execute ONE SOQL query for the entire batch:
          SELECT Name FROM Account
          WHERE Name IN :incomingNamesLower
            AND Id NOT IN :excludeIds
          WITH USER_MODE
        Build existingNamesLower — lowercased Names found in the database.

Step 4: Walk Trigger.new in order, maintaining seenInBatchLower:
          a. Blank Name   → skip (not a duplicate concern).
          b. Name found in existingNamesLower
                          → addError(DUPLICATE_NAME_ERROR); continue.
          c. Name found in seenInBatchLower (within-batch collision)
                          → addError(DUPLICATE_NAME_ERROR); continue.
          d. Clean record → add Name to seenInBatchLower.
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Case-insensitive via `toLowerCase()` on both sides | SOQL `WHERE Name IN :set` treats string comparisons as case-insensitive for the standard `Name` field, but the Apex-side set is also lowercased to guarantee consistent comparisons across all locales |
| Single SOQL query for the entire batch | Bulkification — avoids hitting the 100-SOQL governor limit when 200+ records arrive in one batch |
| `excludeIds` from `oldMap.keySet()` on update | Prevents false positives when an Account is saved without changing its Name, or when only unrelated fields change |
| `seenInBatchLower` walking Trigger.new in order | Detects within-batch collisions. The first occurrence in the list is treated as the winner; every subsequent record with the same name is blocked |
| `addError()` on the `Name` field, not the record | Surfaces the error adjacent to the Name field in the Salesforce UI, giving the end user a precise indication of which field caused the rejection |
| `WITH USER_MODE` on SOQL | Enforces object- and field-level security as required by project conventions (API 65.0) |

### Trigger Execution Order (Before Context)

`preventDuplicateAccounts` was inserted as the first validation step in both before-contexts, ahead of `validateAccounts` and `evaluateHealthRating`:

```
beforeInsert:
  1. setAccountDefaults(newAccounts)
  2. preventDuplicateAccounts(newAccounts, null)   <-- added here
  3. validateAccounts(newAccounts, null)
  4. evaluateHealthRating(newAccounts, null)

beforeUpdate:
  1. preventDuplicateAccounts(newAccounts, oldMap) <-- added here
  2. validateAccounts(newAccounts, oldMap)
  3. evaluateHealthRating(newAccounts, oldMap)
```

A duplicate is caught and the record blocked before any further validation or field-stamping logic runs against it.

---

## Data Flow

### Architecture Diagram

```
 User / External System
         |
         | insert or update Account(s)
         v
 ┌───────────────────────┐
 │     AccountTrigger    │  before insert / before update  (unchanged)
 └──────────┬────────────┘
            |
            v
 ┌──────────────────────────────────────────────────────────────┐
 │                   AccountTriggerHandler                      │
 │                                                              │
 │  beforeInsert / beforeUpdate                                 │
 │    |                                                         │
 │    +-- setAccountDefaults()                                  │
 │    |                                                         │
 │    +-- preventDuplicateAccounts()           <-- NEW          │
 │    |      |                                                  │
 │    |      +-- collect incomingNamesLower                     │
 │    |      +-- collect excludeIds (update only)               │
 │    |      +-- SOQL: SELECT Name FROM Account                 │
 │    |      |         WHERE Name IN :incomingNamesLower        │
 │    |      |           AND Id NOT IN :excludeIds              │
 │    |      |         WITH USER_MODE          (1 query total)  │
 │    |      +-- walk Trigger.new                               │
 │    |           +-- DB duplicate?     -> addError()           │
 │    |           +-- Batch duplicate?  -> addError()           │
 │    |           +-- Clean             -> track in seenInBatch │
 │    |                                                         │
 │    +-- validateAccounts()                                    │
 │    +-- evaluateHealthRating()                                │
 └──────────────────────────────────────────────────────────────┘
            |
            | addError() called  -> DML rolls back for that record
            | no error           -> record written to database
            v
 ┌───────────────────────┐
 │   Database / Caller   │
 └───────────────────────┘
```

---

## File Locations

| Component | Path |
|-----------|------|
| Trigger | `force-app/main/default/triggers/AccountTrigger.trigger` |
| Handler class | `force-app/main/default/classes/AccountTriggerHandler.cls` |
| Handler class metadata | `force-app/main/default/classes/AccountTriggerHandler.cls-meta.xml` |
| Test class | `force-app/main/default/classes/AccountTriggerHandlerTest.cls` |
| Test class metadata | `force-app/main/default/classes/AccountTriggerHandlerTest.cls-meta.xml` |

---

## Testing

### Coverage Summary

| Class | New Method Added | Expected Coverage |
|-------|-----------------|-------------------|
| `AccountTriggerHandler` | `preventDuplicateAccounts` | ~95%+ (combined with pre-existing test coverage) |
| `AccountTriggerHandlerTest` | 7 new test methods | N/A (test class) |

### New Test Method Inventory

#### Insert Scenarios

| Test Method | Scenario | Expected Outcome |
|-------------|----------|-----------------|
| `insert_uniqueName_succeeds` | Account Name does not exist anywhere in the org | Insert succeeds; no errors |
| `insert_duplicateNameSameCase_failsWithError` | Inserted Name exactly matches an existing Account Name | Insert fails; error message matches `DUPLICATE_NAME_ERROR` |
| `insert_duplicateNameDifferentCase_failsWithError` | Inserted Name matches an existing Name only in a different case (e.g., "ACME CORP" vs. "Acme Corp") | Insert fails; validates case-insensitive comparison |

#### Update Scenarios

| Test Method | Scenario | Expected Outcome |
|-------------|----------|-----------------|
| `update_nameTakenByAnotherAccount_failsWithError` | Account renamed to a Name already owned by a different Account | Update fails; error message matches `DUPLICATE_NAME_ERROR` |
| `update_sameNameAsOwnCurrentName_succeeds` | Account saved with its own current Name unchanged (other fields may change) | Update succeeds; validates `excludeIds` prevents false positives |

#### Within-Batch Duplicate

| Test Method | Scenario | Expected Outcome |
|-------------|----------|-----------------|
| `insert_withinBatchDuplicateName_secondRecordFails` | Two Accounts with the same Name inserted in a single DML call | First record succeeds; second record fails with `DUPLICATE_NAME_ERROR` |

#### Bulk Scenario

| Test Method | Scenario | Expected Outcome |
|-------------|----------|-----------------|
| `bulkInsert_200UniqueNames_allSucceed` | 200 Accounts with entirely unique Names inserted in one batch | All 200 succeed; verifies no false positives and single-SOQL approach stays within governor limits |

### Test Patterns Used

- `Database.insert(record, false, AccessLevel.SYSTEM_MODE)` — partial-success mode (`allOrNone=false`) used for all duplicate tests so individual `SaveResult` errors can be inspected without an uncaught exception aborting the test.
- `resetGuards()` helper called before every update DML to reset `hasRunBefore` and `hasRunAfter`, ensuring the handler fires as it would in a fresh transaction.
- `AccountTriggerHandler.DUPLICATE_NAME_ERROR` referenced directly in test assertions via `@TestVisible`, eliminating string duplication between source and test.

---

## Security

### Sharing Model

- `AccountTriggerHandler` is declared `with sharing`, so the running user's record-level access (OWD, sharing rules, role hierarchy) is respected.
- The SOQL query inside `preventDuplicateAccounts` uses `WITH USER_MODE`, enforcing object-level and field-level security on the query results.

### Permission Requirements

No new permissions are required. Any user with Create or Edit access on the Account object will have the duplicate-name check applied automatically by the trigger.

---

## Known Warnings and Limitations

### 1. Race Condition in High-Concurrency Environments

`preventDuplicateAccounts` prevents duplicates within a single synchronous transaction. In high-volume environments where two separate transactions start simultaneously, both could pass the SOQL check independently — neither sees the other's uncommitted record — and both could succeed, resulting in a duplicate pair. The only database-level guarantee against this is a Unique custom field or a custom External ID field enforced at the platform level. That was explicitly out of scope for this feature.

### 2. SOQL Filter Uses Lowercased Values Against a Mixed-Case Field

`WHERE Name IN :incomingNamesLower` passes lowercased strings into the SOQL filter. Because SOQL string comparisons on the standard `Name` field are case-insensitive in Salesforce, this works correctly. The Apex-side `toLowerCase()` on the result set (`existingNamesLower`) is the definitive comparison step. This is a minor semantic inconsistency flagged during code review; the runtime behaviour is correct.

### 3. Blank-Name Records Are Not Blocked

Records where `Name` is blank or null are skipped by the duplicate check (guarded by `String.isNotBlank`). Blank-name validation is a separate concern that should be handled by a required-field configuration or a validation rule, not by this feature.

### 4. Error Logging for Task DML Uses System.debug Only

The `handleSaveResults` helper used by `createAtRiskTasks` (an unrelated handler method) writes DML failures to debug logs via `System.debug(LoggingLevel.ERROR, ...)`. This is invisible in production without an active debug log session. This is a pre-existing handler limitation, not introduced by this feature.

---

## Notes and Considerations

### Interaction with Existing Handler Features

This feature does not affect `evaluateHealthRating` or `createAtRiskTasks`. If `preventDuplicateAccounts` adds an error to a record, that record's DML is rolled back entirely, so neither health rating stamping nor at-risk task creation can fire for a blocked record. Records that pass the duplicate check continue through the handler pipeline normally.

### Why Not a Validation Rule?

Case-insensitive duplicate detection across all existing records cannot be achieved reliably with a standard Salesforce validation rule. Validation rules lack a bulk-safe, case-insensitive cross-record SOQL lookup mechanism without complex and fragile formula workarounds. The Apex trigger approach is the correct tool for this requirement.

### Deployment Notes

Only existing Apex class files were modified. No new metadata types were introduced, so no admin metadata needs to be deployed first.

```bash
# Deploy only the modified classes
sf project deploy start -d force-app/main/default/classes/AccountTriggerHandler.cls
sf project deploy start -d force-app/main/default/classes/AccountTriggerHandlerTest.cls

# Or deploy the entire classes directory
sf project deploy start -d force-app/main/default/classes
```

---

## Change History

| Date | Author | Change Description |
|------|--------|--------------------|
| 2026-02-22 | Documentation Agent | Initial creation |
