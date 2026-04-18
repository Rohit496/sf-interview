# Project Documentation Index

**Project:** Salesforce DX -- Interview Project
**API Version:** 65.0
**Package Directory:** `force-app/main/default`
**Last Updated:** 2026-03-14

---

## Feature Documents

| Document                                                                       | Feature                                  | Objects Affected               | Components                                                                                           |
| ------------------------------------------------------------------------------ | ---------------------------------------- | ------------------------------ | ---------------------------------------------------------------------------------------------------- |
| [account-health-indicator.md](./account-health-indicator.md)                   | Account Health Indicator                 | Account, Task                  | 2 custom fields, 1 permission set, 1 trigger, 1 handler class, 1 test class, 1 LWC                   |
| [lead-follow-up-tracking.md](./lead-follow-up-tracking.md)                     | Lead Follow-Up Tracking                  | Lead                           | 5 custom fields, 1 permission set, 1 trigger, 1 handler class, 2 Apex classes, 2 test classes, 1 LWC |
| [duplicate-account-name-prevention.md](./duplicate-account-name-prevention.md) | Duplicate Account Name Prevention        | Account                        | No new metadata; 1 handler class modified, 1 test class modified                                     |
| [case-duplicate-prevention.md](./case-duplicate-prevention.md)                 | Case Duplicate Prevention                | Case                           | 1 trigger, 1 handler class, 1 test class                                                             |
| [case-lookup-agent.md](./case-lookup-agent.md)                                 | Case Lookup Agent                        | Case (read-only)               | 1 Apex invocable action, 1 test class, 1 Agentforce agent bundle                                     |
| [lwc-error-handling-framework.md](./lwc-error-handling-framework.md)           | LWC Error Handling Framework             | Error_Log\_\_c (new)           | 1 custom object, 6 custom fields, 1 Apex service class, 1 test class, 2 LWC components               |
| [tescribe-library.md](./tescribe-library.md)                                   | Tescribe Test Data Library               | Tescribe_Template\_\_mdt (new) | 1 custom metadata type, 4 custom fields, 1 Apex utility class, 1 permission set                      |
| [apex-callout-jsonplaceholder.md](./apex-callout-jsonplaceholder.md)           | Apex HTTP Callout -- JSONPlaceholder API | None (no Salesforce objects)   | 1 remote site setting, 2 Apex classes, 2 test classes                                                |
| [callout-service-retry-pattern.md](./callout-service-retry-pattern.md)         | Callout Service -- Retry Pattern         | None (no Salesforce objects)   | 1 Apex utility class, 1 test class                                                                   |

---

## Complete Component Inventory

### Custom Metadata Types

| API Name                 | Label             | Feature                    |
| ------------------------ | ----------------- | -------------------------- |
| `Tescribe_Template__mdt` | Tescribe Template | Tescribe Test Data Library |

### Custom Fields

