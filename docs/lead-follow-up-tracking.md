# Lead Follow-Up Tracking

**Date:** 2026-02-21
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

Lead follow-up tracking system -- custom fields on Lead to capture when a lead was last contacted, automatically calculate how many days have passed since that contact, flag the lead as overdue when 7 or more days have elapsed without contact, and surface overdue leads to the record owner via a Lightning Web Component dashboard.

### Business Objective

Sales representatives often lose track of leads that have gone cold. Without a visible staleness signal, follow-up activities are missed and conversion opportunities are lost. This feature automatically derives two calculated values (days since last contact and an overdue flag) from a single user-entered date field, requires no manual maintenance, and surfaces every overdue lead in a dedicated dashboard component so reps can prioritise their outreach immediately.

### Summary

The Lead Follow-Up Tracking feature adds three custom fields to the Lead object and a trigger-based calculation engine that derives `Days_Since_Last_Contact__c` and `Is_Overdue__c` from the user-populated `Last_Contacted_Date__c` field. A companion Lightning Web Component (`overdueLeads`) queries the running user's overdue, unconverted leads via a cacheable Apex controller and renders them in a navigable table that can be placed on any Lightning page.

---

## Components Created

### Admin Components (Declarative)

#### Custom Fields

| Object | Field API Name | Type | Required | Description |
|--------|----------------|------|----------|-------------|
| `Lead` | `Last_Contacted_Date__c` | Date | No | The date when this lead was last contacted. Populated by the user. Drives all derived calculations. |
| `Lead` | `Days_Since_Last_Contact__c` | Number (18,0) | No | Automatically calculated. Number of days between `Last_Contacted_Date__c` and today. Set to null when `Last_Contacted_Date__c` is null. |
| `Lead` | `Is_Overdue__c` | Checkbox | No | Automatically calculated. `true` when `Days_Since_Last_Contact__c >= 7`. Defaults to `false`. |

**Additional Lead Fields (pre-existing, modified or confirmed in scope)**

| Object | Field API Name | Type | Description |
|--------|----------------|------|-------------|
| `Lead` | `Primary__c` | Picklist | Indicates whether the lead is the primary contact. Values: Yes, No. |
| `Lead` | `ProductInterest__c` | Picklist | Product line the lead is interested in. Values: GC1000 series, GC3000 series, GC5000 series. |

#### Permission Sets

| Permission Set API Name | Label | Description |
|-------------------------|-------|-------------|
| `LeadMgmt_Lead_FollowUp_Fields` | LeadMgmt Lead Follow-Up Fields | Grants Read and Edit access to `Last_Contacted_Date__c`, `Days_Since_Last_Contact__c`, and `Is_Overdue__c`. Assign to any user who needs to view or manage overdue lead tracking. |

**Field Permissions Granted**

| Field | Readable | Editable |
|-------|----------|----------|
| `Lead.Last_Contacted_Date__c` | Yes | Yes |
| `Lead.Days_Since_Last_Contact__c` | Yes | Yes |
| `Lead.Is_Overdue__c` | Yes | Yes |

---

### Development Components (Code)

#### Apex Classes

| Class Name | API Version | Sharing | Description |
|------------|-------------|---------|-------------|
| `LeadTriggerHandler` | 65.0 | `with sharing` | Trigger handler for the Lead object. Calculates `Days_Since_Last_Contact__c` and `Is_Overdue__c` in before insert and before update contexts. Uses a single `hasRun` recursion guard. |
| `LeadTriggerHandlerTest` | 65.0 | N/A (`@IsTest`) | Test class with 10 test methods covering insert, update, null handling, future dates, recursion guards, and bulk scenarios. |
| `OverdueLeadsController` | 65.0 | `with sharing` | Cacheable Apex controller for the `overdueLeads` LWC. Queries overdue, unconverted leads owned by the running user and strips inaccessible fields via `Security.stripInaccessible`. |
| `OverdueLeadsControllerTest` | 65.0 | N/A (`@IsTest`) | Test class with 4 test methods covering the happy path, empty state, ordering, and exception handling. |

