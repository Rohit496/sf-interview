# Account Health Indicator

**Date:** 2026-02-21
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

Account Health Indicator -- two custom fields on Account, a trigger to auto-evaluate health rating when AnnualRevenue or NumberOfEmployees changes (with Task creation on "At Risk"), and an LWC card for the Account record page.

### Business Objective

Sales teams need a fast, visual way to understand the financial health of each Account without manually interpreting revenue and headcount figures. This feature automatically classifies every Account into one of three health tiers (Good, Average, At Risk) based on Annual Revenue and Number of Employees thresholds, alerts the Account Owner with a high-priority follow-up task the moment an account transitions to "At Risk", and surfaces the current rating as a color-coded badge directly on the Account record page.

### Summary

The Account Health Indicator feature adds two custom fields to the Account object and a trigger-based evaluation engine that classifies accounts into health tiers on every insert or qualifying update. When an account transitions to "At Risk", the system automatically creates a high-priority Task for the Account Owner due in three days. A Lightning Web Component card on the Account record page displays the current rating as a color-coded badge alongside the date of last evaluation.

---

## Components Created

### Admin Components (Declarative)

#### Custom Fields

| Object | Field API Name | Type | Required | Description |
|--------|----------------|------|----------|-------------|
| `Account` | `Health_Rating__c` | Picklist | No | Automatically evaluated health tier: Good, Average, or At Risk |
| `Account` | `Health_Evaluated_Date__c` | DateTime | No | Timestamp of the most recent health rating evaluation |

**Health_Rating__c Picklist Values**

| Value | API Name | Default |
|-------|----------|---------|
| Good | Good | No |
| Average | Average | No |
| At Risk | At Risk | No |

#### Permission Sets

| Permission Set API Name | Label | Description |
|-------------------------|-------|-------------|
| `AccountHealth_Fields` | AccountHealth Fields | Grants Read and Edit access to `Health_Rating__c` and `Health_Evaluated_Date__c`. Assign to Account Managers or any user who needs to view or update account health evaluations. |

**Field Permissions Granted**

| Field | Readable | Editable |
|-------|----------|----------|
| `Account.Health_Rating__c` | Yes | Yes |
| `Account.Health_Evaluated_Date__c` | Yes | Yes |

---

### Development Components (Code)

#### Apex Classes

| Class Name | API Version | Sharing | Description |
|------------|-------------|---------|-------------|
| `AccountTriggerHandler` | 65.0 | `with sharing` | Trigger handler for the Account object. Extended with health rating evaluation (before insert/update) and At Risk task creation (after update). Follows the one-trigger-per-object handler pattern with separate recursion guards for before and after contexts. |
| `AccountTriggerHandlerTest` | 65.0 | N/A (`@IsTest`) | Comprehensive test class with 17 test methods covering insert, update, null-safety, boundary, recursion guard, and bulk scenarios. |

#### Apex Triggers

| Trigger Name | Object | Events | Description |
|--------------|--------|--------|-------------|
| `AccountTrigger` | `Account` | before insert, before update, after insert, after update | Single entry-point trigger. Delegates all logic to `AccountTriggerHandler`. Keeps the trigger file thin and testable. |

#### Lightning Web Components

| Component Name | Master Label | Target | Description |
|----------------|--------------|--------|-------------|
| `accountHealthIndicator` | Account Health Indicator | `lightning__RecordPage` (Account only) | Card component for the Account record page. Displays `Health_Rating__c` as a color-coded badge and `Health_Evaluated_Date__c` as a formatted date/time string. Uses `@wire` with `getRecord` for reactive data fetching. |

**LWC Files**

| File | Purpose |
|------|---------|
| `accountHealthIndicator.html` | Template with `lightning-card`, loading spinner, error state, and health badge/date display |
| `accountHealthIndicator.js` | Controller with `@wire`, computed getters for `isLoading`, `hasError`, `healthRating`, `formattedEvaluatedDate`, and `badgeClass` |
| `accountHealthIndicator.css` | SLDS-token-based styles for the three badge color variants (success/warning/error) |
| `accountHealthIndicator.js-meta.xml` | Bundle metadata exposing the component to Lightning App Builder for Account record pages |

---

## Health Rating Logic

### Evaluation Rules

The `evaluateHealthRating` method applies the following rules in priority order:

