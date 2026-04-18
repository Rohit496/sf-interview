# LWC Error Handling Framework

**Date:** 2026-03-01
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

Create a reusable Error Handling Framework for LWC in Salesforce that provides consistent error handling and display across all Lightning Web Components.

Specifically:

1. A shared JavaScript utility module with reusable error helper functions (normalizeError, reduceErrors) that any LWC can import
2. A reusable `<c-error-panel>` LWC component for consistent inline error display
3. Toast notifications for transient messages (handled by consuming components via `ShowToastEvent` — not built into this framework)
4. Error persistence to a custom `Error_Log__c` object via Apex
5. Support for different error types: Apex errors, network errors, validation errors
6. Available for new components only — existing components were NOT modified

### Business Objective

Without a shared framework, each LWC handles errors differently: some show raw Salesforce error objects, some silently swallow errors, and none persist failure context for debugging. This framework standardizes error handling org-wide by providing: (1) a utility module any component can import to extract human-readable messages from any error shape, (2) a turnkey display component for consistent SLDS-styled error UI, and (3) a persistent server-side log so developers can diagnose production errors without relying on transient debug logs.

### Summary

The framework consists of four new components deployed in dependency order: a `Error_Log__c` custom object to persist error records, an `ErrorLogService` Apex class exposing a fire-and-forget `@AuraEnabled` logging method, an `errorUtils` LWC service module exporting four utility functions, and an `errorPanel` LWC UI component that consumes `errorUtils` to display SLDS-styled errors in either inline or banner mode. No existing components were modified.

---

## Components Created

### Admin Components (Declarative)

#### Custom Objects

| Object API Name | Label     | Plural Label | Name Field Type | Name Format   | Sharing Model |
| --------------- | --------- | ------------ | --------------- | ------------- | ------------- |
| `Error_Log__c`  | Error Log | Error Logs   | Auto Number     | `ERR-{00000}` | ReadWrite     |

Object settings:

- Allow Reports: true
- Allow Search: true
- Deployment Status: Deployed
- Bulk API enabled: true
- External Sharing Model: Private

#### Custom Fields

| Object         | Field API Name      | Type           | Length / Detail                                                 | Required | Description                                                             |
| -------------- | ------------------- | -------------- | --------------------------------------------------------------- | -------- | ----------------------------------------------------------------------- |
| `Error_Log__c` | `Error_Type__c`     | Picklist       | Values: `Apex`, `Network`, `Validation`, `Unknown` (restricted) | Yes      | Classification of the error source                                      |
| `Error_Log__c` | `Error_Message__c`  | Long Text Area | 32,768 chars, 5 visible lines                                   | No       | Human-readable error message string                                     |
| `Error_Log__c` | `Stack_Trace__c`    | Long Text Area | 32,768 chars, 5 visible lines                                   | No       | JavaScript or Apex stack trace                                          |
| `Error_Log__c` | `Component_Name__c` | Text           | 255 chars                                                       | No       | LWC or Apex component where the error originated                        |
| `Error_Log__c` | `User__c`           | Lookup (User)  | Relationship: Error_Logs                                        | No       | The user who encountered the error (auto-populated by service)          |
| `Error_Log__c` | `Occurred_At__c`    | DateTime       | —                                                               | No       | Timestamp of the error (auto-populated by service via `Datetime.now()`) |

#### Validation Rules

None created.

#### Flows

None created.

#### Permission Sets

None created. Access to `Error_Log__c` is managed through standard profiles or existing permission set structure. If field-level security is needed, assign read/edit access to `Error_Log__c` fields via an existing permission set or create a dedicated one.

---

### Development Components (Code)

#### Apex Classes

| Class Name        | API Version | Type                | Sharing        | Description                                                         |
| ----------------- | ----------- | ------------------- | -------------- | ------------------------------------------------------------------- |
| `ErrorLogService` | 65.0        | AuraEnabled Service | `with sharing` | Fire-and-forget logging service called from LWC via imperative Apex |

#### Apex Triggers

None created.

#### Test Classes

| Test Class            | Tests For         | Test Methods | Description                                                                                                           |
| --------------------- | ----------------- | ------------ | --------------------------------------------------------------------------------------------------------------------- |
| `ErrorLogServiceTest` | `ErrorLogService` | 9            | Covers all 4 valid error types, field accuracy, null params, blank params, partial params, and invalid picklist value |