#### Apex Triggers

| Trigger Name | Object | Events | Description |
|--------------|--------|--------|-------------|
| `LeadTrigger` | `Lead` | before insert, before update | Single entry-point trigger. Delegates all logic to `LeadTriggerHandler`. |

#### Lightning Web Components

| Component Name | Master Label | Targets | Description |
|----------------|--------------|---------|-------------|
| `overdueLeads` | Overdue Leads | `lightning__RecordPage` (Lead), `lightning__AppPage`, `lightning__HomePage` | Renders a striped SLDS table of the running user's overdue, unconverted leads. Lead names are clickable navigation links. Handles loading, error, and empty states. |

**LWC Files -- overdueLeads**

| File | Purpose |
|------|---------|
| `overdueLeads.html` | Template with `lightning-card`, loading spinner, error state with icon, data table with navigation links, and empty/caught-up state |
| `overdueLeads.js` | Controller using `NavigationMixin`. `@wire` calls `getOverdueLeads`. Maps each lead to include a `recordUrl`. Computed getters for `hasLeads`, `hasNoLeads`, `hasError`. `handleNavigate` uses `NavigationMixin.Navigate` for SPA navigation. |
| `overdueLeads.css` | Minimal styles: block display on `:host`, brand-accessible link color with underline on hover |
| `overdueLeads.js-meta.xml` | Bundle metadata. Exposed to App Builder for Lead record pages, App Pages, and Home Pages. |

---

## Contact Metrics Calculation Logic

### Overdue Threshold

A lead is considered overdue when `Days_Since_Last_Contact__c >= 7`.

| Constant | Value | Location |
|----------|-------|----------|
| `OVERDUE_THRESHOLD_DAYS` | 7 | `LeadTriggerHandler` private static final |

### Calculation Rules

| Input State | `Days_Since_Last_Contact__c` | `Is_Overdue__c` |
|-------------|------------------------------|-----------------|
| `Last_Contacted_Date__c` = null | null | false |
| `Last_Contacted_Date__c` = today | 0 | false |
| `Last_Contacted_Date__c` = past date (< 7 days ago) | Positive integer < 7 | false |
| `Last_Contacted_Date__c` = past date (>= 7 days ago) | Positive integer >= 7 | true |
| `Last_Contacted_Date__c` = future date | Absolute number of days from today | false (days < 7 in near future) |

**Future date handling:** The handler calls `lead.Last_Contacted_Date__c.daysBetween(today)`, which returns a negative value for future dates. The handler converts negative values to their absolute equivalent (`daysSince = daysSince * -1`), so future-dated contacts do not produce negative day counts.

### When Calculation Fires

| Context | Behaviour |
|---------|-----------|
| **Before Insert** | Always calculates for every new Lead that has `Last_Contacted_Date__c` set. Leads without the date get null/false. |
| **Before Update** | Only recalculates when `Last_Contacted_Date__c` has changed (including being cleared to null). Updates to other fields skip recalculation entirely. |

### OverdueLeadsController Query Logic

The `getOverdueLeads` method returns leads matching ALL of:
- `Is_Overdue__c = true`
- `OwnerId = running user's Id` (own records only)
- `IsConverted = false` (open leads only)

Results are ordered by `Days_Since_Last_Contact__c DESC` (most-overdue first).

FLS is enforced post-query via `Security.stripInaccessible(AccessType.READABLE, leads)`, which silently removes any field the running user cannot read rather than throwing an exception.

---

## Data Flow

### How It Works

