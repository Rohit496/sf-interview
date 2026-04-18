# Tescribe Test Data Library

**Date:** 2026-03-03
**Author:** Documentation Agent
**Status:** Completed
**License:** MIT
**Upstream Repository:** https://github.com/priyankumodi/Tescribe
**Upstream Author:** Priyank Modi

---

## Overview

### Original Request

Add the Tescribe fluent test data generation library to this Salesforce project.
The library eliminates the need for boilerplate `TestDataFactory` classes by providing
a builder API, a token engine for dynamic values, precision selectors for targeting
specific records, and a template system backed by Custom Metadata.

### Business Objective

Writing test data setup in Apex test classes is repetitive and fragile. Developers
must manually create SObject instances, assign every required field, and keep factory
classes in sync as schema changes. Tescribe centralises that logic behind a concise
fluent API so tests remain readable and easy to maintain. The Custom Metadata
template system additionally allows "golden record" prototypes to be stored and
versioned outside of code, enabling data-driven testing without hard-coding large
field sets in every test class.

### Summary

Tescribe is a single Apex class (`Tescribe`) that implements the Builder pattern for
SObject construction and insertion. Callers chain method calls to declare what records
they need, then call `build()` for in-memory records or `save()` to insert them.
A companion Custom Metadata Type (`Tescribe_Template__mdt`) stores reusable record
prototypes in JSON form, and a Permission Set grants running users the access they
need to query those templates.

---

## Components Created

### Admin Components (Declarative)

#### Custom Metadata Types

| API Name                 | Label             | Description                                                                                                                                                                         |
| ------------------------ | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Tescribe_Template__mdt` | Tescribe Template | Central repository for test data prototypes. Each record stores a JSON snapshot of a "golden record", enabling data-driven unit tests without hard-coding large field sets in Apex. |

#### Custom Fields on `Tescribe_Template__mdt`

| Field API Name       | Type           | Required | Length | Manageability       | Description                                                                                                                                         |
| -------------------- | -------------- | -------- | ------ | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Object_API_Name__c` | Text           | Yes      | 100    | DeveloperControlled | The exact API name of the target SObject (e.g., `Account`, `Opportunity`). Used by the builder to instantiate the correct record type.              |
| `JSON_Data__c`       | Long Text Area | No       | 32,768 | DeveloperControlled | JSON map of field-value pairs that form the record prototype. Compatible with Salesforce Inspector "Copy JSON" export format.                       |
| `Is_Active__c`       | Checkbox       | —        | —      | DeveloperControlled | Default `true`. When unchecked the template is ignored by the builder, allowing retirement of old data shapes without deleting the metadata record. |
| `Description__c`     | Long Text Area | No       | 2,000  | DeveloperControlled | Developer notes describing the "persona" or data state this template represents (e.g., "Standard Enterprise Account with UK Billing Address").      |

#### Permission Sets

| API Name          | Label           | Description                                                                                                        |
| ----------------- | --------------- | ------------------------------------------------------------------------------------------------------------------ |
| `Tescribe_Access` | Tescribe Access | Grants Apex class access to `Tescribe` and read-only access to all four custom fields on `Tescribe_Template__mdt`. |

---

### Development Components (Code)

#### Apex Classes

| Class Name | Sharing           | Type              | Description                                                                                                                                                                                                                                                                                                 |
| ---------- | ----------------- | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Tescribe` | `without sharing` | Utility / Builder | Fluent test data generation library. Provides the builder API, token engine, precision selectors, and template-driven record construction. `without sharing` is an explicit design decision: the class is a test utility and must be able to insert records regardless of the running user's sharing rules. |

No separate test class is included in this project for Tescribe itself; the library is
tested via the test classes of all other features that use it.

---

## API Reference

### Entry Points

| Method Signature                        | Description                                                                                                                                                                                                                                                                                         |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Tescribe.builder(SObjectType objType)` | Creates a new builder targeting the given SObject type. No SOQL.                                                                                                                                                                                                                                    |
| `Tescribe.builder(String templateName)` | Creates a new builder by loading a `Tescribe_Template__mdt` record whose `DeveloperName` matches `templateName` and `Is_Active__c` is `true`. Fires one SOQL query. Throws `IllegalArgumentException` if the template is not found or the `Object_API_Name__c` does not resolve to a valid SObject. |

### Builder Chain Methods

