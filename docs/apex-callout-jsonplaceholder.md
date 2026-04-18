# Apex HTTP Callout -- JSONPlaceholder API

**Date:** 2026-03-07
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

Create an Apex HTTP callout to https://jsonplaceholder.typicode.com/posts:

- A Remote Site Setting (or Named Credential) for the endpoint
- An Apex class to make the callout (GET all posts)
- A response wrapper/model class to deserialize the JSON response
- Response shape: array of objects with fields: userId, id, title, body

### Business Objective

Enable Salesforce Apex code and Lightning Web Components to retrieve public post data from the JSONPlaceholder REST API. JSONPlaceholder is a free, publicly hosted fake REST API commonly used for prototyping and demonstrating HTTP callout patterns. This feature establishes a reusable callout pattern -- Remote Site Setting + typed wrapper class + `@AuraEnabled` service class -- that LWC components or other Apex code can consume directly.

### Summary

A Remote Site Setting was created to whitelist the JSONPlaceholder base URL. Two Apex classes were then created: `PostWrapper` (a data model for a single post resource) and `JsonPlaceholderService` (a `with sharing` service class with an `@AuraEnabled(cacheable=true)` method that performs an HTTP GET to `/posts`, validates the status code, deserializes the JSON array into a typed list, and wraps all exceptions as `AuraHandledException` for safe LWC consumption). Eleven test methods across two test classes cover all happy-path and error branches.

---

## Components Created

### Admin Components (Declarative)

#### Remote Site Settings

| Setting Name      | URL                                    | Active | Protocol Security Disabled | Description                                        |
| ----------------- | -------------------------------------- | ------ | -------------------------- | -------------------------------------------------- |
| `JsonPlaceholder` | `https://jsonplaceholder.typicode.com` | true   | false                      | Remote Site Setting for JSONPlaceholder public API |

No Named Credential was used because the JSONPlaceholder API is public and requires no authentication.

---

### Development Components (Code)

#### Apex Classes

| Class Name               | Sharing        | Type                 | Description                                                                                                                                  |
| ------------------------ | -------------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `PostWrapper`            | `with sharing` | Response Model       | Data holder for a single JSONPlaceholder post resource; all four fields are `@AuraEnabled`                                                   |
| `JsonPlaceholderService` | `with sharing` | HTTP Callout Service | Performs HTTP GET to `/posts`, validates response status, deserializes JSON into `List<PostWrapper>`, wraps errors as `AuraHandledException` |

#### Test Classes

| Test Class                   | Tests For                | Test Methods |
| ---------------------------- | ------------------------ | ------------ |
| `JsonPlaceholderServiceTest` | `JsonPlaceholderService` | 6            |
| `PostWrapperTest`            | `PostWrapper`            | 5            |

---

## API Response Shape

The JSONPlaceholder `/posts` endpoint returns a JSON array. Each element has the following shape:

```json
{
    "userId": 1,
    "id": 1,
    "title": "sunt aut facere repellat provident occaecati excepturi optio reprehenderit",
    "body": "quia et suscipit\nsuscipit recusandae..."
}
```

This maps directly to the `PostWrapper` class fields.

---

## Data Flow

### How It Works

```
1. A caller (LWC wire adapter or imperative Apex) invokes JsonPlaceholderService.getPosts()
2. The service builds an HttpRequest: GET https://jsonplaceholder.typicode.com/posts
   with Content-Type: application/json header
3. Http.send() dispatches the callout (blocked in tests by HttpCalloutMock)
4. If the response status code is not 200, a CalloutException is thrown immediately
5. If status is 200, JSON.deserialize() converts the response body into List<PostWrapper>
6. The list is returned to the caller
7. If any exception occurs at any step, it is caught and re-thrown as AuraHandledException
   so LWC error handlers receive a clean, user-safe message
```

### Architecture Diagram

```
  LWC Component / Apex Caller
         |
         | @AuraEnabled(cacheable=true) / imperative call
         v
  JsonPlaceholderService.getPosts()
         |
         | HttpRequest: GET /posts
         | Header: Content-Type: application/json
         v
  https://jsonplaceholder.typicode.com/posts
  (Remote Site Setting: JsonPlaceholder)
         |
         | HttpResponse (JSON array)
         v
  Status Code Check
         |
    200? |--------NO-------> CalloutException("Unexpected HTTP response status: <code>")
         |                           |
         |                           v
         |                   catch(Exception e)
         |                           |
         |                           v
         |                   AuraHandledException(e.getMessage())
         |
        YES
         |
         v
  JSON.deserialize(body, List<PostWrapper>.class)
         |
         v
  List<PostWrapper> [ { userId, id, title, body }, ... ]
         |
         v
  Return to caller
```

---

## Class Details

### PostWrapper

A plain data-holder class with no business logic. All four fields use `{ get; set; }` accessors and are annotated `@AuraEnabled` so they can be returned from `@AuraEnabled` service methods and read directly in LWC JavaScript.

