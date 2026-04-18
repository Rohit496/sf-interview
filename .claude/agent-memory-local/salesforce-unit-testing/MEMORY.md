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

## Testing addError() / Duplicate Prevention

- Use `Database.insert(record, false, AccessLevel.SYSTEM_MODE)` (allOrNone=false) to capture `addError()` failures per-record without throwing an exception.
- Check `sr.isSuccess()` and `sr.getErrors()[0].getMessage()` to assert the error message.
- For within-batch duplicate tests, pass a `List<SObject>` to `Database.insert(list, false, ...)` and assert `results[0].isSuccess()` true and `results[1].isSuccess()` false.
- Always call `resetGuards()` after the pre-insert of existing data so the update/duplicate insert fires through a fresh handler state.
- SOQL `IN` on text fields is case-insensitive in Salesforce; the handler's `.toLowerCase()` on both sides ensures the Apex-side comparison is also case-insensitive.

## CaseTriggerHandler Patterns

- `hasRunBeforeInsert` is the single guard; reset with `CaseTriggerHandler.hasRunBeforeInsert = false;`
- Closed Case test: insert Case, update Status to 'Closed', verify `IsClosed = true` via SOQL, then reset guard and insert new Case — should succeed because handler queries `WHERE IsClosed = false`.
- Null Origin: Case.Origin is sometimes required in orgs — build with explicit `null` if needed; handler treats null as '' in key.
- Bulk half-duplicate pattern: use `i / 2` as subject suffix so each even-indexed record is unique and each odd-indexed record duplicates the preceding even-indexed one.

## Fire-and-Forget Service Patterns (ErrorLogService)

- No `@TestSetup` needed when the class under test has no prerequisite records.
- Test each valid picklist value individually — one test per value is self-documenting and achieves full branch coverage.
- For null/blank inputs to a fire-and-forget method: wrap the call in try/catch and `Assert.fail(...)` inside the catch to prove no exception escapes.
- After a null/blank/invalid call, query record count and assert 0 — this documents the silent-failure behaviour.
- For the "only required field provided" test: assert optional fields are null in the queried record; proves null inputs pass through cleanly.
- Capture `Datetime beforeCall = Datetime.now()` before `Test.startTest()` then assert `log.Occurred_At__c >= beforeCall` to validate auto-set datetime fields.
- Invalid picklist value → `Database.insert(record, false)` silently fails; no exception, 0 records created.
- SOQL verification after `Test.stopTest()` does not require `AccessLevel.SYSTEM_MODE` — use `WITH USER_MODE` consistently for queries.

## HTTP Callout Service Patterns (JsonPlaceholderService)

- No `@TestSetup` needed — callout services have no prerequisite SObject records.
- Use a single configurable `MockHttpCallout` inner class with `(Integer statusCode, String body)` constructor — avoids a separate mock class per status code.
- Test three branches: HTTP 200 valid JSON, HTTP non-200 (re-thrown `CalloutException`), HTTP 200 empty array.
- Non-200 branch re-throws `CalloutException` from the catch block — do NOT catch `AuraHandledException`; only `CalloutException` should be thrown for status mismatches.
- Use `Assert.fail(...)` inside `Test.startTest()` block _before_ the catch to confirm the exception is always thrown.
- After the try/catch, call `Test.stopTest()` outside the catch so it always executes even if the test passes the catch.
- Plain wrapper classes (no methods, only fields): create a dedicated `PostWrapperTest` to explicitly exercise all field getters/setters in isolation, even though transitive coverage exists from the service test.
- Verify `@TestVisible` constants (ENDPOINT_POSTS, HTTP_METHOD_GET, etc.) in a separate `constants_verify*` test — self-documents expected values and catches accidental regressions.

## Stateful/Sequential HttpCalloutMock Pattern (makeCallout)

- When testing a retry loop, a single `FixedResponseMock` cannot simulate "fail once, then succeed". Use a `SequentialResponseMock` inner class that holds `List<Integer> statusCodes` and `List<String> bodies`, increments an internal `callIndex` per `respond()` call, and clamps the index to `size()-1` so the last entry repeats if exhausted.
- Constructor: `SequentialResponseMock(List<Integer> statusCodes, List<String> bodies)`.
- Keep a separate `FixedResponseMock(Integer statusCode, String body)` for pure-success and pure-failure tests — simpler and self-documenting.
- `sleep()` busy-wait: test with `sleep(0)` to exercise the method path without spending CPU. Do NOT test with real positive millis values — the busy-wait will consume all CPU governor limits inside the test context.
- Verify `@TestVisible` constants (MAX*RETRIES, DELAY_MILLIS) in a dedicated `testConstants*\*` method.
- 2xx boundary tests are valuable: HTTP 299 should succeed, HTTP 300 should fail (exhausts retries → null).
- No `@TestSetup` needed — no SObject prerequisite records.

## Exception-Throwing HttpCalloutMock Pattern (catch block coverage)

- `FixedResponseMock` and `SequentialResponseMock` cannot drive a catch block — they always return a response. To cover a catch block, use a dedicated `ThrowingMock` that throws in `respond()`.
- `CalloutException` cannot be constructed with a message argument directly. Construct it with no args, then call `ex.setMessage('...')` before throwing.
- For "throw once then succeed" scenarios, use a `ThrowThenSucceedMock` with an internal `callCount` integer: throw when `callCount == 1`, return HTTP 200 thereafter. This is simpler and more self-documenting than extending `SequentialResponseMock`.
- Place all exception-related mocks and tests in a clearly labelled section ("Exception catch block coverage") so coverage intent is obvious to future readers.

## InvocableMethod / Action Class Patterns (CaseLookupAction)

- Test by calling the static method directly: `CaseLookupAction.getCaseDetails(requests)` — no trigger DML needed.
- Build a `buildRequest(String caseNum)` helper that instantiates the inner `CaseRequest` class and sets `caseNumber`.
- Null caseNumber input triggers the catch block (NPE from `.trim()`); assert `caseFound = false` and `errorMessage.startsWith('Error retrieving case:')`.
- Empty-string caseNumber falls through to the not-found branch; assert `caseFound = false` and `errorMessage` is set.
- WITH SECURITY_ENFORCED in the production SOQL: use `AccessLevel.SYSTEM_MODE` for test DML so the test user has field access.
- Bulk 200 test: pass 200 requests pointing to the same valid CaseNumber — verifies no governor limit breach in the SOQL-per-item loop.
- Always test null-safe navigation separately: insert a Case with no AccountId and assert `accountName = null` while `caseFound = true`.
