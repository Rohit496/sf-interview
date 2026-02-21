# Project Documentation Index

**Project:** Salesforce DX -- Interview Project
**API Version:** 65.0
**Package Directory:** `force-app/main/default`
**Last Updated:** 2026-02-21

---

## Feature Documents

| Document | Feature | Objects Affected | Components |
|----------|---------|-----------------|------------|
| [account-health-indicator.md](./account-health-indicator.md) | Account Health Indicator | Account, Task | 2 custom fields, 1 permission set, 1 trigger, 1 handler class, 1 test class, 1 LWC |
| [lead-follow-up-tracking.md](./lead-follow-up-tracking.md) | Lead Follow-Up Tracking | Lead | 5 custom fields, 1 permission set, 1 trigger, 1 handler class, 2 Apex classes, 2 test classes, 1 LWC |

---

## Complete Component Inventory

### Custom Fields

| Object | Field API Name | Type | Feature |
|--------|----------------|------|---------|
| `Account` | `Health_Rating__c` | Picklist (Good, Average, At Risk) | Account Health Indicator |
| `Account` | `Health_Evaluated_Date__c` | DateTime | Account Health Indicator |
| `Lead` | `Last_Contacted_Date__c` | Date | Lead Follow-Up Tracking |
| `Lead` | `Days_Since_Last_Contact__c` | Number (18,0) | Lead Follow-Up Tracking |
| `Lead` | `Is_Overdue__c` | Checkbox | Lead Follow-Up Tracking |
| `Lead` | `Primary__c` | Picklist (Yes, No) | Lead Management |
| `Lead` | `ProductInterest__c` | Picklist (GC1000, GC3000, GC5000 series) | Lead Management |

### Permission Sets

| API Name | Label | Grants Access To |
|----------|-------|-----------------|
| `AccountHealth_Fields` | AccountHealth Fields | `Account.Health_Rating__c`, `Account.Health_Evaluated_Date__c` |
| `LeadMgmt_Lead_FollowUp_Fields` | LeadMgmt Lead Follow-Up Fields | `Lead.Last_Contacted_Date__c`, `Lead.Days_Since_Last_Contact__c`, `Lead.Is_Overdue__c` |

### Apex Triggers

| Trigger | Object | Contexts | Handler |
|---------|--------|----------|---------|
| `AccountTrigger` | Account | before insert, before update, after insert, after update | `AccountTriggerHandler` |
| `LeadTrigger` | Lead | before insert, before update | `LeadTriggerHandler` |

### Apex Classes

| Class | Type | Feature |
|-------|------|---------|
| `AccountTriggerHandler` | Trigger Handler | Account Health Indicator |
| `AccountTriggerHandlerTest` | Test Class | Account Health Indicator |
| `LeadTriggerHandler` | Trigger Handler | Lead Follow-Up Tracking |
| `LeadTriggerHandlerTest` | Test Class | Lead Follow-Up Tracking |
| `OverdueLeadsController` | AuraEnabled Controller | Lead Follow-Up Tracking |
| `OverdueLeadsControllerTest` | Test Class | Lead Follow-Up Tracking |

### Lightning Web Components

| Component | Master Label | Supported Pages | Feature |
|-----------|--------------|-----------------|---------|
| `accountHealthIndicator` | Account Health Indicator | Account Record Page | Account Health Indicator |
| `overdueLeads` | Overdue Leads | Lead Record Page, App Page, Home Page | Lead Follow-Up Tracking |

---

## Architecture Overview

```
ACCOUNT HEALTH INDICATOR
========================

User/API                AccountTrigger                AccountTriggerHandler
  |                          |                                 |
  |-- insert/update -------->|-- beforeInsert/beforeUpdate --->|-- evaluateHealthRating()
  |                          |                                 |   Sets Health_Rating__c
  |                          |                                 |   Sets Health_Evaluated_Date__c
  |                          |                                 |
  |                          |-- afterUpdate ----------------->|-- createAtRiskTasks()
  |                          |                                 |   Creates Task (High priority,
  |                          |                                 |   due +3 days) on At Risk
  |                          |                                 |   transition
  |
  |-- view record page -----> accountHealthIndicator LWC
                              @wire getRecord
                              Renders colored badge + date


LEAD FOLLOW-UP TRACKING
=======================

User/API                LeadTrigger                   LeadTriggerHandler
  |                          |                                 |
  |-- insert/update -------->|-- beforeInsert/beforeUpdate --->|-- calculateContactMetrics()
  |                          |                                 |   Sets Days_Since_Last_Contact__c
  |                          |                                 |   Sets Is_Overdue__c (>= 7 days)
  |
  |-- view dashboard -------> overdueLeads LWC
                              @wire OverdueLeadsController.getOverdueLeads()
                              Renders clickable lead table
```

---

## Shared Conventions

| Convention | Detail |
|------------|--------|
| Trigger pattern | One trigger per object; all logic in a separate handler class |
| Recursion guard | Static Boolean flag(s) on handler class; `@TestVisible` for test resets |
| DML | `Database.insert/update` with `allOrNone=false` and `AccessLevel.USER_MODE` where DML is required |
| SOQL | `WITH USER_MODE` on all SOQL in handler/controller classes |
| FLS (LWC controllers) | `Security.stripInaccessible(AccessType.READABLE, ...)` post-query |
| Error handling (LWC) | `AuraHandledException` wrapped around all controller exceptions |
| Error handling (triggers) | `System.debug(LoggingLevel.ERROR, ...)` via `handleSaveResults` helper (see known limitations) |
| Sharing | All classes use `with sharing` |
| API version | 65.0 |

---

## Quick Reference: Assigning Permission Sets

| User Role | Assign These Permission Sets |
|-----------|------------------------------|
| Account Manager / Sales Manager | `AccountHealth_Fields` |
| Sales Representative (managing leads) | `LeadMgmt_Lead_FollowUp_Fields` |
| Both roles | Both permission sets |

---

## Known Project-Wide Limitations

1. **Trigger error logging uses System.debug only.** DML errors in `AccountTriggerHandler.handleSaveResults` are written to debug logs rather than a persistent logging object. This is invisible in production without active debug log configuration. A Platform Event or custom `Error_Log__c` object is the recommended replacement.

2. **Calculated lead fields do not auto-refresh over time.** `Days_Since_Last_Contact__c` and `Is_Overdue__c` are only recalculated when `Last_Contacted_Date__c` changes. Records become stale as days pass. A scheduled batch or scheduled flow is needed to keep values current.

3. **No LWC Jest tests.** Neither `accountHealthIndicator` nor `overdueLeads` have Jest unit tests. These should be added to the project's test suite.