| Method Signature                                                          | Description                                                                                                                    |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `repeat(Integer qty)`                                                     | Sets the number of records to generate. Default is `1`.                                                                        |
| `setFieldValue(SObjectField field, Object value)`                         | Sets `field` to `value` on all records.                                                                                        |
| `setFieldValue(SObjectField field, Object value, List<String> selectors)` | Sets `field` to `value` only on records whose zero-based index matches a selector (see Precision Selectors).                   |
| `setFieldValue(String fieldName, Object value)`                           | Same as above using a field API name string.                                                                                   |
| `setFieldValue(String fieldName, Object value, List<String> selectors)`   | Same as above with selector support.                                                                                           |
| `setFieldValues(SObjectField field, List<Object> values)`                 | Maps a list of values onto records by position. Record at index `i` receives `values[i]`. Out-of-range indices receive `null`. |
| `setFieldValues(SObjectField field, List<SObject> records)`               | Extracts the `Id` from each SObject and applies the resulting Id list positionally (useful for setting lookup fields).         |
| `setFieldValues(String fieldName, List<Object> values)`                   | Same as the SObjectField variant using a string field name.                                                                    |
| `setFieldValues(String fieldName, List<SObject> records)`                 | Same as the SObjectField variant using a string field name.                                                                    |

### Terminal Methods

| Method Signature | Return Type     | Description                                                                                                                                                                                                                                     |
| ---------------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `build()`        | `List<SObject>` | Constructs and returns SObject instances **without** performing any DML. Records exist in memory only.                                                                                                                                          |
| `save()`         | `List<SObject>` | Calls `build()` then inserts the records using the standard `insert` statement (`allOrNone=true`). A `DmlException` is thrown if any record fails validation or a required field is missing. Returns the inserted records (with populated Ids). |

---

## Token Engine

Tokens are placeholders embedded in String field values. The token processor resolves
them at build time per record. Non-string values pass through unchanged.

| Token Syntax  | Resolves To                                                              | Example Input              | Example Output (records 0, 1, 2)      |
| ------------- | ------------------------------------------------------------------------ | -------------------------- | ------------------------------------- |
| `{counter}`   | 1-based record counter within the current `build()` call                 | `'Account {counter}'`      | `Account 1`, `Account 2`, `Account 3` |
| `{counter:N}` | Counter starting at `N` (offset)                                         | `{counter:10}`             | `10`, `11`, `12`                      |
| `{alpha}`     | Alphabetic sequence (A, B, C ... Z, AA, AB ...)                          | `'Region {alpha}'`         | `Region A`, `Region B`, `Region C`    |
| `{alpha:X}`   | Alphabetic sequence starting at letter `X`                               | `{alpha:C}`                | `C`, `D`, `E`                         |
| `{0N}`        | Zero-padded counter, `N` = number of pad digits                          | `'CASE-{00}'`              | `CASE-01`, `CASE-02`, `CASE-03`       |
| `{0N:S}`      | Zero-padded counter starting at `S`                                      | `'{000:5}'`                | `005`, `006`, `007`                   |
| `{index}`     | Zero-based index of the current record                                   | `'Item {index}'`           | `Item 0`, `Item 1`, `Item 2`          |
| `{random}`    | Pseudo-unique value combining global sequence and 4 crypto random digits | `'Email{random}@test.com'` | Unique per record per run             |

Token processing is short-circuited: if the value contains no `{` character, the
processor returns immediately without scanning for any tokens.

---

## Precision Selectors

Selectors restrict a `setFieldValue` rule to a subset of the generated records.
They are passed as a `List<String>` and evaluated against the zero-based record index.

| Selector Format                | Applies To                                       |
| ------------------------------ | ------------------------------------------------ |
| `'2'`                          | Record at index 2 only                           |
| `'0'`, `'3'`, `'5'` (multiple) | Records at index 0, 3, and 5                     |
| `'0-2'`                        | Records at indices 0, 1, and 2 (inclusive range) |
| Mixed list `['0', '3-5']`      | Record 0 and records 3, 4, 5                     |

If the selector list is empty or null, the rule applies to **all** records (global rule).

Rules are internally sorted into a `globalRules` list and a `specificRuleMap` keyed
by index. Specific rules overwrite global rules for the same field, allowing a default
value to be set for all records and then overridden for specific ones.

---

## Template-Driven Data

The `builder(String templateName)` entry point loads a `Tescribe_Template__mdt` record
and pre-populates all builder rules from its JSON payload before returning the builder
instance. Callers can still add or override individual fields with `setFieldValue` after
loading the template.