| Tier | Condition | Both conditions required? |
|------|-----------|--------------------------|
| **Good** | `AnnualRevenue > $10,000,000` AND `NumberOfEmployees > 500` | Yes (AND) |
| **At Risk** | `AnnualRevenue < $1,000,000` AND `NumberOfEmployees < 100` | Yes (AND) |
| **Average** | All other combinations (default/fallback) | N/A |

**Null handling:** Null `AnnualRevenue` is treated as `0`. Null `NumberOfEmployees` is treated as `0`. Both null fields therefore evaluate to At Risk.

**Threshold constants (defined in `AccountTriggerHandler`):**

| Constant | Value | Purpose |
|----------|-------|---------|
| `REVENUE_HIGH_THRESHOLD` | 10,000,000 | Good revenue floor (exclusive) |
| `REVENUE_LOW_THRESHOLD` | 1,000,000 | At Risk revenue ceiling (exclusive) |
| `EMPLOYEES_HIGH_THRESHOLD` | 500 | Good employee floor (exclusive) |
| `EMPLOYEES_LOW_THRESHOLD` | 100 | At Risk employee ceiling (exclusive) |

### When Evaluation Fires

- **On insert:** Always evaluates every new account record.
- **On update:** Only re-evaluates when `AnnualRevenue` or `NumberOfEmployees` has changed. Updates to other fields (e.g., Name, Phone) skip re-evaluation, leaving `Health_Rating__c` and `Health_Evaluated_Date__c` unchanged.

### At Risk Task Creation

When `Health_Rating__c` transitions TO `'At Risk'` from any other value during an update, the handler creates one Task per qualifying account:

| Task Field | Value |
|------------|-------|
| Subject | `'Review At Risk Account: ' + Account.Name` |
| ActivityDate | `Date.today().addDays(3)` |
| OwnerId | `Account.OwnerId` |
| WhatId | `Account.Id` |
| Status | `Not Started` |
| Priority | `High` |

Tasks are inserted with `Database.insert(tasks, false, AccessLevel.USER_MODE)` (partial success mode). DML errors are logged via `System.debug(LoggingLevel.ERROR, ...)` and do not block the rest of the batch.

A task is NOT created when:
- The account was already rated At Risk before the update (no transition).
- The rating is moving away from At Risk (e.g., At Risk to Good).
- The account is being inserted (only applies to updates).

---

## Data Flow

### How It Works

```
1. User creates or updates an Account record (via UI, API, or data load).
2. AccountTrigger fires.
3. If before insert or before update:
   a. AccountTriggerHandler.beforeInsert / beforeUpdate is called.
   b. Recursion guard (hasRunBefore) is checked; returns early if already fired.
   c. evaluateHealthRating() is called:
      - On update, skips records where AnnualRevenue and NumberOfEmployees are unchanged.
      - Applies Good / At Risk / Average rule and sets Health_Rating__c.
      - Stamps Health_Evaluated_Date__c = Datetime.now().
4. Record is saved to the database with the new field values.
5. If after update:
   a. AccountTriggerHandler.afterUpdate is called.
   b. Recursion guard (hasRunAfter) is checked; returns early if already fired.
   c. createAtRiskTasks() compares old vs new Health_Rating__c for each record.
   d. For records that transitioned to 'At Risk', a Task is built.
   e. All tasks are bulk-inserted in a single DML call (partial success, USER_MODE).
```

### Architecture Diagram

