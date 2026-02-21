# Unit Testing Agent Memory

## Key Project Patterns
- See `test-patterns.md` for conventions confirmed across multiple test classes.
- API version: 65.0 for all test class metadata files.
- Test class metadata goes in `force-app/main/default/classes/` alongside the class.

## Recursion Guards
- AccountTriggerHandler exposes `hasRunBefore` and `hasRunAfter` as `@TestVisible`.
- Reset BOTH before every update DML in tests: `AccountTriggerHandler.hasRunBefore = false; AccountTriggerHandler.hasRunAfter = false;`
- LeadTriggerHandler uses a single `hasRun` flag — reset with `LeadTriggerHandler.hasRun = false;`

## DML Access Level
- Use `AccessLevel.SYSTEM_MODE` for test DML when custom fields may lack FLS for the running test user.
- Use `WITH USER_MODE` in SOQL queries inside tests (handler runs in system mode; queries are fine in user mode).

## Coverage Tips
- For trigger handlers: invoke via real DML (insert/update), not by calling handler methods directly — ensures trigger context is exercised.
- For `createAtRiskTasks`: the after-context fires only during `update`; insert does not trigger it.
- Null fields in `evaluateHealthRating`: null revenue and null employees both default to 0, so both < thresholds → 'At Risk'.