| Field    | Apex Type | @AuraEnabled | Description                          |
| -------- | --------- | ------------ | ------------------------------------ |
| `userId` | `Integer` | Yes          | ID of the user who authored the post |
| `id`     | `Integer` | Yes          | Unique identifier of the post        |
| `title`  | `String`  | Yes          | Post title                           |
| `body`   | `String`  | Yes          | Post body content                    |

Default values for all fields are `null` (Apex default for primitives in a wrapper class).

### JsonPlaceholderService

#### Constants (`@TestVisible`)

| Constant                    | Value                                          | Purpose                                    |
| --------------------------- | ---------------------------------------------- | ------------------------------------------ |
| `ENDPOINT_POSTS`            | `'https://jsonplaceholder.typicode.com/posts'` | Callout endpoint URL                       |
| `HTTP_METHOD_GET`           | `'GET'`                                        | HTTP method string                         |
| `HTTP_STATUS_OK`            | `200`                                          | Expected success status code               |
| `HEADER_CONTENT_TYPE_NAME`  | `'Content-Type'`                               | Request header name                        |
| `HEADER_CONTENT_TYPE_VALUE` | `'application/json'`                           | Request header value                       |
| `ERROR_NON_200`             | `'Unexpected HTTP response status: '`          | Error message prefix for non-200 responses |

All constants are `@TestVisible` private statics, which allows the test class to assert their exact values without exposing them publicly.

#### Method: `getPosts()`

| Attribute             | Value                                                                        |
| --------------------- | ---------------------------------------------------------------------------- |
| Signature             | `public static List<PostWrapper> getPosts()`                                 |
| Annotation            | `@AuraEnabled(cacheable=true)`                                               |
| Sharing               | `with sharing` (class-level)                                                 |
| Parameters            | None                                                                         |
| Returns               | `List<PostWrapper>`                                                          |
| Throws (user-visible) | `AuraHandledException` -- wraps any `Exception` including `CalloutException` |

The `cacheable=true` annotation means LWC can use `@wire` to call this method, and Salesforce will cache the response. This is appropriate for read-only data that does not change between page loads.

---

## File Locations

| Component                    | Path                                                                            |
| ---------------------------- | ------------------------------------------------------------------------------- |
| Remote Site Setting          | `force-app/main/default/remoteSiteSettings/JsonPlaceholder.remoteSite-meta.xml` |
| PostWrapper class            | `force-app/main/default/classes/PostWrapper.cls`                                |
| PostWrapper meta             | `force-app/main/default/classes/PostWrapper.cls-meta.xml`                       |
| JsonPlaceholderService class | `force-app/main/default/classes/JsonPlaceholderService.cls`                     |
| JsonPlaceholderService meta  | `force-app/main/default/classes/JsonPlaceholderService.cls-meta.xml`            |
| JsonPlaceholderServiceTest   | `force-app/main/default/classes/JsonPlaceholderServiceTest.cls`                 |
| PostWrapperTest              | `force-app/main/default/classes/PostWrapperTest.cls`                            |

---

## Testing

### Test Strategy

HTTP callouts cannot be made in test context. Both test classes rely on `HttpCalloutMock` via `Test.setMock()` to intercept all outbound HTTP requests and return pre-configured responses.

The inner `MockHttpCallout` class in `JsonPlaceholderServiceTest` accepts any status code and response body at construction time. Its `respond()` method also asserts that the service used the correct HTTP method (`GET`) and the exact endpoint constant (`ENDPOINT_POSTS`), so the mock itself serves as a structural contract test.

### Test Method Inventory

#### JsonPlaceholderServiceTest (6 methods)

| Method                                                        | Scenario                         | Asserts                                                                                      |
| ------------------------------------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------- |
| `getPosts_http200ValidSinglePost_returnsOnePostWithAllFields` | HTTP 200, single-item JSON array | Non-null list, size=1, all four fields deserialized correctly                                |
| `getPosts_http200ValidMultiplePosts_returnsAllPostsInOrder`   | HTTP 200, two-item JSON array    | Non-null list, size=2, all four fields on both items                                         |
| `getPosts_http200EmptyJsonArray_returnsEmptyList`             | HTTP 200, empty JSON array `[]`  | Non-null list, size=0, no exception                                                          |
| `getPosts_http500_throwsCalloutExceptionWithStatusCode`       | HTTP 500                         | `CalloutException` thrown (not swallowed), message contains `'500'`                          |
| `getPosts_http404_throwsCalloutExceptionWithStatusCode`       | HTTP 404                         | `CalloutException` thrown, message contains `'404'` and starts with `ERROR_NON_200` constant |
| `constants_verifyExpectedValues`                              | No HTTP call                     | `ENDPOINT_POSTS`, `HTTP_METHOD_GET`, `HTTP_STATUS_OK`, `ERROR_NON_200` have expected values  |

#### PostWrapperTest (5 methods)

