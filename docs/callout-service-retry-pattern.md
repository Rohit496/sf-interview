# Callout Service -- Retry Pattern

**Date:** 2026-03-14
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

A retry callout pattern in Apex with:

- A class with a static method accepting `url`, `method`, and `body` parameters
- Returns `HttpResponse`
- Maximum 3 retry attempts
- 5000 ms delay between retries using a busy-wait sleep helper method
- Catches exceptions and retries on failure
- Returns `null` if all retries are exhausted
- A separate static `sleep(Integer millis)` helper method using a `DateTime` busy-wait loop
- Test class with mock HTTP callouts

### Business Objective

External integrations are inherently unreliable. Transient failures (network blips, remote server overload) often resolve within seconds. A generic retry wrapper lets any caller in the org benefit from automatic retry behaviour without duplicating that logic in every service class. This pattern is especially valuable for integrations that cannot use Platform Events or asynchronous Queueables.

### Summary

`CalloutService` is a stateless utility class that wraps every HTTP callout in a `while` loop capped at `MAX_RETRIES = 3` attempts. If a callout returns a non-2xx status code or throws an exception, the class sleeps for `DELAY_MILLIS = 5000` milliseconds (via a busy-wait loop) and tries again. A successful 2xx response is returned immediately; `null` is returned if all attempts fail. `CalloutServiceTest` covers the class with 10 test methods using two inner mock classes.

---

## Components Created

### Admin Components (Declarative)

No admin components were created for this feature. The class works with any Named Credential configured in the org by the caller at runtime.

---

### Development Components (Code)

#### Apex Classes

| Class Name           | Type                                  | Description                              |
| -------------------- | ------------------------------------- | ---------------------------------------- |
| `CalloutService`     | HTTP Callout Utility (`with sharing`) | Generic retry wrapper for HTTP callouts  |
| `CalloutServiceTest` | Test Class                            | 10 test methods covering all retry paths |

#### Apex Triggers

None.

#### Test Classes

| Test Class           | Tests For        | Coverage Notes                                                                                                                 |
| -------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `CalloutServiceTest` | `CalloutService` | 10 test methods; covers constants, success, full-retry exhaustion, partial retry, 2xx boundary edges, and the `sleep()` helper |

#### Lightning Web Components

None.

---

## Retry Logic -- How It Works

### Algorithm

```
send(url, method, body):
    numAttempts = MAX_RETRIES  // 3

    while numAttempts > 0:
        try:
            build HttpRequest (set endpoint, method, body if non-blank)
            response = Http.send(request)

            if response.statusCode in [200..299]:
                return response          // success -- exit immediately

            numAttempts--
            if numAttempts > 0:
                sleep(DELAY_MILLIS)      // wait before next attempt
            else:
                System.debug(ERROR, ...)  // log exhaustion

        catch Exception:
            numAttempts--
            if numAttempts > 0:
                sleep(DELAY_MILLIS)
            else:
                System.debug(ERROR, ...)  // log exhaustion

    return null                          // all attempts failed
```

### Key Constants

| Constant       | Value       | Visibility                             |
| -------------- | ----------- | -------------------------------------- |
| `MAX_RETRIES`  | `3`         | `private static final`, `@TestVisible` |
| `DELAY_MILLIS` | `5000` (ms) | `private static final`, `@TestVisible` |

Both constants are `@TestVisible` so the test class can assert their values as a regression guard.

### Retry Triggers

The class retries on **either** of these conditions:

1. **Non-2xx HTTP status code** -- any `statusCode < 200` or `statusCode > 299`
2. **Any exception** thrown during `Http.send()` (network errors, `CalloutException`, etc.)

### Sleep Implementation

```java
private static void sleep(Integer millis) {
    Long startTime = DateTime.now().getTime();
    while (DateTime.now().getTime() - startTime < millis) {
        // Busy-wait
    }
}
```

The `sleep()` method is a **busy-wait** loop. It continuously polls `DateTime.now()` until the elapsed wall-clock time exceeds `millis`. This is the standard workaround in Apex because `Thread.sleep()` does not exist on the platform. In test context the Apex test framework compresses time, so the full 5000 ms wall-clock delay does not actually block test execution.

---

## How to Use the Class

### Method Signature

```java
public static HttpResponse send(String url, String method, String body)
```

