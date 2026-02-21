# Salesforce Developer Agent Memory

## Files
- See [apex-patterns.md](apex-patterns.md) for trigger/handler structure, DML/SOQL patterns, constants, task creation, and AuraEnabled patterns.

## Key Project Conventions
- API version: 65.0 for all new Apex classes
- Trigger pattern: Handler class pattern (`TriggerName` → `TriggerNameHandler`)
- All service/handler classes use `with sharing`
- DML: Use `Database.*` methods, not naked DML
- SOQL: Use `WITH USER_MODE` (API 65.0+), except in tests where custom fields may lack FLS
- Error handling: `AuraHandledException` for LWC-facing methods

## Classes Created
| Class                      | Purpose                                             |
|----------------------------|-----------------------------------------------------|
| `AccountTriggerHandler`    | Evaluates Account health rating on insert/update    |
| `AccountTriggerHandlerTest`| 19 tests, 91% coverage                             |
| `LeadTriggerHandler`       | Stamps last contacted date, overdue flag on Leads   |
| `LeadTriggerHandlerTest`   | Test class for LeadTriggerHandler                   |
| `OverdueLeadsController`   | AuraEnabled controller for overdueLeads LWC         |
| `OverdueLeadsControllerTest`| Test class for OverdueLeadsController              |

## AccountTriggerHandler — Health Rating Logic
- `evaluateHealthRating(List<Account> accounts)` — runs on before insert/update
- `createAtRiskTasks(List<Account> accounts)` — runs on after update only
- Recursion guards: `@TestVisible static Boolean hasRunBefore` and `hasRunAfter`
- Rating thresholds defined as constants (enums/constants pattern, not magic strings)

## CRITICAL: WITH USER_MODE + FLS in Test Classes
- Tests using `WITH USER_MODE` in SOQL will fail with "No such column" if the running user lacks FLS on custom fields — even if the field exists in the org.
- Pattern to follow in test classes:
  - DML: use `AccessLevel.SYSTEM_MODE` so custom field writes succeed regardless of FLS
  - SOQL: use `WITH USER_MODE` to match production handler behavior
- The admin agent must create a permission set granting FLS on any custom fields used.
- The devops agent must assign that permission set to the running user post-deployment.

## Recursion Guard Pattern
```apex
// In handler class
@TestVisible static Boolean hasRunBefore = false;
@TestVisible static Boolean hasRunAfter  = false;

// In tests — reset before every update DML
AccountTriggerHandler.hasRunBefore = false;
AccountTriggerHandler.hasRunAfter  = false;
```

## Test Coverage Notes
- Always invoke handler logic via real DML (insert/update), not direct method calls — ensures trigger context fires
- `createAtRiskTasks` only fires on after-update, not insert
- Null `AnnualRevenue` and null `NumberOfEmployees` both default to 0 in health evaluation → 'At Risk'