### Template Loading Behaviour

1. SOQL query filters by `DeveloperName = :templateName AND Is_Active__c = TRUE`. Only
   the first match is used.
2. `Object_API_Name__c` is resolved via `Schema.getGlobalDescribe()`. An invalid name
   throws `IllegalArgumentException`.
3. Each key in `JSON_Data__c` is checked against the object's field map. Fields that
   are not createable or are calculated (formula) are silently skipped.
4. The resulting builder is returned with the same fluent API as the direct
   `builder(SObjectType)` entry point.

### Creating a Template Record

1. Open Setup > Custom Metadata Types > Tescribe Template > Manage Records.
2. Click **New**.
3. Fill in:
    - **Label**: Human-readable name (e.g., "Standard Enterprise Account")
    - **Tescribe Template Name** (DeveloperName): Camel-case or underscore API name used in `builder('...')`
    - **Object API Name**: Exact Salesforce API name (e.g., `Account`)
    - **JSON Data**: Paste a JSON object of field-value pairs (Salesforce Inspector export or hand-written)
    - **Is Active**: Checked (default)
    - **Description**: What data scenario this template represents
4. Save.

### Example JSON Data Payload

```json
{
    "Name": "Test Account {counter}",
    "BillingCity": "San Francisco",
    "BillingPostalCode": "94105",
    "Type": "Customer - Direct",
    "NumberOfEmployees": 500
}
```

---

## Usage Examples

### Basic: Create a single Account

```apex
Account acc = (Account) Tescribe.builder(Account.SObjectType)
    .setFieldValue(Account.Name, 'Test Account')
    .save()[0];
```

### Bulk: Create 10 Accounts with unique names

```apex
List<Account> accounts = (List<Account>) Tescribe.builder(Account.SObjectType)
    .repeat(10)
    .setFieldValue(Account.Name, 'Account {counter}')
    .save();
```

### Precision Selectors: Override a field on specific records

```apex
// 5 Leads; first 3 are Hot, last 2 are Cold
List<Lead> leads = (List<Lead>) Tescribe.builder(Lead.SObjectType)
    .repeat(5)
    .setFieldValue(Lead.LastName, 'Test {counter}')
    .setFieldValue(Lead.Company, 'Company {counter}')
    .setFieldValue(Lead.Status, 'Open - Not Contacted')
    .setFieldValue(Lead.Rating, 'Hot', new List<String>{ '0-2' })
    .setFieldValue(Lead.Rating, 'Cold', new List<String>{ '3', '4' })
    .save();
```

### Positional values: Set a lookup field from a list of parent records

```apex
List<Account> accs = (List<Account>) Tescribe.builder(Account.SObjectType)
    .repeat(3)
    .setFieldValue(Account.Name, 'Parent {counter}')
    .save();

List<Contact> contacts = (List<Contact>) Tescribe.builder(Contact.SObjectType)
    .repeat(3)
    .setFieldValue(Contact.LastName, 'Contact {counter}')
    .setFieldValues(Contact.AccountId, accs)
    .save();
// contacts[0].AccountId = accs[0].Id, contacts[1].AccountId = accs[1].Id, etc.
```

### Template-driven: Load a stored prototype

```apex
// Assumes a Tescribe_Template__mdt record with DeveloperName = 'Standard_Account' exists
List<Account> accounts = (List<Account>) Tescribe.builder('Standard_Account')
    .repeat(5)
    .save();
```

### In-memory only: Inspect records without DML

```apex
List<Opportunity> opps = (List<Opportunity>) Tescribe.builder(Opportunity.SObjectType)
    .repeat(3)
    .setFieldValue(Opportunity.Name, 'Opp {counter}')
    .setFieldValue(Opportunity.StageName, 'Prospecting')
    .setFieldValue(Opportunity.CloseDate, Date.today().addDays(30))
    .build(); // no insert
```

### Mock template in test class (for 100% coverage of the template path)

```apex
Tescribe_Template__mdt mock = new Tescribe_Template__mdt(
    Object_API_Name__c = 'Account',
    JSON_Data__c = '{"Name":"Mock Account"}',
    Is_Active__c = true
);
Tescribe.mockTemplate = mock; // @TestVisible static field
List<Account> accs = (List<Account>) Tescribe.builder('any_name').save();
```

---

## Data Flow

### How It Works