#### Lightning Web Components

| Component Name | Type                     | Is Exposed | Supported Targets                                                    | Description                                                                                           |
| -------------- | ------------------------ | ---------- | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `errorUtils`   | Service Module (no HTML) | false      | —                                                                    | Exports four utility functions: `reduceErrors`, `normalizeError`, `classifyError`, `logErrorToServer` |
| `errorPanel`   | UI Component             | true       | `lightning__RecordPage`, `lightning__AppPage`, `lightning__HomePage` | Renders SLDS-styled error messages in inline or banner mode                                           |

---

## Data Flow

### How It Works

```
1. A consuming LWC receives an error (wire adapter error, imperative Apex
   catch, UI API failure, plain JS Error, network error, etc.)

2. The component imports reduceErrors / normalizeError / classifyError from
   c/errorUtils to extract human-readable message strings from whatever
   error shape was returned.

3. For persistent logging, the component calls logErrorToServer({ error,
   componentName }) from c/errorUtils, which:
     a. Classifies the error type via classifyError()
     b. Normalizes the message via normalizeError()
     c. Extracts the stack trace (error.stack or error.body.stackTrace)
     d. Calls ErrorLogService.logError via imperative Apex (@AuraEnabled)
     e. Silently catches any logging failure so it never breaks the UI

4. ErrorLogService.logError creates an Error_Log__c record with:
     - Error_Type__c  = classified type (Apex / Network / Validation / Unknown)
     - Error_Message__c = normalized message string
     - Stack_Trace__c   = stack trace string
     - Component_Name__c = consuming component name
     - User__c          = UserInfo.getUserId() (auto-populated)
     - Occurred_At__c   = Datetime.now() (auto-populated)
   Uses Database.insert with allOrNone=false so insert failures are silent.

5. For inline display, the component includes <c-error-panel> in its template,
   passing the errors property. errorPanel calls reduceErrors internally and
   renders the message list using SLDS classes.
   - type="inline" (default): SLDS illustration with error icon + dotted list
   - type="banner": SLDS alert banner with role="alert" for page-level errors
   - No errors: renders nothing (empty template, zero DOM overhead)
```

### Architecture Diagram

```
Consuming LWC (any component)
  |
  |-- catch(error) --> c/errorUtils
  |                        |
  |                        |-- reduceErrors(error) --> string[]
  |                        |-- normalizeError(error) --> string
  |                        |-- classifyError(error) --> 'Apex'|'Network'|'Validation'|'Unknown'
  |                        |
  |                        |-- logErrorToServer({ error, componentName })
  |                                  |
  |                                  | (imperative Apex, async, fire-and-forget)
  |                                  v
  |                        ErrorLogService.logError()
  |                                  |
  |                                  | Database.insert (allOrNone=false, USER_MODE)
  |                                  v
  |                        Error_Log__c record
  |                        (ERR-00001, ERR-00002, ...)
  |
  |-- <c-error-panel errors={error}> --> errorPanel LWC
                              |
                              | calls reduceErrors(errors) internally
                              |
                              |-- type='inline' --> SLDS illustration + dotted message list
                              |-- type='banner' --> SLDS alert banner, role="alert"
                              |-- no errors    --> renders nothing
```

### Error Shape Handling (reduceErrors priority order)

| Priority | Error Shape             | Example                                           | Extracted Value               |
| -------- | ----------------------- | ------------------------------------------------- | ----------------------------- |
| 1        | `null` / `undefined`    | —                                                 | `['Unknown error']`           |
| 2        | Plain `string`          | `'Something failed'`                              | `['Something failed']`        |
| 3        | Array                   | `[err1, err2]`                                    | Recursively reduces each item |
| 4        | DML errors              | `{ body: { output: { errors: [{ message }] } } }` | Array of DML error messages   |
| 5        | UI API errors           | `{ body: [{ message }] }`                         | Array of body messages        |
| 6        | AuraHandledException    | `{ body: { message: 'string' } }`                 | `[body.message]`              |
| 7        | Network / FetchResponse | `{ status: 404, statusText: 'Not Found' }`        | `['404 Not Found']`           |
| 8        | Plain JS Error          | `{ message: 'string' }`                           | `[error.message]`             |
| 9        | Unrecognized object     | —                                                 | `['Unknown error']`           |

### Error Classification (classifyError)

