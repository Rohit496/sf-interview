# Test Patterns — Confirmed in This Project

## Naming Convention
- File: `{ClassName}Test.cls`
- Method: `context_condition_expectedOutcome` (e.g., `insert_nullRevenueAndEmployees_treatsAsZeroAndSetsAtRiskRating`)
- Avoid `@TestSetup` when tests need distinct isolated data — use inline inserts instead.

## Structure
```apex
@IsTest
static void methodName_scenario_expectation() {
    // Arrange
    Account acc = buildAccount('Name', revenue, employees);

    // Act
    Test.startTest();
    Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
    Test.stopTest();

    // Assert
    Assert.isTrue(sr.isSuccess(), 'message');
    Account result = queryAccount(sr.getId());
    Assert.areEqual(expected, result.Field__c, 'descriptive message');
}
```

## Helper Methods (always include)
- `buildAccount(name, revenue, employees)` — builds unsaved Account
- `queryAccount(id)` — queries back with assertion fields using WITH USER_MODE
- `resetGuards()` — resets hasRunBefore + hasRunAfter on handler

## Bulk Test Pattern
- Insert 200 accounts covering all rating tiers; verify count per tier after query-back.
- Update pattern: insert 200 as Good, then update half to At Risk; verify Task count = 100.
- Use `Database.insert(list, true, AccessLevel.SYSTEM_MODE)` for bulk.
- Query result set with `new Map<Id, SObject>(list).keySet()` to filter to test records only.

## Assert Style
- Use `Assert.areEqual(expected, actual, 'message')` — preferred over `System.assertEquals`.
- Use `Assert.isTrue`, `Assert.isFalse`, `Assert.isNull`, `Assert.isNotNull`.
- Always provide a descriptive assertion message explaining the business rule being tested.

## Task Verification Pattern
```apex
List<Task> tasks = [
    SELECT Id, Subject, ActivityDate, Status, Priority, OwnerId, WhatId
    FROM Task
    WHERE WhatId = :accountId
    WITH USER_MODE
];
Assert.areEqual(1, tasks.size(), 'message');
Task t = tasks[0];
Assert.areEqual(expectedSubject, t.Subject, 'message');
```

## Recursion Guard Reset
Always call `resetGuards()` between insert and update in the same test method.
Failing to reset means the update handler silently skips all logic — tests pass but nothing is verified.