```
+-----------------------+       +---------------------------+       +---------------------------+
|   User / API / Load   |------>|   Account Record (DML)    |------>|    AccountTrigger         |
|   (Insert or Update)  |       |   Account Object          |       |    (before/after contexts) |
+-----------------------+       +---------------------------+       +-------------+-------------+
                                                                                  |
                                              +-----------------------------------+-----------------------------------+
                                              |                                                                       |
                                              v (before insert / before update)                                      v (after update)
                               +--------------+------------------+                                  +----------------+-----------------+
                               |   AccountTriggerHandler         |                                  |   AccountTriggerHandler          |
                               |   .beforeInsert()               |                                  |   .afterUpdate()                 |
                               |   .beforeUpdate()               |                                  |   .createAtRiskTasks()           |
                               |         |                       |                                  |         |                        |
                               |         v                       |                                  |         v                        |
                               |   evaluateHealthRating()        |                                  |   Compare old vs new rating      |
                               |   - Apply Good/AtRisk/Avg rule  |                                  |   - Transition to 'At Risk'?     |
                               |   - Set Health_Rating__c        |                                  |   - Build Task per account       |
                               |   - Stamp Health_Evaluated_Date |                                  |   - Bulk insert (USER_MODE)      |
                               +---------------------------------+                                  +----------------------------------+
                                              |                                                                       |
                                              v                                                                       v
                               +------------------------------+                                  +---------------------------+
                               |   Account record saved with  |                                  |   Task record created     |
                               |   updated health fields       |                                  |   (Subject, Due +3 days,  |
                               +------------------------------+                                  |    Priority=High)         |
                                              |                                                  +---------------------------+
                                              |
                                              v
                               +-------------------------------------------------+
                               |   accountHealthIndicator LWC                    |
                               |   @wire getRecord (Health_Rating__c,            |
                               |                    Health_Evaluated_Date__c)    |
                               |   - Renders color-coded badge for rating        |
                               |   - Formats and displays evaluated date         |
                               +-------------------------------------------------+
```

---

## File Locations

| Component | Path |
|-----------|------|
| Health Rating field metadata | `force-app/main/default/objects/Account/fields/Health_Rating__c.field-meta.xml` |
| Health Evaluated Date field metadata | `force-app/main/default/objects/Account/fields/Health_Evaluated_Date__c.field-meta.xml` |
| Permission Set | `force-app/main/default/permissionsets/AccountHealth_Fields.permissionset-meta.xml` |
| Trigger | `force-app/main/default/triggers/AccountTrigger.trigger` |
| Trigger metadata | `force-app/main/default/triggers/AccountTrigger.trigger-meta.xml` |
| Trigger Handler class | `force-app/main/default/classes/AccountTriggerHandler.cls` |
| Trigger Handler class metadata | `force-app/main/default/classes/AccountTriggerHandler.cls-meta.xml` |
| Test class | `force-app/main/default/classes/AccountTriggerHandlerTest.cls` |
| Test class metadata | `force-app/main/default/classes/AccountTriggerHandlerTest.cls-meta.xml` |
| LWC HTML template | `force-app/main/default/lwc/accountHealthIndicator/accountHealthIndicator.html` |
| LWC JavaScript controller | `force-app/main/default/lwc/accountHealthIndicator/accountHealthIndicator.js` |
| LWC CSS styles | `force-app/main/default/lwc/accountHealthIndicator/accountHealthIndicator.css` |
| LWC bundle metadata | `force-app/main/default/lwc/accountHealthIndicator/accountHealthIndicator.js-meta.xml` |

---

## Configuration Details

### AccountTriggerHandler -- Key Implementation Details

**Recursion Guards**

The handler uses two separate static Boolean flags to prevent re-entrant trigger execution within a single transaction:

| Flag | Scope | Purpose |
|------|-------|---------|
| `hasRunBefore` | Static, `@TestVisible` | Guards `beforeInsert` and `beforeUpdate` contexts |
| `hasRunAfter` | Static, `@TestVisible` | Guards `afterInsert` and `afterUpdate` contexts |
| `hasRun` (legacy) | Static property, `@TestVisible` | Backward-compatible property mapping to both flags |

Both flags are `@TestVisible` so test classes can reset them between DML operations within the same test transaction.

**Health Rating Enum**

The handler uses an inner enum and a map to avoid magic strings:

```apex
public enum HealthRating { GOOD, AVERAGE, AT_RISK }

private static final Map<HealthRating, String> HEALTH_RATING_LABELS = new Map<HealthRating, String>{
    HealthRating.GOOD    => 'Good',
    HealthRating.AVERAGE => 'Average',
    HealthRating.AT_RISK => 'At Risk'
};
```

**DML Strategy**

- `createAtRiskTasks` uses `Database.insert(tasks, false, AccessLevel.USER_MODE)` (allOrNone = false, USER_MODE access level).
- The `handleSaveResults` helper logs any per-record DML failures via `System.debug(LoggingLevel.ERROR, ...)` without throwing, allowing partial batch success.

### AccountTrigger -- Context Routing