| Parameter | Type     | Notes                                                                                       |
| --------- | -------- | ------------------------------------------------------------------------------------------- |
| `url`     | `String` | Endpoint URL. Use Named Credential format (`callout:CredentialName/path`) -- never hardcode |
| `method`  | `String` | HTTP verb: `'GET'`, `'POST'`, `'PUT'`, `'DELETE'`, etc.                                     |
| `body`    | `String` | Request body. Pass `null` or blank for GET requests; body is only set when non-blank        |

**Return value:** `HttpResponse` on success (2xx), `null` if all retries are exhausted.

### Example -- GET Request

```java
HttpResponse res = CalloutService.send(
    'callout:ExternalAPI/api/v1/resource',
    'GET',
    null
);

if (res != null) {
    String responseBody = res.getBody();
    // process responseBody
} else {
    // all 3 attempts failed -- handle gracefully
    throw new AuraHandledException('External service unavailable. Please try again later.');
}
```

### Example -- POST Request

```java
String payload = JSON.serialize(new Map<String, Object>{ 'key', 'value' });

HttpResponse res = CalloutService.send(
    'callout:ExternalAPI/api/v1/items',
    'POST',
    payload
);

if (res != null && res.getStatusCode() == 201) {
    // record created successfully
}
```

### Named Credential Setup

The caller is responsible for configuring a Named Credential in Setup. The `callout:` prefix in the URL tells Salesforce to route the request through the Named Credential, which handles authentication and remote site allowlisting automatically. No Remote Site Setting is needed.

---

## Data Flow

### Architecture Diagram

```
Caller (Apex class, @AuraEnabled, Queueable, etc.)
    |
    | CalloutService.send('callout:CredName/path', 'GET', null)
    |
    v
+-------------------------------+
|       CalloutService          |
|  numAttempts = 3              |
|                               |
|  while numAttempts > 0:       |
|    build HttpRequest          |
|    Http.send() ─────────────────────> External Endpoint
|                               |       (via Named Credential)
|    if 2xx  ──────────────────────── return HttpResponse
|                               |
|    else/exception:            |
|      numAttempts--            |
|      if attempts remain:      |
|        sleep(5000 ms)         |   (busy-wait)
|      retry...                 |
|                               |
|  if all attempts fail:        |
|    System.debug(ERROR, ...)   |
|    return null                |
+-------------------------------+
    |
    v
Caller receives HttpResponse (success) or null (all retries exhausted)
```

---

## File Locations

| Component           | Path                                                             |
| ------------------- | ---------------------------------------------------------------- |
| Main class          | `force-app/main/default/classes/CalloutService.cls`              |
| Main class metadata | `force-app/main/default/classes/CalloutService.cls-meta.xml`     |
| Test class          | `force-app/main/default/classes/CalloutServiceTest.cls`          |
| Test class metadata | `force-app/main/default/classes/CalloutServiceTest.cls-meta.xml` |

---

## Configuration Details

### Class Configuration

| Attribute          | Value                                                               |
| ------------------ | ------------------------------------------------------------------- |
| Sharing model      | `with sharing`                                                      |
| API version        | 65.0                                                                |
| Max retry attempts | 3 (`MAX_RETRIES`)                                                   |
| Inter-retry delay  | 5000 ms (`DELAY_MILLIS`)                                            |
| Success range      | HTTP 200 -- 299 (inclusive)                                         |
| Failure result     | `null`                                                              |
| Exception handling | Catches all `Exception` types; retries then logs via `System.debug` |

### Null / Blank Body Handling

The body is forwarded to the `HttpRequest` only when `String.isNotBlank(body)` is true. Passing `null` or an empty string for GET-style requests is safe and expected.

---

## Testing

### Test Coverage Summary

| Class            | Test Methods | Status |
| ---------------- | ------------ | ------ |
| `CalloutService` | 10           | Pass   |

### Mock Classes Used