| Return Value   | Trigger Condition                                       |
| -------------- | ------------------------------------------------------- |
| `'Validation'` | `error.body?.output?.errors` is present (checked first) |
| `'Apex'`       | `error.body?.message` is present                        |
| `'Network'`    | `error.status != null`                                  |
| `'Unknown'`    | `error` is null, non-object, or none of the above match |

---

## File Locations

| Component                    | Path                                                                                  |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| Custom Object definition     | `force-app/main/default/objects/Error_Log__c/Error_Log__c.object-meta.xml`            |
| Error_Type\_\_c field        | `force-app/main/default/objects/Error_Log__c/fields/Error_Type__c.field-meta.xml`     |
| Error_Message\_\_c field     | `force-app/main/default/objects/Error_Log__c/fields/Error_Message__c.field-meta.xml`  |
| Stack_Trace\_\_c field       | `force-app/main/default/objects/Error_Log__c/fields/Stack_Trace__c.field-meta.xml`    |
| Component_Name\_\_c field    | `force-app/main/default/objects/Error_Log__c/fields/Component_Name__c.field-meta.xml` |
| User\_\_c field              | `force-app/main/default/objects/Error_Log__c/fields/User__c.field-meta.xml`           |
| Occurred_At\_\_c field       | `force-app/main/default/objects/Error_Log__c/fields/Occurred_At__c.field-meta.xml`    |
| ErrorLogService Apex class   | `force-app/main/default/classes/ErrorLogService.cls`                                  |
| ErrorLogService metadata     | `force-app/main/default/classes/ErrorLogService.cls-meta.xml`                         |
| ErrorLogServiceTest class    | `force-app/main/default/classes/ErrorLogServiceTest.cls`                              |
| ErrorLogServiceTest metadata | `force-app/main/default/classes/ErrorLogServiceTest.cls-meta.xml`                     |
| errorUtils JS module         | `force-app/main/default/lwc/errorUtils/errorUtils.js`                                 |
| errorUtils metadata          | `force-app/main/default/lwc/errorUtils/errorUtils.js-meta.xml`                        |
| errorPanel controller        | `force-app/main/default/lwc/errorPanel/errorPanel.js`                                 |
| errorPanel template          | `force-app/main/default/lwc/errorPanel/errorPanel.html`                               |
| errorPanel metadata          | `force-app/main/default/lwc/errorPanel/errorPanel.js-meta.xml`                        |

---

## Configuration Details

### Error_Log\_\_c Object

The `Name` field is an Auto Number using format `ERR-{00000}`, starting at 1. Records will be named `ERR-00001`, `ERR-00002`, etc. The object is report-enabled and searchable. Sharing model is ReadWrite (org-wide default), meaning all internal users with object-level Read access can see all error log records.

### ErrorLogService — logError Method

```
Signature:  public static void logError(String errorType, String errorMessage,
                                        String stackTrace, String componentName)
Annotation: @AuraEnabled(cacheable=false)
DML:        Database.insert(errorLog, false, AccessLevel.USER_MODE)
            allOrNone=false → insert failures are silently discarded
            AccessLevel.USER_MODE → respects FLS of the calling user
Auto fields: User__c = UserInfo.getUserId()
             Occurred_At__c = Datetime.now()
Exception policy: no try/catch; allOrNone=false is the safety mechanism
                  (Database.insert returns SaveResult[] but the method ignores them)
```

### errorUtils — Exported Functions

| Function           | Signature                                          | Return          | Notes                                             |
| ------------------ | -------------------------------------------------- | --------------- | ------------------------------------------------- | ------------ | ---------- | ----------------------------------------- |
| `reduceErrors`     | `reduceErrors(error)`                              | `string[]`      | Handles all documented error shapes; never throws |
| `normalizeError`   | `normalizeError(error)`                            | `string`        | Joins `reduceErrors` output with `'; '`           |
| `classifyError`    | `classifyError(error)`                             | `'Apex'         | 'Network'                                         | 'Validation' | 'Unknown'` | Checks shape properties in priority order |
| `logErrorToServer` | `async logErrorToServer({ error, componentName })` | `Promise<void>` | Calls Apex; silently swallows all exceptions      |

### errorPanel — Public API

| Property      | Type                     | Default    | Description                                            |
| ------------- | ------------------------ | ---------- | ------------------------------------------------------ |
| `@api errors` | any                      | —          | Error object or array in any supported LWC error shape |
| `@api type`   | `'inline'` or `'banner'` | `'inline'` | Controls rendering mode                                |