```
1. User enters or updates Last_Contacted_Date__c on a Lead record.
2. LeadTrigger fires (before insert or before update).
3. LeadTriggerHandler.beforeInsert / beforeUpdate is called.
4. Recursion guard (hasRun) is checked -- returns early if already fired.
5. calculateContactMetrics() iterates each Lead:
   a. On update: skips record if Last_Contacted_Date__c did not change.
   b. If Last_Contacted_Date__c is null: resets Days_Since_Last_Contact__c to null
      and Is_Overdue__c to false.
   c. Otherwise: calculates absolute daysBetween(today), sets
      Days_Since_Last_Contact__c and Is_Overdue__c accordingly.
6. Record is saved with updated field values (no extra DML needed -- before context).
7. User navigates to their Overdue Leads dashboard (overdueLeads LWC).
8. @wire calls OverdueLeadsController.getOverdueLeads (cacheable).
9. Apex queries overdue, unconverted leads owned by the running user.
10. stripInaccessible removes fields the user cannot read.
11. LWC renders the lead table with clickable name links.
12. User clicks a lead name -- NavigationMixin routes to the Lead record page.
```

### Architecture Diagram

```
+---------------------------+       +---------------------------+       +---------------------------+
|   User edits              |       |   Lead Record (DML)       |       |   LeadTrigger             |
|   Last_Contacted_Date__c  |------>|   Lead Object             |------>|   (before insert/update)  |
+---------------------------+       +---------------------------+       +-----------+---------------+
                                                                                    |
                                                                                    v
                                                                    +---------------+---------------+
                                                                    |   LeadTriggerHandler          |
                                                                    |   .beforeInsert()             |
                                                                    |   .beforeUpdate()             |
                                                                    |         |                     |
                                                                    |         v                     |
                                                                    |   calculateContactMetrics()   |
                                                                    |   - Changed? (update check)  |
                                                                    |   - Null? Reset both fields  |
                                                                    |   - Days = abs(daysBetween)  |
                                                                    |   - Overdue = days >= 7      |
                                                                    +---------------+---------------+
                                                                                    |
                                                                                    v
                                                              +-------------------------------------------+
                                                              |   Lead saved with                         |
                                                              |   Days_Since_Last_Contact__c (Number)     |
                                                              |   Is_Overdue__c (Checkbox)                |
                                                              +-------------------------------------------+
                                                                                    |
                                    +-----------------------------------------------+
                                    |
                                    v
+---------------------------+       +---------------------------+       +---------------------------+
|   overdueLeads LWC        |       |   OverdueLeadsController  |       |   Lead SOQL               |
|   @wire getOverdueLeads   |<------|   getOverdueLeads()       |<------|   Is_Overdue__c = true    |
|   - Renders table         |       |   (cacheable, USER_MODE)  |       |   OwnerId = currentUser   |
|   - NavigationMixin links |       |   - stripInaccessible     |       |   IsConverted = false     |
+---------------------------+       +---------------------------+       |   ORDER BY Days DESC      |
                                                                        +---------------------------+
```

---

## File Locations

| Component | Path |
|-----------|------|
| Last_Contacted_Date__c field | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Lead/fields/Last_Contacted_Date__c.field-meta.xml` |
| Days_Since_Last_Contact__c field | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Lead/fields/Days_Since_Last_Contact__c.field-meta.xml` |
| Is_Overdue__c field | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Lead/fields/Is_Overdue__c.field-meta.xml` |
| Primary__c field | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Lead/fields/Primary__c.field-meta.xml` |
| ProductInterest__c field | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Lead/fields/ProductInterest__c.field-meta.xml` |
| Permission Set | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/permissionsets/LeadMgmt_Lead_FollowUp_Fields.permissionset-meta.xml` |
| Trigger | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/triggers/LeadTrigger.trigger` |
| Trigger metadata | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/triggers/LeadTrigger.trigger-meta.xml` |
| LeadTriggerHandler class | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/LeadTriggerHandler.cls` |
| LeadTriggerHandler metadata | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/LeadTriggerHandler.cls-meta.xml` |
| LeadTriggerHandlerTest class | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/LeadTriggerHandlerTest.cls` |
| LeadTriggerHandlerTest metadata | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/LeadTriggerHandlerTest.cls-meta.xml` |
| OverdueLeadsController class | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/OverdueLeadsController.cls` |
| OverdueLeadsController metadata | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/OverdueLeadsController.cls-meta.xml` |
| OverdueLeadsControllerTest class | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/OverdueLeadsControllerTest.cls` |
| OverdueLeadsControllerTest metadata | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/OverdueLeadsControllerTest.cls-meta.xml` |
| LWC HTML template | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/lwc/overdueLeads/overdueLeads.html` |
| LWC JavaScript controller | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/lwc/overdueLeads/overdueLeads.js` |
| LWC CSS styles | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/lwc/overdueLeads/overdueLeads.css` |
| LWC bundle metadata | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/lwc/overdueLeads/overdueLeads.js-meta.xml` |