| Inner Class              | Type              | Purpose                                                                                                                                                                                  |
| ------------------------ | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FixedResponseMock`      | `HttpCalloutMock` | Stateless mock -- returns the same configured status code and body on every call. Used for pure-success and pure-failure scenarios.                                                      |
| `SequentialResponseMock` | `HttpCalloutMock` | Stateful mock -- returns a configurable list of status codes in order, one per call; repeats the last entry when the list is exhausted. Used for "fail N times, then succeed" scenarios. |

### Test Method Inventory

| Test Method                                       | Scenario                                                                   | Mock Used                                      |
| ------------------------------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------- |
| `testConstants_maxRetriesAndDelay`                | Asserts `MAX_RETRIES = 3` and `DELAY_MILLIS = 5000` as a regression guard  | None                                           |
| `testSend_firstAttemptSucceeds_returnsResponse`   | HTTP 200 on first attempt; result is non-null with correct body            | `FixedResponseMock(200, ...)`                  |
| `testSend_postWith201_returnsResponse`            | HTTP 201 with non-null body forwarded; POST request                        | `FixedResponseMock(201, ...)`                  |
| `testSend_allRetriesFail500_returnsNull`          | All 3 attempts return HTTP 500; result is `null`                           | `FixedResponseMock(500, ...)`                  |
| `testSend_allRetriesFail404_returnsNull`          | All 3 attempts return HTTP 404; result is `null`                           | `FixedResponseMock(404, ...)`                  |
| `testSend_firstFailsThenSucceeds_returnsResponse` | Attempt 1 returns 500, attempt 2 returns 200; result is 200 response       | `SequentialResponseMock([500, 200], ...)`      |
| `testSend_twoFailsThenSucceeds_returnsResponse`   | Attempts 1+2 return 500/503, attempt 3 returns 200; result is 200 response | `SequentialResponseMock([500, 503, 200], ...)` |
| `testSend_status299_treatedAsSuccess`             | HTTP 299 is upper boundary of 2xx; should return response, not null        | `FixedResponseMock(299, ...)`                  |
| `testSend_status300_treatedAsFailure`             | HTTP 300 is just outside 2xx; all retries should exhaust and return null   | `FixedResponseMock(300, ...)`                  |
| `testSleep_zeroMillis_completesWithoutException`  | `sleep(0)` completes without throwing; exercises method entry/exit path    | None                                           |

---

## Security

### Sharing Model

`CalloutService` uses `with sharing`, which enforces the running user's record-level sharing rules. This is appropriate for a utility class invoked from user-facing LWC controllers and Apex actions.

### Required Permissions

| Requirement             | Detail                                                                                   |
| ----------------------- | ---------------------------------------------------------------------------------------- |
| Apex class access       | Running user must have access to `CalloutService` via profile or permission set          |
| Named Credential        | The Named Credential referenced in the `url` parameter must be configured in Setup       |
| Outbound network access | Managed automatically by the Named Credential (no separate Remote Site Setting required) |

No custom permission set is shipped with this class. Access is governed by standard Apex class security settings on the caller's profile or permission set.

---

## Notes and Considerations

### Known Limitations

1. **Busy-wait sleep consumes CPU time.** The `sleep()` implementation polls `DateTime.now()` in a tight loop. It consumes CPU governor time during the delay rather than yielding. In production, each 5000 ms sleep against a real clock can exhaust the 10-second Apex CPU limit depending on the calling context. In practice, Apex transactions that perform callouts run outside the synchronous CPU limit, but callers should be aware of this trade-off.

2. **No retry on exception type discrimination.** The class retries on any `Exception`. Certain errors (e.g. a malformed URL, a missing Named Credential) are permanent failures that will never recover and still consume all three retries plus two 5-second delays. Consider discriminating on `CalloutException` vs other types in a future iteration.

3. **Failure logging uses `System.debug` only.** Exhaustion events are written to the debug log via `System.debug(LoggingLevel.ERROR, ...)`. These are invisible in production without an active debug log configuration. Integrate with `ErrorLogService` (or a Platform Event) for persistent failure tracking.

4. **No response body validation.** The class treats any 2xx response as success regardless of body content. A caller that needs to validate the response shape (e.g. JSON parse errors) must do so after `send()` returns.

5. **Callout-after-DML restriction applies to all callers.** Any caller that performs DML before invoking `CalloutService.send()` will receive a `CalloutException: You have uncommitted work pending`. Callers must sequence all callouts before DML or use an asynchronous context (Queueable, Future).

### Future Enhancements

- Replace busy-wait `sleep()` with a `Queueable` chain that chains itself on failure, allowing true asynchronous delay without CPU consumption.
- Add exception type filtering to skip retries for permanent error conditions.
- Add a `maxRetries` parameter override so callers can tune retry count per endpoint.
- Integrate exhaustion logging with `ErrorLogService` for persistent, queryable error records.

### Dependencies

| Dependency            | Type                    | Notes                                                                                        |
| --------------------- | ----------------------- | -------------------------------------------------------------------------------------------- |
| Named Credential      | Org Setup configuration | Caller must pass a valid `callout:` URL; class does not create or validate Named Credentials |
| No other Apex classes | --                      | `CalloutService` has no dependencies on other custom classes in this project                 |

---

## Change History

| Date       | Author              | Change Description |
| ---------- | ------------------- | ------------------ |
| 2026-03-14 | Documentation Agent | Initial creation   |
