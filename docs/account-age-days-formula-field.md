# Account Age (Days) Formula Field

**Date:** 2026-06-21
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request
Create a designer-chosen formula field on the standard Account object: "Account Age (Days)" that computes the number of days elapsed since the Account record was created.

### Business Objective
Sales and operations teams often need to know how long an account has been in the system — for example, to identify recently created accounts that need onboarding attention, or to surface long-standing accounts that have never been converted. A formula field that auto-calculates this value removes any manual effort and ensures the number is always current without requiring a trigger, flow, or batch job.

### Summary
A single read-only formula field (`Account_Age_Days__c`) was added to the standard `Account` object. It uses the native Salesforce formula `TODAY() - DATEVALUE(CreatedDate)` to return a whole-number count of calendar days since the record was created. Because it is a formula field, it recalculates automatically every time the record is viewed and requires no Apex, no Flow, and no scheduled process.

---

## Components Created

### Admin Components (Declarative)

#### Custom Fields

| Object | Field API Name | Label | Type | Description |
|--------|----------------|-------|------|-------------|
| `Account` | `Account_Age_Days__c` | Account Age (Days) | Formula (Number) | Number of days elapsed since the Account record was created. |

**Full Field Specification**

| Property | Value |
|----------|-------|
| API Name | `Account_Age_Days__c` |
| Label | Account Age (Days) |
| Data Type | Formula — returns Number |
| Precision | 18 |
| Scale | 0 (whole numbers only) |
| Formula | `TODAY() - DATEVALUE(CreatedDate)` |
| Blank Field Handling | Blank as Zero (`BlankAsZero`) |
| Description | Number of days elapsed since the Account record was created. |
| Help Text (Inline) | The age of this Account in days since its creation. |
| External ID | false |
| Namespace | None |
| API Version | 65.0 |

---

### Development Components (Code)

None. This feature is entirely declarative — no Apex classes, triggers, test classes, LWC components, or Flows were created.

---

## How the Formula Works

```
Formula: TODAY() - DATEVALUE(CreatedDate)
```

| Part | Explanation |
|------|-------------|
| `TODAY()` | Returns the current date (no time component) in the org's time zone. Re-evaluated every time the record is displayed. |
| `CreatedDate` | Standard Salesforce DateTime field that records the exact moment the record was inserted. |
| `DATEVALUE(CreatedDate)` | Strips the time component from `CreatedDate`, converting it to a plain Date so it is compatible with `TODAY()`. |
| `TODAY() - DATEVALUE(CreatedDate)` | Subtracts two Date values, which Salesforce evaluates as the number of calendar days between them, returned as a Number. |
| `BlankAsZero` | Instructs Salesforce to treat any blank operands as zero rather than null, preventing blank/null results. In practice `CreatedDate` is never null on a persisted record, so this setting acts as a safety guard. |

### Calculation examples

| CreatedDate | Today (example) | Result |
|-------------|-----------------|--------|
| 2026-06-21 | 2026-06-21 | 0 |
| 2026-06-14 | 2026-06-21 | 7 |
| 2025-06-21 | 2026-06-21 | 365 |
| 2024-01-01 | 2026-06-21 | 901 |

The value shown to the user always reflects today's date — not the date the record was last saved.

---

## Data Flow

### How it surfaces in Salesforce

```
Record Created
      │
      ▼
Account.CreatedDate  ──┐
                       ├──► TODAY() - DATEVALUE(CreatedDate)  ──►  Account_Age_Days__c
TODAY()            ────┘       (evaluated at page-render time)       (read-only display)
```

1. A user creates or opens an Account record.
2. Salesforce evaluates the formula at render time using the current day (`TODAY()`) and the stored `CreatedDate`.
3. The result (a whole number) is displayed in any page layout section, list view column, report column, or filter condition where the field has been added.
4. No data is written back to the database — formula field values are computed on the fly and are not persisted.

### Where the field can be used