---

## Configuration Details

### LeadTrigger -- Context Routing

| Trigger Context | Handler Method |
|-----------------|----------------|
| before insert | `handler.beforeInsert(Trigger.new)` |
| before update | `handler.beforeUpdate(Trigger.new, Trigger.oldMap)` |

The trigger fires on before insert and before update only. No after-context events are subscribed because all field calculations happen in-memory before the record is written to the database, requiring no additional DML.

### LeadTriggerHandler -- Recursion Guard

| Flag | Type | Annotation | Purpose |
|------|------|------------|---------|
| `hasRun` | `private static Boolean` | `@TestVisible` | Single guard for both before insert and before update contexts. Set to `true` after first handler invocation per transaction. Reset in tests with `LeadTriggerHandler.hasRun = false`. |

Unlike `AccountTriggerHandler`, the Lead handler uses a single combined guard (not separate before/after flags) because it only operates in before-trigger contexts.

### OverdueLeadsController -- Key Implementation Notes

| Detail | Value |
|--------|-------|
| Method annotation | `@AuraEnabled(cacheable=true)` |
| SOQL access level | `WITH USER_MODE` |
| FLS enforcement | `Security.stripInaccessible(AccessType.READABLE, leads)` |
| Error handling | All exceptions caught and re-thrown as `AuraHandledException` |
| Test hook | `@TestVisible private static Boolean forceException = false` |

The `forceException` flag allows test code to simulate a query failure without needing a genuine error condition, enabling full coverage of the exception branch.

### overdueLeads LWC -- Component Details

**Template State Machine**

| State | Condition | What Renders |
|-------|-----------|-------------|
| Loading | `isLoading = true` | `lightning-spinner` |
| Error | `hasError = true` | Error icon + `errorMessage` text |
| Has leads | `hasLeads = true` | SLDS striped bordered table |
| Empty | All others | "No overdue leads found. You are all caught up." message |

**Computed Getters**

| Getter | Returns |
|--------|---------|
| `hasLeads` | `true` when `leads.length > 0` |
| `hasNoLeads` | `true` when not loading, no error, and no leads |
| `hasError` | `true` when `errorMessage` is set |

**Navigation**

Each lead name in the table is rendered as an `<a>` tag with a `data-id` attribute. The `handleNavigate` event handler intercepts clicks, prevents the default browser navigation, and uses `NavigationMixin.Navigate` to route to the Lead record page within the Lightning SPA context.

**Target Configuration**

| Target | Restriction |
|--------|-------------|
| `lightning__RecordPage` | Lead object only |
| `lightning__AppPage` | No restriction |
| `lightning__HomePage` | No restriction |

---

## Testing

### Test Coverage Summary

| Class | Test Methods | Key Scenarios Covered |
|-------|--------------|-----------------------|
| `LeadTriggerHandlerTest` | 10 | Insert (today, past, null, future dates), Update (recalculate, clear date, unrelated field), Recursion guards (insert and update), Bulk 200-record insert |
| `OverdueLeadsControllerTest` | 4 | Returns only overdue leads, descending order, empty list, AuraHandledException on failure |

### LeadTriggerHandlerTest -- Method Inventory

**Insert Scenarios (4 tests)**