| Object                   | Field API Name               | Type                                          | Feature                      |
| ------------------------ | ---------------------------- | --------------------------------------------- | ---------------------------- |
| `Tescribe_Template__mdt` | `Object_API_Name__c`         | Text (100)                                    | Tescribe Test Data Library   |
| `Tescribe_Template__mdt` | `JSON_Data__c`               | Long Text Area (32,768)                       | Tescribe Test Data Library   |
| `Tescribe_Template__mdt` | `Is_Active__c`               | Checkbox                                      | Tescribe Test Data Library   |
| `Tescribe_Template__mdt` | `Description__c`             | Long Text Area (2,000)                        | Tescribe Test Data Library   |
| `Account`                | `Health_Rating__c`           | Picklist (Good, Average, At Risk)             | Account Health Indicator     |
| `Account`                | `Health_Evaluated_Date__c`   | DateTime                                      | Account Health Indicator     |
| `Lead`                   | `Last_Contacted_Date__c`     | Date                                          | Lead Follow-Up Tracking      |
| `Lead`                   | `Days_Since_Last_Contact__c` | Number (18,0)                                 | Lead Follow-Up Tracking      |
| `Lead`                   | `Is_Overdue__c`              | Checkbox                                      | Lead Follow-Up Tracking      |
| `Lead`                   | `Primary__c`                 | Picklist (Yes, No)                            | Lead Management              |
| `Lead`                   | `ProductInterest__c`         | Picklist (GC1000, GC3000, GC5000 series)      | Lead Management              |
| `Error_Log__c`           | `Error_Type__c`              | Picklist (Apex, Network, Validation, Unknown) | LWC Error Handling Framework |
| `Error_Log__c`           | `Error_Message__c`           | Long Text Area (32,768)                       | LWC Error Handling Framework |
| `Error_Log__c`           | `Stack_Trace__c`             | Long Text Area (32,768)                       | LWC Error Handling Framework |
| `Error_Log__c`           | `Component_Name__c`          | Text (255)                                    | LWC Error Handling Framework |
| `Error_Log__c`           | `User__c`                    | Lookup (User)                                 | LWC Error Handling Framework |
| `Error_Log__c`           | `Occurred_At__c`             | DateTime                                      | LWC Error Handling Framework |

### Permission Sets

| API Name                        | Label                          | Grants Access To                                                                       |
| ------------------------------- | ------------------------------ | -------------------------------------------------------------------------------------- |
| `AccountHealth_Fields`          | AccountHealth Fields           | `Account.Health_Rating__c`, `Account.Health_Evaluated_Date__c`                         |
| `LeadMgmt_Lead_FollowUp_Fields` | LeadMgmt Lead Follow-Up Fields | `Lead.Last_Contacted_Date__c`, `Lead.Days_Since_Last_Contact__c`, `Lead.Is_Overdue__c` |
| `Tescribe_Access`               | Tescribe Access                | `Tescribe` class; `Tescribe_Template__mdt` (read + all fields)                         |

### Apex Triggers

| Trigger          | Object  | Contexts                                                 | Handler                 |
| ---------------- | ------- | -------------------------------------------------------- | ----------------------- |
| `AccountTrigger` | Account | before insert, before update, after insert, after update | `AccountTriggerHandler` |
| `LeadTrigger`    | Lead    | before insert, before update                             | `LeadTriggerHandler`    |
| `CaseTrigger`    | Case    | before insert                                            | `CaseTriggerHandler`    |

### Apex Classes

| Class                        | Type                                  | Feature                                                     |
| ---------------------------- | ------------------------------------- | ----------------------------------------------------------- |
| `AccountTriggerHandler`      | Trigger Handler                       | Account Health Indicator, Duplicate Account Name Prevention |
| `AccountTriggerHandlerTest`  | Test Class                            | Account Health Indicator, Duplicate Account Name Prevention |
| `LeadTriggerHandler`         | Trigger Handler                       | Lead Follow-Up Tracking                                     |
| `LeadTriggerHandlerTest`     | Test Class                            | Lead Follow-Up Tracking                                     |
| `OverdueLeadsController`     | AuraEnabled Controller                | Lead Follow-Up Tracking                                     |
| `OverdueLeadsControllerTest` | Test Class                            | Lead Follow-Up Tracking                                     |
| `CaseTriggerHandler`         | Trigger Handler                       | Case Duplicate Prevention                                   |
| `CaseTriggerHandlerTest`     | Test Class                            | Case Duplicate Prevention                                   |
| `CaseLookupAction`           | Invocable Action                      | Case Lookup Agent                                           |
| `CaseLookupActionTest`       | Test Class                            | Case Lookup Agent                                           |
| `ErrorLogService`            | AuraEnabled Service                   | LWC Error Handling Framework                                |
| `ErrorLogServiceTest`        | Test Class                            | LWC Error Handling Framework                                |
| `Tescribe`                   | Test Utility (without sharing)        | Tescribe Test Data Library                                  |
| `PostWrapper`                | Response Model (with sharing)         | Apex HTTP Callout -- JSONPlaceholder API                    |
| `JsonPlaceholderService`     | HTTP Callout Service (with sharing)   | Apex HTTP Callout -- JSONPlaceholder API                    |
| `JsonPlaceholderServiceTest` | Test Class                            | Apex HTTP Callout -- JSONPlaceholder API                    |
| `PostWrapperTest`            | Test Class                            | Apex HTTP Callout -- JSONPlaceholder API                    |
| `CalloutService`             | HTTP Callout Utility (`with sharing`) | Callout Service -- Retry Pattern                            |
| `CalloutServiceTest`         | Test Class                            | Callout Service -- Retry Pattern                            |