| Surface | Supported | Notes |
|---------|-----------|-------|
| Record Page Layout | Yes | Add via Setup > Object Manager > Account > Page Layouts |
| List Views | Yes | Add as a column; sortable |
| Reports | Yes | Add as a column; can be used in summary/matrix formulas |
| Report Filters | Yes | e.g., "Account Age (Days) greater than 365" |
| List View Filters | Yes | Same filter operators as any number field |
| SOQL (Apex / API) | Yes | Queryable as `Account_Age_Days__c` |
| Formula references | Yes | Other formula fields on Account can reference this field |
| Flow conditions | Yes | Can be used as a filter/decision condition in Flows |
| Triggers | Yes | Readable in trigger context (read-only) |
| LWC / Aura | Yes | Wire via `getRecord` or `@wire(getFieldValue)` |

---

## File Locations

| Component | Path |
|-----------|------|
| Field Metadata | `force-app/main/default/objects/Account/fields/Account_Age_Days__c.field-meta.xml` |

---

## Configuration Details

### Making the field visible to users

Formula fields are automatically readable by any user who has Read access to the Account object. No permission set or field-level security change is strictly required. However, the field must be explicitly placed on page layouts and list views before users will see it.

**Recommended steps after deployment:**

1. **Page Layout** — Setup > Object Manager > Account > Page Layouts > add "Account Age (Days)" to the desired section (e.g., Account Information).
2. **List View** — From the Accounts list view, use the column selector to add "Account Age (Days)".
3. **Reports** — Open or create an Accounts report and add the field as a column.

### Field-Level Security (FLS)

Because this is a formula field on a standard object with no namespace, it inherits the standard object's field access rules. It is always read-only — no profile or permission set can grant write access to a formula field.

---

## Limitations and Considerations

### Known Limitations

| Limitation | Detail |
|------------|--------|
| Read-only | Formula fields cannot be edited by users or set via DML. The value is always derived from `CreatedDate`. |
| No historical snapshots | The field always reflects today's age. You cannot query "what was the age on a specific past date" using this field. To do that, use `TODAY() - DATEVALUE(CreatedDate)` directly in a report formula or SOQL expression. |
| Time zone sensitivity | `TODAY()` uses the org's default time zone. For orgs spanning multiple time zones, the displayed value may differ by 1 day for users in very different zones relative to the org's configured time zone. |
| Not stored in database | Because formula field values are computed at query time, they cannot be indexed and filtering on very large data sets (millions of records) may be slower than filtering on a stored field. |
| Rollup summary limitation | Formula fields cannot be used directly as the field to aggregate in a Roll-Up Summary field. |

### Future Enhancements

- If a stored (non-formula) version of the age is needed for indexing or rollup purposes, a Flow or Apex trigger can write the computed value into a separate Number field on a nightly or on-change basis.
- A companion formula field `Account_Age_Years__c` could be added using `FLOOR((TODAY() - DATEVALUE(CreatedDate)) / 365.25)` for a year-level view.
- The field can be used as a filter criterion in a list view to create a "New Accounts (< 30 days)" view or a "Stale Accounts (> 365 days)" view without any code.

### Dependencies

| Dependency | Type | Notes |
|------------|------|-------|
| `Account.CreatedDate` | Standard field | Always present on every Account record; cannot be null on a persisted record. |
| `TODAY()` | Formula function | Standard Salesforce formula function; no version or org feature dependency. |

---

## Security

| Aspect | Detail |
|--------|--------|
| Sharing | Controlled by the Account object's sharing model (OWD + sharing rules). The formula field adds no additional exposure. |
| Write access | Impossible — formula fields are always read-only in the Salesforce platform. |
| FLS | Inherits Account field access. No custom FLS configuration required. |

---

## Testing

No test class is required or applicable for a declarative formula field. Validation can be performed manually:

1. Open any existing Account record and note the `CreatedDate`.
2. Verify that `Account Age (Days)` displays `TODAY() - DATEVALUE(CreatedDate)` as a whole number.
3. Optionally, run the following SOQL in Developer Console to confirm the computed value matches expectations:

```sql
SELECT Id, Name, CreatedDate, Account_Age_Days__c
FROM Account
ORDER BY CreatedDate ASC
LIMIT 10
```

---

## Change History

| Date | Author | Change Description |
|------|--------|-------------------|
| 2026-06-21 | Documentation Agent | Initial creation |