```
1. Test class calls Tescribe.builder(SObjectType) or Tescribe.builder(templateName)
2. For template entry: one SOQL query fetches Tescribe_Template__mdt record
3. Caller chains .repeat(), .setFieldValue(), .setFieldValues() to define rules
4. Caller calls .build() or .save()
5. build() separates rules into globalRules and a per-index specificRuleMap
6. For each record (0 to quantity-1):
     a. globalSequence is incremented (used by {random} token)
     b. A new SObject instance is created via targetType.newSObject()
     c. Global rules are applied first (prototype values)
     d. Specific selector rules overwrite global rules for this index
     e. For each rule value, the token processor resolves {counter}, {alpha},
        {0N}, {index}, {random} tokens
7. build() returns the List<SObject>
8. save() calls build(), then inserts with allOrNone=true
```

### Architecture Diagram

```
Test Class
    |
    |-- Tescribe.builder(SObjectType) ---------> new Tescribe(type)
    |                                                     |
    |-- Tescribe.builder(templateName) ------> SOQL: Tescribe_Template__mdt
    |                                          JSON.deserializeUntyped()
    |                                          Schema validation (createable, !calculated)
    |                                          new Tescribe(type) + pre-set rules
    |
    |-- .repeat(N)                       }
    |-- .setFieldValue(field, value)     }  Appends FieldRule objects to rules list
    |-- .setFieldValue(field, val, sel)  }  Selectors parsed into IntegerRange / specificIndices
    |-- .setFieldValues(field, list)     }
    |
    |-- .build()
    |       |
    |       |-- Sort rules: globalRules[] vs specificRuleMap{index -> rules[]}
    |       |-- For i = 0..N-1:
    |       |       globalSequence++
    |       |       obj = targetType.newSObject()
    |       |       Apply globalRules (token-processed values)
    |       |       Apply specificRuleMap[i] rules (overwrite)
    |       |-- return List<SObject>
    |
    |-- .save()
            |
            |-- build()
            |-- insert records (allOrNone=true)
            |-- return List<SObject> (with Ids)
```

---

## File Locations

| Component                   | Path                                                                                                                                                      |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apex Class                  | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/Tescribe.cls`                                                    |
| Apex Class Metadata         | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/classes/Tescribe.cls-meta.xml`                                           |
| Custom Metadata Type Object | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Tescribe_Template__mdt/Tescribe_Template__mdt.object-meta.xml`   |
| Field: Object_API_Name\_\_c | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Tescribe_Template__mdt/fields/Object_API_Name__c.field-meta.xml` |
| Field: JSON_Data\_\_c       | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Tescribe_Template__mdt/fields/JSON_Data__c.field-meta.xml`       |
| Field: Is_Active\_\_c       | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Tescribe_Template__mdt/fields/Is_Active__c.field-meta.xml`       |
| Field: Description\_\_c     | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/objects/Tescribe_Template__mdt/fields/Description__c.field-meta.xml`     |
| Permission Set              | `/Users/rohit/Workspace/Salesforce/SF Interview/Interview/force-app/main/default/permissionsets/Tescribe_Access.permissionset-meta.xml`                   |

---

## Configuration Details

### Custom Metadata Field Details

| Field                | Type           | Length | Default | Required | Notes                                                                                                                                        |
| -------------------- | -------------- | ------ | ------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `Object_API_Name__c` | Text           | 100    | —       | Yes      | Must match a valid SObject API name; validated at runtime via `Schema.getGlobalDescribe()`. Case-insensitive via Salesforce schema.          |
| `JSON_Data__c`       | Long Text Area | 32,768 | —       | No       | Must be valid JSON (a flat object map). Nested objects are not currently supported. Compatible with Salesforce Inspector "Copy JSON" output. |
| `Is_Active__c`       | Checkbox       | —      | `true`  | —        | Soft-delete mechanism. Set to `false` to retire a template without losing its data.                                                          |
| `Description__c`     | Long Text Area | 2,000  | —       | No       | Documentation only; not read by the builder.                                                                                                 |

### Permission Set Details

The `Tescribe_Access` permission set grants:

- Apex class enabled access to `Tescribe`
- Read + View All Records on `Tescribe_Template__mdt`
- Readable (not editable) field permissions on all four custom fields

Note: Custom Metadata records are read-only for non-admin users by design. The
permission set covers what is needed for the `builder(templateName)` SOQL path.

### Modifications Made vs. Upstream

The following changes were made to the original Tescribe source during code review:

| Area              | Change                                                                                                                                 | Reason                                                                                                                                                               |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Class declaration | Added `without sharing` keyword (upstream had no sharing declaration, which defaults to implicit `without sharing` for test utilities) | Makes the sharing intent explicit and passes static analysis tools that flag implicit sharing                                                                        |
| `save()` comment  | Changed `// Safe insert` to `// allOrNone=true: throws DmlException if any record fails validation`                                    | The original comment was misleading; `allOrNone=true` is not "safe" — it throws on any failure                                                                       |
| Permission set    | Added `Object_API_Name__c` field permission                                                                                            | The upstream permission set did not include this field; omitting it would cause the template SOQL query to fail to retrieve the field for users without admin access |