### Agentforce Agent Bundles

| Bundle            | Label             | Target               | Feature           |
| ----------------- | ----------------- | -------------------- | ----------------- |
| `CaseLookupAgent` | Case Lookup Agent | `CaseLookupAgent.v6` | Case Lookup Agent |

### Lightning Web Components

| Component                | Master Label                        | Supported Pages                       | Feature                      |
| ------------------------ | ----------------------------------- | ------------------------------------- | ---------------------------- |
| `accountHealthIndicator` | Account Health Indicator            | Account Record Page                   | Account Health Indicator     |
| `overdueLeads`           | Overdue Leads                       | Lead Record Page, App Page, Home Page | Lead Follow-Up Tracking      |
| `errorUtils`             | Error Utils (service module, no UI) | — (service only, not exposed)         | LWC Error Handling Framework |
| `errorPanel`             | Error Panel                         | Record Page, App Page, Home Page      | LWC Error Handling Framework |

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


DUPLICATE ACCOUNT NAME PREVENTION
==================================

User/API                AccountTrigger                AccountTriggerHandler
  |                          |                                 |
  |-- insert/update -------->|-- beforeInsert/beforeUpdate --->|-- preventDuplicateAccounts()
                                                               |   Case-insensitive SOQL check
                                                               |   addError() blocks duplicate


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


CASE DUPLICATE PREVENTION
=========================

User/API                CaseTrigger                   CaseTriggerHandler
  |                          |                                 |
  |-- insert --------------->|-- beforeInsert (pass 1) ------->|-- within-batch key detection
  |                          |                                 |   addError() on 2nd+ same-key records
  |                          |                                 |
  |                          |-- beforeInsert (pass 2) ------->|-- SOQL: open Cases (IsClosed=false)
  |                          |                                 |   WITH USER_MODE
  |                          |                                 |   addError() on DB-level duplicates
  |                          |
  |  Composite key: Subject.toLowerCase() + '|' + AccountId + '|' + ContactId + '|' + Origin


LWC ERROR HANDLING FRAMEWORK
============================

Consuming LWC (any)
  |
  |-- catch(error) --> c/errorUtils (errorUtils.js service module)
  |                        |
  |                        |-- reduceErrors()   --> string[]  (normalize any error shape)
  |                        |-- normalizeError() --> string    (join with '; ')
  |                        |-- classifyError()  --> Apex|Network|Validation|Unknown
  |                        |-- logErrorToServer({ error, componentName })
  |                                  |
  |                                  | imperative @AuraEnabled Apex (async, fire-and-forget)
  |                                  v
  |                        ErrorLogService.logError()
  |                                  |
  |                                  | Database.insert (allOrNone=false, USER_MODE)
  |                                  v
  |                        Error_Log__c  (ERR-00001, ERR-00002, ...)
  |
  |-- <c-error-panel errors={error}>  -->  errorPanel LWC
                              |
                              |-- type='inline': SLDS illustration + error message list
                              |-- type='banner': SLDS alert banner (role="alert")
                              |-- no errors   : renders nothing


CASE LOOKUP AGENT
=================