| Trigger Context | Handler Method |
|-----------------|----------------|
| before insert | `handler.beforeInsert(Trigger.new)` |
| before update | `handler.beforeUpdate(Trigger.new, Trigger.oldMap)` |
| after insert | `handler.afterInsert(Trigger.new, Trigger.newMap)` |
| after update | `handler.afterUpdate(Trigger.new, Trigger.newMap, Trigger.oldMap)` |

### accountHealthIndicator LWC -- Component Details

**Badge Color Mapping**

| Health Rating | CSS Class Applied | Visual Color |
|---------------|-------------------|--------------|
| Good | `slds-badge slds-theme_success` | Green |
| Average | `slds-badge slds-theme_warning` | Orange/Amber |
| At Risk | `slds-badge slds-theme_error` | Red |
| Null / Unknown | `slds-badge` | Default (grey) |

**Computed Getters**

| Getter | Returns |
|--------|---------|
| `isLoading` | `true` while `_wireResult` has neither data nor error |
| `hasError` | `true` when `_wireResult.error` is set |
| `healthRating` | String value of `Health_Rating__c`, or `null` |
| `formattedEvaluatedDate` | Locale-formatted date/time string, or `'Not yet evaluated'` if field is null |
| `badgeClass` | CSS class string based on health rating |

**Date Formatting**

The `formattedEvaluatedDate` getter uses `Intl.DateTimeFormat` with the `en-US` locale, rendering dates as: `Feb 21, 2026, 03:45 PM`.

**Target Configuration**

- Exposed to Lightning App Builder (`isExposed: true`).
- Restricted to `lightning__RecordPage` target, Account object only.

---

## Testing

### Test Coverage Summary

| Class | Test Methods | Key Scenarios Covered |
|-------|--------------|-----------------------|
| `AccountTriggerHandlerTest` | 17 | Insert (all tiers), Update (re-evaluation, skip, task creation), Null safety, Boundary/AND logic, Recursion guards, Bulk 200-record insert and update |

### Test Method Inventory

**evaluateHealthRating -- Insert Scenarios (8 tests)**

| Test Method | Scenario |
|-------------|----------|
| `insert_goodThresholds_setsGoodRating` | Revenue > $10M AND Employees > 500 produces Good |
| `insert_atRiskThresholds_setsAtRiskRating` | Revenue < $1M AND Employees < 100 produces At Risk |
| `insert_averageThresholds_setsAverageRating` | Mid-range revenue and employees produces Average |
| `insert_highRevenueButLowEmployees_setsAverageRating` | High revenue alone is not enough for Good (AND logic) |
| `insert_lowRevenueButHighEmployees_setsAverageRating` | Low employees alone is not enough for At Risk (AND logic) |
| `insert_nullRevenueAndEmployees_treatsAsZeroAndSetsAtRiskRating` | Both null treated as 0, produces At Risk |
| `insert_nullRevenueWithHighEmployees_setsAverageRating` | Null revenue (0) with high employees produces Average |
| `insert_nullEmployeesWithHighRevenue_setsAverageRating` | High revenue with null employees (0) produces Average |

**evaluateHealthRating -- Update Scenarios (2 tests)**

| Test Method | Scenario |
|-------------|----------|
| `update_noChangeToRevenueOrEmployees_doesNotReStampRating` | Non-qualifying field change skips re-evaluation |
| `update_revenueChangesToGoodTier_setsGoodRating` | Revenue change triggers re-evaluation to Good |
| `update_employeesChangesToAtRiskTier_setsAtRiskRating` | Employees change triggers re-evaluation to At Risk |

**createAtRiskTasks -- Update Scenarios (4 tests)**

| Test Method | Scenario |
|-------------|----------|
| `update_ratingChangesToAtRisk_createsTask` | Good-to-At Risk transition creates one task with correct fields |
| `update_ratingStaysAtRisk_doesNotCreateDuplicateTask` | No transition = no task (prevents duplicate tasks) |
| `update_ratingChangesAwayFromAtRisk_doesNotCreateTask` | At Risk-to-Good transition does not create a task |
| `update_ratingFromAverageToAtRisk_createsTask` | Average-to-At Risk transition creates one task |

**Recursion Guard Scenarios (2 tests)**

| Test Method | Scenario |
|-------------|----------|
| `insert_recursionGuardBeforeActive_skipsEvaluation` | `hasRunBefore = true` prevents evaluation; fields stay null |
| `update_recursionGuardAfterActive_skipsTaskCreation` | `hasRunAfter = true` prevents task creation |

