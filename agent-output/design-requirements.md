# Design Requirements -- Retry Callout Pattern

===============================================================================
DESIGN REQUIREMENTS
===============================================================================

## WHAT USER REQUESTED

A retry callout pattern in Apex with:

- A `makeCallout` class with a static method accepting url, method, and body parameters
- Returns HttpResponse
- Maximum 3 retry attempts
- 5000ms delay between retries using a busy-wait sleep helper method
- Catches exceptions and retries on failure
- Returns null if all retries exhausted
- A separate static `sleep(Integer secs)` helper method using DateTime busy-wait loop
- Test class with mock HTTP callouts

---

                    ADMIN WORK (salesforce-admin)

---

No admin work required for this request.

---

                    DEVELOPMENT WORK (salesforce-developer)

---

1. Apex Class: `makeCallout`
    - `with sharing` keyword
    - API version 65.0
    - Static method that accepts: String url (endpoint), String method (HTTP method), String body
    - Returns: HttpResponse
    - Maximum 3 retry attempts
    - 5000ms delay between retries using busy-wait sleep helper
    - Catches exceptions and retries on failure
    - Returns null if all retries exhausted
    - Separate static `sleep(Integer secs)` helper method using DateTime busy-wait loop
    - Method accepts endpoint as parameter for flexibility (caller can pass Named Credential URLs like `callout:CredName/path`)

2. Test Class: `makeCalloutTest`
    - API version 65.0
    - Implements HttpCalloutMock for mock callouts
    - Test scenarios:
      a. Successful callout on first attempt
      b. All retries exhausted returning null (mock that throws exceptions or returns error)
    - Use @IsTest annotation

---

                    EXECUTION ORDER

---

1. Developer creates `makeCallout` class and `makeCalloutTest` class
   (No dependencies on admin work -- single step)

---

                    PROMPTS FOR SPECIALIST AGENTS

---

### PROMPT FOR salesforce-admin

```
No admin work required.
```

### PROMPT FOR salesforce-developer

```
Create the following Apex classes. Follow project conventions: `with sharing`,
API version 65.0, named constants over magic strings.

1. Class: makeCallout
   - with sharing
   - A static method that accepts three parameters:
     String url (endpoint), String method (HTTP method), String body
   - Returns HttpResponse
   - Maximum 3 retry attempts (use a named constant for the retry count)
   - 5000ms delay between retries (use a named constant for the delay in milliseconds)
   - Delay is implemented via a separate static sleep(Integer milliseconds) helper
     method that uses a DateTime busy-wait loop (loop checking
     DateTime.now() >= target time)
   - Catches exceptions during callout and retries on failure
   - Returns null if all retries are exhausted without success
   - The method signature accepts the endpoint as a parameter for flexibility
     (caller can pass Named Credential URLs like callout:CredName/path)

2. Test Class: makeCalloutTest
   - Implements HttpCalloutMock for mock callouts
   - Test scenarios:
     a. Successful callout on first attempt
     b. All retries exhausted returning null
   - API version 65.0
   - Use @IsTest annotation

Do not deploy -- just create the metadata files under
force-app/main/default/classes/.
```

===============================================================================
