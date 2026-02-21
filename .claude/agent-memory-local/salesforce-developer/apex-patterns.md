# Apex Patterns — Confirmed in This Project

## Trigger Handler Structure
```apex
public with sharing class ObjectTriggerHandler {

    @TestVisible static Boolean hasRunBefore = false;
    @TestVisible static Boolean hasRunAfter  = false;

    public static void beforeInsert(List<SObject> newRecords) {
        if (hasRunBefore) return;
        hasRunBefore = true;
        // logic
    }

    public static void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        if (hasRunBefore) return;
        hasRunBefore = true;
        // logic
    }

    public static void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        if (hasRunAfter) return;
        hasRunAfter = true;
        // logic
    }
}
```

## Trigger Structure
```apex
trigger ObjectTrigger on SObjectName (before insert, before update, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) ObjectTriggerHandler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) ObjectTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) ObjectTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
```

## DML Patterns
- Use `Database.insert(list, true, AccessLevel.SYSTEM_MODE)` — never naked DML
- `AccessLevel.USER_MODE` for user-facing DML, `SYSTEM_MODE` when FLS may block writes (e.g., batch jobs, trigger handlers)
- Collect DML results and handle errors via `handleSaveResults()` helper

## SOQL Patterns
- Always use `WITH USER_MODE` on SOQL in handler classes (API 65.0 requirement)
- Exception: batch jobs and internal automation where system access is needed use `WITH SYSTEM_MODE`
- Filter to relevant records in bulk context using `Map<Id, SObject>` and `.keySet()`

## Constants Pattern
```apex
// Preferred — no magic strings
private static final String RATING_GOOD    = 'Good';
private static final String RATING_AVERAGE = 'Average';
private static final String RATING_AT_RISK = 'At Risk';
private static final String AT_RISK_TASK_SUBJECT_PREFIX = 'Review At Risk Account: ';
```

## Task Creation Pattern (after-update context)
```apex
List<Task> tasks = new List<Task>();
for (Account acc : newRecords) {
    Account old = (Account) oldMap.get(acc.Id);
    if (acc.Health_Rating__c == RATING_AT_RISK && old.Health_Rating__c != RATING_AT_RISK) {
        tasks.add(new Task(
            Subject      = AT_RISK_TASK_SUBJECT_PREFIX + acc.Name,
            WhatId       = acc.Id,
            OwnerId      = acc.OwnerId,
            ActivityDate = Date.today().addDays(7),
            Status       = 'Not Started',
            Priority     = 'High'
        ));
    }
}
if (!tasks.isEmpty()) {
    Database.insert(tasks, false, AccessLevel.USER_MODE);
}
```

## AuraEnabled Controller Pattern (for LWC)
```apex
public with sharing class ControllerName {
    @AuraEnabled(cacheable=true)
    public static List<SObject> getRecords() {
        try {
            return [SELECT Id, Name FROM SObject WITH USER_MODE];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
```

## Classes in This Project
| Class                       | Type            | Key Methods                                      |
|-----------------------------|-----------------|--------------------------------------------------|
| `AccountTriggerHandler`     | Trigger handler | `beforeInsert`, `beforeUpdate`, `afterUpdate`, `evaluateHealthRating`, `createAtRiskTasks` |
| `LeadTriggerHandler`        | Trigger handler | `beforeInsert`, `beforeUpdate` (stamps last contacted date, overdue flag) |
| `OverdueLeadsController`    | AuraEnabled     | `getOverdueLeads()` — returns `Is_Overdue__c = true` leads |

## Error Handling
- `System.debug(LoggingLevel.ERROR, ...)` is a known TODO — flag in code review as WARNING, not critical
- `AuraHandledException` wraps all exceptions in `@AuraEnabled` methods
- Fault connectors required on all DML in Flows (not Apex, but noted for cross-reference)