| Test Method | Scenario |
|-------------|----------|
| `insertWithTodayDate_shouldNotBeOverdue` | `Last_Contacted_Date__c` = today produces 0 days, `Is_Overdue__c` = false |
| `insertWithTenDaysAgo_shouldBeOverdue` | 10 days ago produces 10 days, `Is_Overdue__c` = true |
| `insertWithNullDate_shouldHaveNullMetrics` | Null date leaves both fields at null/false |
| `insertWithFutureDate_shouldCalculatePositiveDays` | Future date produces positive absolute day count |

**Update Scenarios (3 tests)**

| Test Method | Scenario |
|-------------|----------|
| `updateLastContactedDate_shouldRecalculate` | Changing date from today to 10 days ago recalculates to overdue |
| `clearLastContactedDate_shouldResetMetrics` | Clearing date resets `Days_Since_Last_Contact__c` to null and `Is_Overdue__c` to false |
| `updateUnrelatedField_shouldNotRecalculate` | Updating `Company` does not trigger recalculation; metrics unchanged |

**Recursion Guard Scenarios (2 tests)**

| Test Method | Scenario |
|-------------|----------|
| `beforeInsert_recursionGuard_shouldSkipWhenHasRunIsTrue` | `hasRun = true` before insert -- handler skips; fields remain null |
| `beforeUpdate_recursionGuard_shouldSkipWhenHasRunIsTrue` | `hasRun = true` before update -- handler skips; fields remain null |

**Bulk Scenario (1 test)**

| Test Method | Scenario |
|-------------|----------|
| `bulkInsert_shouldHandleTwoHundredRecords` | 200 leads with alternating today/10-days-ago dates; verifies exactly 100 overdue and 100 not overdue |

### OverdueLeadsControllerTest -- Method Inventory

**Setup:** `@TestSetup` creates 5 overdue leads (contacted 10 days ago), 3 current leads (contacted today), and 1 no-date lead, all owned by the running user.

| Test Method | Scenario |
|-------------|----------|
| `getOverdueLeads_shouldReturnOnlyOverdueLeads` | Returns exactly 5 overdue leads; all names start with "OverdueLead" |
| `getOverdueLeads_shouldBeOrderedDescending` | Verifies descending order by `Days_Since_Last_Contact__c` |
| `getOverdueLeads_shouldReturnEmptyWhenNoneOverdue` | After deleting overdue leads, returns empty list |
| `getOverdueLeads_shouldThrowAuraHandledException_whenQueryFails` | `forceException = true` causes `AuraHandledException` to be thrown |

### Test Design Notes

- All test DML uses `AccessLevel.SYSTEM_MODE` because test users may lack FLS on newly deployed custom fields. The trigger handler runs in before-trigger context (system mode), so this accurately reflects production behaviour.
- `LeadTriggerHandler.hasRun = false` must be called between insert and update operations in the same test transaction to simulate a fresh trigger execution.
- SOQL in test assertions uses `WITH USER_MODE` to enforce field-level security in queries.
- The ordering test uses `getPopulatedFieldsAsMap().containsKey(...)` before reading `Days_Since_Last_Contact__c` to handle the case where `Security.stripInaccessible` has removed the field for the test user.

---

## Security

### Sharing Model

- `LeadTriggerHandler` is declared `public with sharing`, respecting the running user's record-level sharing rules.
- `OverdueLeadsController` is declared `public with sharing`, further restricting the SOQL result set to records the running user has access to.
- The `getOverdueLeads` SOQL uses `WITH USER_MODE` (field- and object-level security enforced at query time).
- `Security.stripInaccessible(AccessType.READABLE, leads)` provides a secondary FLS enforcement layer, silently removing any field the user cannot read.

### Required Permissions

To use the Lead Follow-Up Tracking features, users must be assigned the `LeadMgmt_Lead_FollowUp_Fields` permission set (or equivalent profile-level FLS access).