Computed getter summary:

| Getter          | Logic                                                                                       |
| --------------- | ------------------------------------------------------------------------------------------- |
| `errorMessages` | Returns `[]` when `errors` is null/undefined; otherwise returns `reduceErrors(this.errors)` |
| `hasErrors`     | `errorMessages.length > 0`                                                                  |
| `isInline`      | `type !== 'banner'` (any unrecognized value falls through to inline)                        |
| `isBanner`      | `type === 'banner'`                                                                         |

---

## Usage Guide

### Importing errorUtils in any LWC

```javascript
import {
    reduceErrors,
    normalizeError,
    classifyError,
    logErrorToServer
} from 'c/errorUtils';
```

### Displaying errors with errorPanel

```html
<!-- Inline mode (default) — place inside a lightning-card body -->
<c-error-panel errors="{error}"></c-error-panel>

<!-- Banner mode — place at the top of a page or modal -->
<c-error-panel errors="{error}" type="banner"></c-error-panel>
```

The component renders nothing when `errors` is null, undefined, or an empty array — no conditional wrapping needed in the consuming template.

### Logging errors to the server

```javascript
import { logErrorToServer } from 'c/errorUtils';

// In an error handler:
async handleError(error) {
    await logErrorToServer({ error, componentName: 'myComponent' });
}
```

### Showing a toast (consuming component responsibility)

```javascript
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { normalizeError } from 'c/errorUtils';

handleError(error) {
    const message = normalizeError(error);
    this.dispatchEvent(new ShowToastEvent({
        title: 'Error',
        message,
        variant: 'error'
    }));
}
```

---

## Testing

### Test Coverage Summary

| Class                 | Test Methods | Status |
| --------------------- | ------------ | ------ |
| `ErrorLogServiceTest` | 9            | Pass   |

Note: `errorUtils` and `errorPanel` are JavaScript modules. No Apex test class covers them. LWC Jest tests are not included in this project (consistent with other LWC components in the project).

### Test Method Inventory

| Method Name                                                          | Scenario                                                            | Expected Outcome                                                            |
| -------------------------------------------------------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `logError_apexType_insertsOneRecord`                                 | Valid call with `Error_Type__c = 'Apex'`                            | Exactly 1 `Error_Log__c` record inserted                                    |
| `logError_networkType_insertsOneRecord`                              | Valid call with `Error_Type__c = 'Network'`                         | Exactly 1 record inserted                                                   |
| `logError_validationType_insertsOneRecord`                           | Valid call with `Error_Type__c = 'Validation'`                      | Exactly 1 record inserted                                                   |
| `logError_unknownType_insertsOneRecord`                              | Valid call with `Error_Type__c = 'Unknown'`                         | Exactly 1 record inserted                                                   |
| `logError_allFieldsPopulated_fieldValuesMatchInput`                  | All four input params + auto-populated `User__c` / `Occurred_At__c` | Every field on the record matches its expected value                        |
| `logError_allNullParameters_doesNotThrow`                            | All params `null`                                                   | No exception thrown; 0 records created (required field fails silently)      |
| `logError_allBlankParameters_doesNotThrow`                           | All params `''`                                                     | No exception thrown; 0 records created                                      |
| `logError_onlyErrorTypeProvided_insertsRecordWithNullOptionalFields` | Only `errorType` is non-null                                        | 1 record inserted; optional fields stored as null                           |
| `logError_invalidErrorType_silentlyFailsWithoutThrowing`             | `errorType = 'NotARealType'` (not in picklist)                      | No exception thrown; 0 records created (picklist validation fails silently) |

### Test Design Notes

- Tests use `WITH USER_MODE` on all SOQL queries in the test class.
- DML in test setup uses `AccessLevel.SYSTEM_MODE` to avoid FLS failures for the test user against custom fields. The production class's own `USER_MODE` DML is exercised within `Test.startTest() / Test.stopTest()`.
- No `@TestSetup` method is needed because `Error_Log__c` records are created entirely by the method under test.

---

## Security

### Sharing Model

- `ErrorLogService` is declared `with sharing`, so record access follows the running user's sharing rules when querying.
- `Database.insert` uses `AccessLevel.USER_MODE`, which respects the running user's FLS on `Error_Log__c` fields. If a user lacks write access to a field, that field is silently omitted from the insert (not an error).