---

## Deployment Order

Deploy in this order to avoid metadata dependency errors:

1. `Tescribe_Template__mdt` Custom Metadata Type (object + fields)
2. `Tescribe.cls` Apex class
3. `Tescribe_Access` permission set

The permission set references both the class and the metadata type, so it must be
deployed last.

---

## Security

### Sharing Model

`Tescribe` is declared `without sharing`. This is intentional for a test utility class:
test methods run in a context where sharing rules would block record insertion for
standard users, but test data must be created regardless. The class must never be
exposed to a non-test context.

### Permission Set Assignment

Assign `Tescribe_Access` to any integration user, developer sandbox profile, or CI/CD
service account that needs to run tests that use the template-driven entry point. Users
that only use the direct `builder(SObjectType)` entry point do not require the
permission set (that path performs no SOQL).

### Field Manageability

All custom fields on `Tescribe_Template__mdt` use `DeveloperControlled` manageability.
Records can only be created or edited by developers with Deploy permissions, not by
end users through the UI. This prevents accidental corruption of test data prototypes.

---

## Known Limitations

1. **`save()` uses `allOrNone=true`.** Any validation rule, required field, or trigger
   error will throw a `DmlException` and roll back all records in the batch. This is
   intentional for test data (fail fast), but callers must ensure all required fields
   are set before calling `save()`.

2. **Template JSON supports flat maps only.** Nested JSON objects in `JSON_Data__c` are
   not recursively traversed. Only top-level key-value pairs are applied as field values.
   Multi-level field paths (e.g., relationship fields) are not supported.

3. **`setFieldValues` positional mapping truncates to list length.** If `repeat(10)` is
   called but `setFieldValues` receives a list of 3 values, records at index 3–9 receive
   `null` for that field.

4. **Token processing applies to String values only.** Passing a token string as an
   Integer or Decimal field value will not be processed (the processor returns the raw
   value for non-String types).

5. **`{random}` token is not globally unique across test runs.** It combines `globalSequence`
   (a static Integer that resets each test execution) with 4 digits of `Crypto.getRandomInteger()`.
   Collisions are unlikely but possible; for true uniqueness use a UUID approach or
   `EncodingUtil.convertToHex(Crypto.generateAESKey(128))`.

6. **No test class for Tescribe itself.** The library relies on being exercised through
   the test classes of other features. Adding a dedicated `TescribeTest.cls` would provide
   explicit coverage of all builder paths and token combinations, and would protect against
   regressions if the library is modified.

7. **Template loading fires one SOQL query.** The `builder(templateName)` path uses one
   SOQL query per call. In `@TestSetup` methods or heavily data-driven tests that call
   this entry point many times, SOQL governor limits may become a concern. Use
   `Tescribe.mockTemplate` to bypass SOQL in performance-sensitive test paths.

---

## Notes & Considerations

### When to Use `build()` vs `save()`

Use `build()` when:

- You need to inspect or modify records before inserting them
- You want to test validation rules (insert is expected to fail)
- You are building parent-child hierarchies where child records need the parent Id

Use `save()` when:

- Records should be committed to the database and subsequent test logic queries them
- Simplicity is preferred and all required fields are already set

### globalSequence Static Variable

`globalSequence` is a `private static Integer` that increments every time `build()` is
called. It persists across multiple `Tescribe` builder instances within the same test
execution (not reset between test methods). This means the `{random}` token value is
different even across multiple `save()` calls in the same test class run.

### Integration with `@TestSetup`

Tescribe works well in `@TestSetup` methods. Because `@TestSetup` runs once and the
committed records are visible to all test methods, calling `save()` in setup and then
querying records back in individual test methods is the recommended pattern.

---

## Change History

| Date       | Author              | Change Description |
| ---------- | ------------------- | ------------------ |
| 2026-03-03 | Documentation Agent | Initial creation   |