| Action | Minimum Required Access |
|--------|------------------------|
| View `Days_Since_Last_Contact__c` and `Is_Overdue__c` | Read on all three custom Lead fields |
| Enter or edit `Last_Contacted_Date__c` | Edit on `Lead.Last_Contacted_Date__c` |
| View the `overdueLeads` LWC table | Read on `Lead.Days_Since_Last_Contact__c` and `Lead.Is_Overdue__c` |
| Navigate to a Lead from the LWC | Standard Lead Read access |

---

## Notes and Considerations

### Known Limitations

1. **No error logging for trigger failures:** `LeadTriggerHandler` does not perform DML, so there are no DML failures to log. However, if a future enhancement adds DML (e.g., creating follow-up Tasks from the trigger), the same `System.debug`-only pattern from `AccountTriggerHandler` should be avoided in favour of a proper logging framework.

2. **`Days_Since_Last_Contact__c` is not a formula field:** The value is written by the trigger handler and will become stale if the trigger does not fire (e.g., if a data load bypasses triggers, or if `Last_Contacted_Date__c` is not changed during a bulk update). It represents the days since last contact at the time of the last trigger execution, not necessarily at the moment of viewing.

3. **`Is_Overdue__c` does not auto-update with the passage of time:** Both fields are only recalculated when `Last_Contacted_Date__c` changes. An account last contacted 6 days ago will show as not overdue, but will remain not overdue the next day unless the record is saved again. A nightly batch or scheduled flow would be needed to keep these values current on all records.

4. **`overdueLeads` LWC has no Jest tests:** The component has no Jest unit tests. Tests should cover the loading state, error state, empty state, data rendering, and the `handleNavigate` click handler.

5. **Future dates on `Last_Contacted_Date__c` are accepted without validation:** The handler stores the absolute day count for future dates without raising an error. A validation rule on the field could prevent future dates if they are not a valid use case.

6. **`Primary__c` and `ProductInterest__c` fields are admin-only:** These two Lead picklist fields are deployed as metadata but are not referenced by the trigger or LWC. They are standalone admin fields and require no special trigger logic.

### Future Enhancements

- Add a nightly scheduled batch or Record-Triggered Flow (on schedule path) to recalculate `Days_Since_Last_Contact__c` and `Is_Overdue__c` for all leads where `Last_Contacted_Date__c` is populated, keeping values current without requiring a record save.
- Add a validation rule on `Last_Contacted_Date__c` to reject future dates if that is not an intended use case.
- Add Jest tests for the `overdueLeads` LWC.
- Consider making `OVERDUE_THRESHOLD_DAYS` configurable via Custom Metadata Types so the threshold can be adjusted per org without a code deployment.
- Add an `OpenLeadFollowUpBatch` (already started in this project per commit `a012a79`) to create Tasks for stale open leads on a scheduled basis.

### Dependencies

| Dependency | Notes |
|------------|-------|
| `Lead.Last_Contacted_Date__c` | Must be deployed before `LeadTriggerHandler` references it |
| `Lead.Days_Since_Last_Contact__c` | Must be deployed before `LeadTriggerHandler` references it |
| `Lead.Is_Overdue__c` | Must be deployed before `LeadTriggerHandler` references it |
| `OverdueLeadsController` | Must be deployed before the `overdueLeads` LWC is used |
| `LeadTriggerHandler` | Must be deployed before `LeadTrigger` can compile |

### Deployment Order

1. Deploy custom Lead fields (`Last_Contacted_Date__c`, `Days_Since_Last_Contact__c`, `Is_Overdue__c`, `Primary__c`, `ProductInterest__c`) and the permission set -- these must exist before Apex references them.
2. Deploy `LeadTriggerHandler`, `OverdueLeadsController`, and their test classes.
3. Deploy `LeadTrigger`.
4. Deploy the `overdueLeads` LWC.

---

## Change History

| Date | Author | Change Description |
|------|--------|--------------------|
| 2026-02-21 | Documentation Agent | Initial creation |