### Required Permissions

For the logging feature to work end-to-end, the running user must have:

| Permission                                                                        | Minimum Level |
| --------------------------------------------------------------------------------- | ------------- |
| `Error_Log__c` object                                                             | Create        |
| `Error_Type__c`, `Error_Message__c`, `Stack_Trace__c`, `Component_Name__c` fields | Edit          |
| `User__c`, `Occurred_At__c` fields                                                | Edit          |

If a user lacks field-level access to one or more fields, `Database.insert` with `USER_MODE` will silently omit that field. The record will still be created if `Error_Type__c` (required) is accessible. The entire insert fails silently if `Error_Type__c` is not writable.

No permission sets were created as part of this feature. Access should be granted through the appropriate existing permission sets or profiles.

---

## Notes and Considerations

### Known Limitations

1. **No toast logic is built into the framework.** Toast notifications are the responsibility of the consuming component. `normalizeError()` from `errorUtils` provides the message string to pass to `ShowToastEvent`. This is intentional — toasts require access to the component's event dispatcher, which a service module cannot hold.

2. **`ErrorLogService` silently ignores insert failures.** `Database.insert` with `allOrNone=false` returns a `SaveResult[]` that the method does not inspect. Insert failures (e.g., due to FLS, required field violations, or governor limits) are discarded without any notification. There is no fallback logging mechanism.

3. **No LWC Jest tests.** `errorUtils` and `errorPanel` do not have Jest test files. Jest testing is not configured in this project (consistent with existing LWC components). Unit test coverage for the utility functions should be added when Jest infrastructure is introduced.

4. **`errorPanel` uses legacy `if:true` directives.** The template uses `if:true={hasErrors}`, `if:true={isInline}`, and `if:true={isBanner}`. These are valid in API 65.0 but the `lwc:if` directive (introduced in Summer '23) is the recommended modern equivalent and removes the need for complementary boolean getters.

5. **`logErrorToServer` silently swallows its own failures.** If the Apex call itself fails (network outage, permission issue, governor limit), the catch block discards the error without any indication. This is intentional to prevent logging from breaking the UI, but it means logging failures are completely invisible.

6. **No retention or archival policy.** `Error_Log__c` records accumulate indefinitely. Storage costs will grow over time. A scheduled batch to archive or delete records older than a defined threshold should be planned.

### Future Enhancements

- **Jest tests for errorUtils:** Write tests covering all error shapes recognized by `reduceErrors` and all classification branches in `classifyError`.
- **errorPanel upgrade to `lwc:if`:** Replace `if:true` with `lwc:if` / `lwc:elseif` / `lwc:else` directives for modern LWC compliance.
- **Error Log list view:** Create a default list view and page layout on `Error_Log__c` so admins can monitor errors via the Salesforce UI without writing SOQL.
- **Error Log retention batch:** A scheduled Apex batch to purge or archive `Error_Log__c` records older than N days.
- **Platform Event alternative:** Replace `@AuraEnabled` logging with a Platform Event publish so errors are captured asynchronously, even when the user's session ends or the DML fails mid-transaction.
- **`is_displayable` dashboard:** Build an `overdueErrors` LWC or Salesforce Report surfacing recent error volume by component name and error type.

### Dependencies

| This component...         | Depends on...                                           |
| ------------------------- | ------------------------------------------------------- |
| `ErrorLogService.cls`     | `Error_Log__c` custom object (must be deployed first)   |
| `errorUtils.js`           | `ErrorLogService.cls` (imported via `@salesforce/apex`) |
| `errorPanel.js`           | `errorUtils.js` (imported via `c/errorUtils`)           |
| `ErrorLogServiceTest.cls` | `ErrorLogService.cls`, `Error_Log__c`                   |

### Deployment Order

The components must be deployed in this order to satisfy compile-time dependencies:

1. `Error_Log__c` object and all six custom fields
2. `ErrorLogService.cls` (references `Error_Log__c`)
3. `errorUtils` LWC module (references `ErrorLogService` via `@salesforce/apex`)
4. `errorPanel` LWC component (references `errorUtils` via `c/errorUtils`)
5. `ErrorLogServiceTest.cls` (can be deployed with or after step 2)

---

## Change History

| Date       | Author              | Change Description |
| ---------- | ------------------- | ------------------ |
| 2026-03-01 | Documentation Agent | Initial creation   |