| Method                                                       | Scenario                  | Asserts                                                      |
| ------------------------------------------------------------ | ------------------------- | ------------------------------------------------------------ |
| `postWrapper_setAllFields_gettersReturnAssignedValues`       | All four fields assigned  | Getter returns exact assigned value for each field           |
| `postWrapper_newInstance_allFieldsDefaultToNull`             | Fresh instantiation       | All four fields are null                                     |
| `postWrapper_overwriteOneField_otherFieldsUnchanged`         | One field updated         | Changed field reflects new value; all other fields unchanged |
| `postWrapper_integerFieldsSetToZero_returnZero`              | Integer fields set to 0   | Returns 0 (distinguishes from null)                          |
| `postWrapper_stringFieldsSetToEmptyString_returnEmptyString` | String fields set to `''` | Returns `''` (distinguishes from null)                       |

### Coverage Notes

- `PostWrapper` is also covered transitively through `JsonPlaceholderServiceTest` (the happy-path tests fully deserialize JSON into `PostWrapper` instances and assert all four fields). `PostWrapperTest` provides explicit, isolated coverage.
- The constants test (`constants_verifyExpectedValues`) acts as a regression guard: any accidental change to the endpoint URL or HTTP method will immediately fail this test.
- The non-200 tests verify that the exception is a `CalloutException`, not an `AuraHandledException`. This is important because the catch block re-wraps any `Exception` as `AuraHandledException` -- but `CalloutException` is itself a subclass of `Exception`, so the re-throw happens as `AuraHandledException`. The tests use a try/catch with a fallback `Assert.fail` to distinguish exception types precisely.

---

## Security

### Sharing Model

- `PostWrapper` -- `with sharing` (no SOQL or DML; sharing has no effect but follows project convention)
- `JsonPlaceholderService` -- `with sharing` (no SOQL or DML; callout behavior is unaffected by sharing mode but follows project convention)

### Remote Site Setting

The Remote Site Setting `JsonPlaceholder` whitelists `https://jsonplaceholder.typicode.com`. Without this setting, all HTTP callouts to that domain would fail with a `CalloutException` at runtime. `disableProtocolSecurity` is `false`, so standard TLS verification is enforced.

### No Authentication

JSONPlaceholder is a public, unauthenticated API. No credentials, Named Credentials, or Auth Providers are required. If a future integration requires authentication, replace the Remote Site Setting with a Named Credential and update the endpoint constant accordingly.

### Required Permissions

No custom permission set is required. Access to `JsonPlaceholderService.getPosts()` is controlled by standard Apex class access (Profile or Permission Set).

---

## Deployment Order

| Order | Component                                        | Reason                                                                                                   |
| ----- | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| 1     | `JsonPlaceholder.remoteSite-meta.xml`            | Remote Site Setting must exist before callouts can succeed at runtime                                    |
| 2     | `PostWrapper.cls` + `JsonPlaceholderService.cls` | Classes can be deployed in the same step as the Remote Site Setting; no ordering constraint between them |
| 3     | Test classes                                     | Automatically compiled alongside the production classes; no strict ordering beyond their dependencies    |

---

## Notes and Considerations

### Known Limitations

1. **No retry logic.** A single HTTP 500 or network timeout immediately throws an exception. If reliability is required, wrap the callout in a retry loop with exponential backoff or use a Platform Event / Queueable for async retry.

2. **`cacheable=true` caches stale data.** LWC wire adapter results are cached by Salesforce Lightning Data Service. If the JSONPlaceholder API data changes, the cache must be invalidated manually (or the method made non-cacheable) for the LWC to receive fresh data. For a real-world integration, evaluate whether stale reads are acceptable.

3. **No pagination support.** The `/posts` endpoint returns all 100 posts in a single call. If the upstream API introduced pagination, the service class would need to be updated to handle pages or cursor tokens.

4. **Single callout per transaction.** The Salesforce governor limit allows up to 100 HTTP callouts per transaction. Each call to `getPosts()` consumes one callout. This is unlikely to be a concern for this endpoint but should be noted if the pattern is replicated across many service classes in a single transaction.

5. **Callouts cannot be made after DML in the same transaction.** If a caller performs DML before invoking `getPosts()`, Salesforce will throw a `System.CalloutException: You have uncommitted work pending. Please commit or rollback before calling out`. Design callers to perform all callouts before DML, or use a Queueable/Future method to separate contexts.

### Future Enhancements

- Add a specific endpoint method such as `getPostById(Integer postId)` to retrieve a single post by ID from `/posts/{id}`.
- Add a Named Credential if the target API is replaced with an authenticated endpoint.
- Add an LWC component that wires to `JsonPlaceholderService.getPosts()` and renders the post list in a datatable.
- Consider a caching layer (Platform Cache) for high-frequency callout scenarios to avoid repeated network round-trips.

### Dependencies

- No custom objects or fields required.
- No permission sets required.
- Requires an internet-accessible Salesforce org (sandbox or scratch org must be able to reach `https://jsonplaceholder.typicode.com`). Orgs behind strict network egress rules may need additional network configuration.

---

## Change History

| Date       | Author              | Change Description |
| ---------- | ------------------- | ------------------ |
| 2026-03-07 | Documentation Agent | Initial creation   |