**Bulk Scenarios (2 tests)**

| Test Method | Scenario |
|-------------|----------|
| `bulkInsert_200Records_stampsCorrectRatings` | 200-record insert with mixed tiers; validates correct distribution (67 Good, 67 Average, 66 At Risk) |
| `bulkUpdate_halfTransitionToAtRisk_creates100Tasks` | 200-record update; 100 transition to At Risk; verifies exactly 100 tasks created |

### Test Design Notes

- All DML in tests uses `Database.insert/update(records, AccessLevel.SYSTEM_MODE)` because test users may lack FLS on newly deployed custom fields.
- The helper `resetGuards()` clears both `hasRunBefore` and `hasRunAfter` between operations within the same test transaction to simulate fresh trigger executions.
- SOQL assertions use `WITH USER_MODE` to enforce field-level security in queries.

---

## Security

### Sharing Model

- `AccountTriggerHandler` is declared `public with sharing`, respecting the running user's record-level sharing rules.
- All DML operations on Task records use `AccessLevel.USER_MODE`, enforcing FLS and CRUD for the running user.
- Task query in test assertions uses `WITH USER_MODE`.

### Required Permissions

To view and edit the health indicator fields, users must be assigned the `AccountHealth_Fields` permission set (or have equivalent field-level security configured through a profile).

| Action | Minimum Required Access |
|--------|------------------------|
| View Health Rating badge in LWC | Read on `Account.Health_Rating__c` and `Account.Health_Evaluated_Date__c` |
| Trigger auto-evaluation (insert/update Account) | Edit on Account; trigger runs in system context for field writes |
| Receive At Risk Tasks | Task owner; no special permissions needed |

---

## Notes and Considerations

### Known Limitations

1. **Error logging is debug-only:** `handleSaveResults` logs Task DML failures with `System.debug(LoggingLevel.ERROR, ...)`. In production, this relies on debug logs being active. A platform event or custom logging object should replace this for reliable error tracking.

2. **No LWC unit tests:** The `accountHealthIndicator` LWC does not have Jest unit tests. If Jest testing is added to the project, tests should cover the three badge color states, the loading state, the error state, and the null date fallback.

3. **Date formatting is locale-hardcoded:** The LWC formats `Health_Evaluated_Date__c` using `Intl.DateTimeFormat('en-US', ...)`. Multi-locale orgs should use a dynamic locale or a `lightning-formatted-date-time` base component instead.

4. **`Health_Rating__c` is not required:** The field defaults to null on records that existed before deployment and on records inserted without triggering the handler (e.g., when the recursion guard is already active in the same transaction).

5. **`syncRelatedRecords` and `enqueueAsyncWork` are stubs:** These pre-existing handler methods contain TODO comments and no live logic. They are part of the handler template pattern and do not affect health rating behavior.

### Future Enhancements

- Replace `System.debug` error logging in `handleSaveResults` with a Platform Event or custom `Error_Log__c` object.
- Add `lightning-formatted-date-time` to the LWC for multi-locale date rendering.
- Add a scheduled batch job to re-evaluate health ratings nightly for all open accounts (in case AnnualRevenue or NumberOfEmployees are updated via external data integration without triggering the Salesforce trigger).
- Consider adding a `Health_Rating_Changed_Date__c` field to track the most recent tier transition, enabling trend reporting.
- Add Jest tests for the `accountHealthIndicator` LWC component.

### Dependencies

| Dependency | Notes |
|------------|-------|
| `Account.AnnualRevenue` | Standard field; must be populated for accurate evaluation |
| `Account.NumberOfEmployees` | Standard field; must be populated for accurate evaluation |
| `Account.OwnerId` | Used as the Task owner on At Risk transitions |
| `Health_Rating__c` field | Must be deployed before `AccountTriggerHandler` can reference it |
| `Health_Evaluated_Date__c` field | Must be deployed before `AccountTriggerHandler` can reference it |

### Deployment Order

Admin metadata (custom fields and permission set) must be deployed before the Apex classes and trigger, because the handler references `Health_Rating__c` and `Health_Evaluated_Date__c` by API name. The LWC can be deployed in any order relative to the Apex code.

---

## Change History

| Date | Author | Change Description |
|------|--------|--------------------|
| 2026-02-21 | Documentation Agent | Initial creation |