User (chat)           CaseLookupAgent (.agent)          CaseLookupAction.cls        Case Object
    |                         |                                   |                      |
    |-- "00001234" ---------->| start_agent: greet + ask         |                      |
    |                         | topic_selector → case_lookup     |                      |
    |                         | set_case_number (utils)          |                      |
    |                         | get_case_details action -------->|                      |
    |                         |                                   | SOQL WHERE           |
    |                         |                                   | CaseNumber = :num -->|
    |                         |                                   |<-- Case record ----  |
    |                         |<-- CaseResult (10 fields) ------  |                      |
    |                         |                                   |                      |
    |                         | if caseFound = true:              |                      |
    |<-- formatted details ---| display subject/status/priority   |                      |
    |                         |   /owner/account/dates/desc       |                      |
    |                         |                                   |                      |
    |                         | if caseFound = false (< 3 tries): |                      |
    |<-- retry prompt --------| ask user to re-enter number       |                      |
    |                         |                                   |                      |
    |                         | if attempts >= 3:                 |                      |
    |<-- escalation ----------| topic escalation: offer options   |                      |
```

---

## Shared Conventions

| Convention                | Detail                                                                                            |
| ------------------------- | ------------------------------------------------------------------------------------------------- |
| Trigger pattern           | One trigger per object; all logic in a separate handler class                                     |
| Recursion guard           | Static Boolean flag(s) on handler class; `@TestVisible` for test resets                           |
| DML                       | `Database.insert/update` with `allOrNone=false` and `AccessLevel.USER_MODE` where DML is required |
| SOQL                      | `WITH USER_MODE` on all SOQL in handler/controller classes                                        |
| FLS (LWC controllers)     | `Security.stripInaccessible(AccessType.READABLE, ...)` post-query                                 |
| Error handling (LWC)      | `AuraHandledException` wrapped around all controller exceptions                                   |
| Error handling (triggers) | `System.debug(LoggingLevel.ERROR, ...)` via `handleSaveResults` helper (see known limitations)    |
| Sharing                   | All classes use `with sharing`                                                                    |
| API version               | 65.0                                                                                              |

---

## Quick Reference: Assigning Permission Sets

| User Role                             | Assign These Permission Sets    |
| ------------------------------------- | ------------------------------- |
| Account Manager / Sales Manager       | `AccountHealth_Fields`          |
| Sales Representative (managing leads) | `LeadMgmt_Lead_FollowUp_Fields` |
| Both roles                            | Both permission sets            |

---

## Known Project-Wide Limitations

1. **Trigger error logging uses System.debug only.** DML errors in `AccountTriggerHandler.handleSaveResults` are written to debug logs rather than a persistent logging object. This is invisible in production without active debug log configuration. A Platform Event or custom `Error_Log__c` object is the recommended replacement.

2. **Calculated lead fields do not auto-refresh over time.** `Days_Since_Last_Contact__c` and `Is_Overdue__c` are only recalculated when `Last_Contacted_Date__c` changes. Records become stale as days pass. A scheduled batch or scheduled flow is needed to keep values current.

3. **No LWC Jest tests.** Neither `accountHealthIndicator` nor `overdueLeads` have Jest unit tests. These should be added to the project's test suite.

4. **Duplicate Account Name Prevention has a race condition risk.** The `preventDuplicateAccounts` check uses a before-trigger SOQL query, which cannot see uncommitted rows from concurrent transactions. Two simultaneous inserts with the same name can both pass the check and create a duplicate pair. A database-level Unique constraint is the only complete solution.

5. **Case Duplicate Prevention is insert-only.** `CaseTriggerHandler` fires only on `before insert`. Updating a Case's Subject, Origin, AccountId, or ContactId to match an existing open Case is not prevented. A `before update` extension should be added if this becomes a concern.

6. **Case Duplicate Prevention has a race condition risk (same as Account).** The composite-key SOQL query cannot see uncommitted rows from concurrent inserts. Two simultaneous Case inserts with the same composite key can both succeed. A database-level Unique constraint across these four fields is the only complete solution.

7. **Case Lookup Agent: SOQL inside a for loop.** `CaseLookupAction.getCaseDetails()` runs one SOQL query per `CaseRequest` item. Agentforce passes a single request per turn in normal use, but bulk invocation (e.g. from a Flow or Process) risks hitting the 101-query governor limit. Fix: collect all CaseNumbers first, run a single `WHERE CaseNumber IN :set` query, then match results back to each request.

8. **Case Lookup Agent: `WITH SECURITY_ENFORCED` instead of `WITH USER_MODE`.** The project standard is `WITH USER_MODE` (API 65.0). `WITH SECURITY_ENFORCED` throws a runtime exception if the running user lacks field-level access; the catch block converts this to a clean `caseFound = false` result, so functional correctness is maintained, but the project convention is not followed. Should be updated in a future iteration.

9. **Case Lookup Agent: meta XML files use API version 63.0.** `CaseLookupAction.cls-meta.xml` and `CaseLookupActionTest.cls-meta.xml` declare `<apiVersion>63.0</apiVersion>`. Project standard is 65.0. Cosmetic only — no runtime impact.

10. **LWC Error Handling Framework: ErrorLogService silently discards insert failures.** `Database.insert` is called with `allOrNone=false` and the returned `SaveResult[]` is ignored. Insert failures (FLS violations, governor limits, invalid picklist values) are completely silent. There is no fallback mechanism.

11. **LWC Error Handling Framework: No LWC Jest tests.** `errorUtils` and `errorPanel` have no Jest test files. Jest infrastructure is not configured in this project.

12. **LWC Error Handling Framework: No retention policy on Error_Log\_\_c.** Records accumulate indefinitely. A scheduled batch to purge or archive old records should be planned before production use.

13. **LWC Error Handling Framework: errorPanel uses legacy `if:true` directives.** The `lwc:if` directive (Summer '23+) is the recommended modern equivalent. The legacy directive works in API 65.0 but should be migrated in a future iteration.

14. **Tescribe: No dedicated test class.** `Tescribe.cls` is exercised only indirectly through test classes of other features. A standalone `TescribeTest.cls` covering all builder paths, token combinations, and error cases should be added to protect against regressions.

15. **Tescribe: `save()` is allOrNone=true.** Unlike the project's standard pattern of `Database.insert(..., allOrNone=false)`, Tescribe's `save()` uses native `insert` (implicit `allOrNone=true`). A single failing record aborts the entire batch insert with a `DmlException`. This is intentional fail-fast behaviour for test data but differs from production DML conventions.

16. **JsonPlaceholderService: No retry logic.** A single HTTP 500 or network timeout immediately throws an `AuraHandledException`. There is no retry or backoff mechanism.

17. **JsonPlaceholderService: `cacheable=true` may return stale data.** LWC wire adapter results are cached by Salesforce Lightning Data Service. If upstream data changes, the cache must be manually invalidated or the method made non-cacheable.

18. **JsonPlaceholderService: Callouts cannot follow DML in the same transaction.** Any caller that performs DML before invoking `getPosts()` will receive a `CalloutException: You have uncommitted work pending`. Callers must sequence all callouts before DML or use a Queueable/Future context.

19. **CalloutService: Busy-wait sleep consumes CPU governor time.** The `sleep()` method polls `DateTime.now()` in a tight loop for up to 5000 ms per retry interval, consuming CPU time rather than yielding. Deep retry chains against a real clock can exhaust the Apex CPU limit in synchronous contexts.

20. **CalloutService: No exception type discrimination.** Every exception type (including permanent errors such as a missing Named Credential) triggers a retry, burning all three attempts plus two 5-second delays before returning `null`.

21. **CalloutService: Failure logging uses `System.debug` only.** Retry exhaustion events are invisible in production without an active debug log. Persistent failure tracking requires integration with `ErrorLogService` or a Platform Event.
