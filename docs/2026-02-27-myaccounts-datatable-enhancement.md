# myAccounts LWC -- Datatable Enhancement

**Date:** 2026-02-27
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

Enhance the EXISTING `myAccounts` LWC component and its backing Apex controller:

1. Replace the current card-based layout with a `lightning-datatable`
2. Datatable columns: Id (hidden), Name, Industry, Phone, AnnualRevenue, Rating
3. No special datatable features (no inline editing, no row selection, no row actions, no pagination)
4. Update the existing `AccountController.getAccounts` Apex method to return up to 50 records instead of the current 2-5 clamp range
5. Keep the existing `AccountController` class -- just modify the limit

### Business Objective

The previous card-based layout rendered a maximum of 5 Account records and required custom HTML/CSS for avatar letters, color badges, and rating indicators. This limited usefulness as a data overview tool. By switching to a standard `lightning-datatable` and raising the cap to 50 records, users get a scannable, consistent table of up to 50 accounts without custom presentational code.

### Summary

Five existing files were modified and no new files were created. The `AccountController.clampDisplayCount()` method was updated to accept a range of 1--50 instead of the previous 2--5. The `myAccounts` LWC was refactored to remove all card-rendering helpers and replaced the hand-rolled card loop in the template with a single `lightning-datatable` element. The test class for `AccountController` was also updated to reflect the new boundary values.

---

## Components Modified

No new components were created. The following five files were modified.

### Development Components (Code)

#### Apex Classes

| Class Name | Type | Change Made |
|------------|------|-------------|
| `AccountController` | AuraEnabled Controller | `clampDisplayCount()` range changed from [2, 5] to [1, 50]; null/below-1 now defaults to 50 |
| `AccountControllerTest` | Test Class | Clamp boundary assertions updated to reflect new [1, 50] range; max-cap test now seeds 51 total records |

#### Lightning Web Components

| File | Change Made |
|------|-------------|
| `myAccounts/myAccounts.js` | Removed `AVATAR_COLORS`, `RATING_CLASS_MAP`, `_enrichAccount()`, `_formatCurrency()`; added `columns` array; changed `displayCount` default from 5 to 50; simplified wire handler |
| `myAccounts/myAccounts.html` | Replaced the `for:each` card iteration block with a `lightning-datatable` element |
| `myAccounts/myAccounts.css` | Removed `.rating-hot`, `.rating-warm`, `.rating-cold`, `.rating-default` rule blocks |
| `myAccounts/myAccounts.js-meta.xml` | Updated `displayCount` property default from `"5"` to `"50"`; updated description to say "up to 50" |

---

## Detailed Change Notes

### AccountController.cls

**Before:**
```apex
private static Integer clampDisplayCount(Integer value) {
    if (value == null || value < 2) {
        return 2;
    }
    return value > 5 ? 5 : value;
}
```

**After:**
```apex
private static Integer clampDisplayCount(Integer value) {
    if (value == null || value < 1) {
        return 50;
    }
    return value > 50 ? 50 : value;
}
```

Key behavioral differences:
- Minimum accepted value is now 1 (was 2). Values below 1 or null return 50 (was 2).
- Maximum cap is now 50 (was 5).
- The null/below-minimum default changed from 2 to 50 to match the new `displayCount` default in the LWC.

Everything else in the class is unchanged: `@AuraEnabled(cacheable=true)`, `WITH USER_MODE`, the `AccountResult` wrapper, SOQL field list (`Id, Name, Industry, Phone, AnnualRevenue, Rating`), and `ORDER BY Name ASC`.

### AccountControllerTest.cls

The test class was updated to match the new clamping behavior. The test method inventory is:

| Test Method | What It Tests |
|-------------|---------------|
| `testGetAccounts_returnsRequestedCount` | Requesting 3 returns exactly 3 records |
| `testGetAccounts_clampedToMin` | Requesting 1 still returns 2 (minimum floor behavior -- NOTE: see caveat below) |
| `testGetAccounts_clampedToMax` | Requesting 100 with 51 records in org returns exactly 50 |
| `testGetAccounts_nullCountDefaultsToMin` | Null input returns 2 (minimum floor) |
| `testGetAccounts_resultFieldsPopulated` | `Name` and `Id` fields are non-null on returned records |

**Important caveat on the min test:** The test assertions for `testGetAccounts_clampedToMin` and `testGetAccounts_nullCountDefaultsToMin` still assert a return count of `2`. However, the current implementation returns `50` (the new default) for null and below-1 inputs. The `@TestSetup` only seeds 10 records, so the query returns all 10 -- not 2 or 50. These two test methods pass only because the assertion checks `result.accounts.size()` against 2, and with 10 records seeded the actual returned count is 10, which means those assertions will fail. This is a known inconsistency in the test file that should be corrected in a follow-up.

The `testGetAccounts_clampedToMax` method is the most substantive new test. It inserts 41 additional accounts on top of the 10 from `@TestSetup` to ensure 51 records exist, then calls `getAccounts(100)` and asserts the result size is exactly 50.

### myAccounts.js

**Removed:**
- `AVATAR_COLORS` constant array (hex color values for avatar backgrounds)
- `RATING_CLASS_MAP` constant object mapping Rating values to CSS class names
- `_enrichAccount(acc)` method (added `avatarLetter`, `avatarStyle`, `formattedRevenue`, `ratingClass`, `isHot` to each record)
- `_formatCurrency(value)` helper method (manual `Intl.NumberFormat` formatting)
- `.map((acc) => this._enrichAccount(acc))` call in the wire handler

**Added:**
- `columns` array property defining the five visible columns for the datatable

**Changed:**
- `@api displayCount` default value changed from `5` to `50`
- Wire handler now assigns `data.accounts` directly to `this.accounts` (no enrichment step)

**Unchanged:** `@api title`, `hasError` getter, `footerText` getter, `isLoading`, `totalCount`, `errorMessage`, the wire import, and all error-handling logic.

The full `columns` definition:

```javascript
columns = [
    { label: 'Name',           fieldName: 'Name',          type: 'text'     },
    { label: 'Industry',       fieldName: 'Industry',       type: 'text'     },
    { label: 'Phone',          fieldName: 'Phone',          type: 'phone'    },
    { label: 'Annual Revenue', fieldName: 'AnnualRevenue',  type: 'currency' },
    { label: 'Rating',         fieldName: 'Rating',         type: 'text'     }
];
```

`Id` is used as `key-field` on the datatable element and is not a visible column.

### myAccounts.html

**Removed:** The entire `for:each` card iteration block (previously lines 28--83). This included the avatar circle, account name/industry/phone/revenue, and rating badge span per card.

**Added:**
```html
<lightning-datatable
    key-field="Id"
    data={accounts}
    columns={columns}
    hide-checkbox-column
></lightning-datatable>
```

**Unchanged:** The outer `slds-card` wrapper, the `.accounts-header` block with `{title}`, the `lightning-spinner` loading block, the error state `<p>`, and the footer pill with `{footerText}`.

The datatable is wrapped in a `<template if:false={isLoading}>` block so it (and the footer) are only rendered after the wire call resolves.

### myAccounts.css

**Removed:**
- `.rating-hot` rule
- `.rating-warm` rule
- `.rating-cold` rule
- `.rating-default` rule

**Unchanged:** `.accounts-header` (blue card header background), `.footer-pill` (light-blue tinted footer box), `.footer-text` (blue font weight for footer label).

### myAccounts.js-meta.xml

**Changed:**
- `displayCount` property `default` attribute: `"5"` → `"50"`
- `displayCount` property `description` attribute: previously referenced "2-5" range, now reads "Number of accounts shown on the card (up to 50). Values outside this range are clamped by the server."

---

## Data Flow

### How It Works

```
1. Admin drops myAccounts onto a Lightning page in App Builder and
   optionally configures the "Accounts to Display" property (default: 50).

2. Component renders with isLoading = true, showing lightning-spinner.

3. @wire(getAccounts, { displayCount: '$displayCount' }) fires,
   calling AccountController.getAccounts(50) via the Apex wire adapter.

4. AccountController.clampDisplayCount(50) returns 50 (within range).
   SOQL runs: SELECT Id, Name, Industry, Phone, AnnualRevenue, Rating
              FROM Account WITH USER_MODE ORDER BY Name ASC LIMIT 50
   A second SOQL runs for totalCount.

5. Wire adapter returns AccountResult { accounts: [...], totalCount: N }.

6. wiredAccounts handler sets isLoading = false, accounts = data.accounts,
   totalCount = data.totalCount.

7. Template renders lightning-datatable with the accounts array and
   the columns definition. Footer shows "Showing X of N Accounts".
```

### Architecture Diagram

```
Lightning Page (App Builder)
        |
        | displayCount property (default 50)
        v
+----------------------+          @wire call
|   myAccounts LWC     |-------------------------> AccountController.getAccounts(50)
|                      |                                      |
|  columns = [...]     |          AccountResult               | clampDisplayCount(50)
|  accounts = []       |<----- { accounts:[...],             |   --> returns 50
|  isLoading = true    |         totalCount: N }             |
|                      |                                      | SOQL: SELECT ... FROM Account
+----------------------+                                      |       WITH USER_MODE
        |                                                     |       ORDER BY Name ASC
        | renders                                             |       LIMIT 50
        v
+----------------------+
|  lightning-datatable |   columns: Name | Industry | Phone | Annual Revenue | Rating
|  key-field="Id"      |
|  data={accounts}     |
|  hide-checkbox-column|
+----------------------+
        |
        v
+----------------------+
|  Footer pill         |   "Showing 12 of 247 Accounts"
+----------------------+
```

---

## File Locations

| Component | Path |
|-----------|------|
| Apex Controller | `/home/user/sf-interview/force-app/main/default/classes/AccountController.cls` |
| Apex Controller Meta | `/home/user/sf-interview/force-app/main/default/classes/AccountController.cls-meta.xml` |
| Apex Test Class | `/home/user/sf-interview/force-app/main/default/classes/AccountControllerTest.cls` |
| LWC JavaScript | `/home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js` |
| LWC Template | `/home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.html` |
| LWC CSS | `/home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.css` |
| LWC Meta XML | `/home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js-meta.xml` |
| LWC Jest Tests | `/home/user/sf-interview/force-app/main/default/lwc/myAccounts/__tests__/myAccounts.test.js` |

---

## Configuration Details

### Datatable Column Definitions

| Label | fieldName | type | Notes |
|-------|-----------|------|-------|
| Name | `Name` | `text` | Standard Account Name field |
| Industry | `Industry` | `text` | Standard Account Industry picklist, displayed as text |
| Phone | `Phone` | `phone` | Renders as clickable `tel:` link in supported browsers |
| Annual Revenue | `AnnualRevenue` | `currency` | Formatted by the platform using the user's locale currency |
| Rating | `Rating` | `text` | Standard Account Rating picklist, displayed as plain text |
| (Id) | `Id` | -- | Used as `key-field` only; not a visible column |

No inline editing, row selection, row actions, sorting, searching, or pagination is configured.

### App Builder Property Configuration

| Property Name | Label | Type | Default | Valid Range |
|---------------|-------|------|---------|-------------|
| `title` | Component Title | String | "My Accounts" | Any string |
| `displayCount` | Accounts to Display | Integer | 50 | 1--50 (server-clamped) |

Both properties are available on `lightning__AppPage`, `lightning__RecordPage`, and `lightning__HomePage` targets.

### Apex Clamping Logic

| Input Value | Output (LIMIT applied) |
|-------------|------------------------|
| `null` | 50 |
| `0` or negative | 50 |
| `1` to `50` | Value as provided |
| `51` or greater | 50 |

---

## Testing

### Apex Test Coverage

| Class | Key Scenarios Covered |
|-------|-----------------------|
| `AccountController` | Normal request (3 records), null input, below-minimum input, above-maximum input (100 with 51 seeded), field population |

| Test Method | Scenario |
|-------------|----------|
| `testGetAccounts_returnsRequestedCount` | Count within valid range returns exactly that many records |
| `testGetAccounts_clampedToMin` | Value of 1 (below new minimum of 1 -- effectively tests floor behavior) |
| `testGetAccounts_clampedToMax` | Value of 100 clamped to 50 when 51 records exist |
| `testGetAccounts_nullCountDefaultsToMin` | Null input clamped to default |
| `testGetAccounts_resultFieldsPopulated` | Returned Account records have non-null `Name` and `Id` |

### LWC Jest Tests -- Known Broken State

The file `/home/user/sf-interview/force-app/main/default/lwc/myAccounts/__tests__/myAccounts.test.js` was NOT updated as part of this task. It contains tests that reference DOM selectors that no longer exist after the card-to-datatable migration. These tests will fail until updated:

| Test | Broken Selector | Reason |
|------|-----------------|--------|
| `renders the correct number of account cards` | `.account-card` | CSS class removed with card loop |
| `shows the Hot rating with correct CSS class` | `.rating-hot` | CSS class removed |
| `shows the Warm rating with correct CSS class` | `.rating-warm` | CSS class removed |

Tests that remain valid (no selector changes needed):
| Test | Status |
|------|--------|
| `displays footer with showing count and total` | Still valid (`.footer-text` retained) |
| `renders error message when wire returns an error` | Still valid (`.slds-text-color_error` retained) |
| `uses the title @api property in the header` | Still valid (`.accounts-title` retained) |

Updating the Jest tests to assert on `lightning-datatable` presence and row content is a recommended follow-up.

---

## Security

### Sharing Model

- `AccountController` is declared `public with sharing` -- respects the running user's record sharing.
- SOQL uses `WITH USER_MODE` -- enforces FLS and object-level security at query time.
- No `Security.stripInaccessible` call is needed because `WITH USER_MODE` handles FLS enforcement in API version 65.0.

### Required Permissions

No new permission sets were created. Users need standard read access to the `Account` object and the following fields:

| Field | API Name |
|-------|----------|
| Account Name | `Name` |
| Industry | `Industry` |
| Phone | `Phone` |
| Annual Revenue | `AnnualRevenue` |
| Rating | `Rating` |
| Record ID | `Id` |

All are standard Account fields available to any profile with Account read access.

---

## Notes and Considerations

### Known Limitations

1. **LWC Jest tests are broken.** Three of the six Jest test cases reference `.account-card`, `.rating-hot`, and `.rating-warm` CSS selectors that were removed. These tests will fail in CI until updated to assert on `lightning-datatable` behavior.

2. **Apex test min-clamp assertions are inconsistent.** `testGetAccounts_clampedToMin` and `testGetAccounts_nullCountDefaultsToMin` still assert a return count of `2`, but the implementation now returns `50` for null/below-1 inputs. With only 10 records seeded, the query returns 10 records and both assertions fail. These should be corrected to assert 10 (or seed more records and assert 50).

3. **No server-side pagination.** The component loads all records up to the cap in a single wire call. For orgs with hundreds of accounts, users will only ever see the top 50 ordered by Name. If broader browsing is needed, pagination or search would need to be added.

4. **Currency column uses platform locale.** The `type: 'currency'` column in `lightning-datatable` renders using the org's default currency symbol and the user's locale. It does not use a custom format string.

5. **Datatable is read-only.** `hide-checkbox-column` is set and no `onrowaction`, `onsave`, or `draftValues` attributes are configured. The table is intentionally display-only.

### Future Enhancements

- Update Jest tests to cover the `lightning-datatable` element and remove card-selector assertions.
- Fix the two inconsistent Apex test assertions for null/below-minimum inputs.
- Consider adding column sorting (`sorted-by`, `onsort` handler) if users need to reorder the table client-side.
- Consider wiring `displayCount` to a user preference stored in a custom setting if per-user configuration is needed beyond App Builder properties.

### Dependencies

| Dependency | Type | Notes |
|------------|------|-------|
| `Account` standard object | Salesforce Platform | Required; standard read access needed |
| `lightning-datatable` | Base Component | Ships with the platform; no installation needed |
| `AccountController.getAccounts` | Apex Wire Method | Must be deployed before the LWC can render data |

---

## Change History

| Date | Author | Change Description |
|------|--------|--------------------|
| 2026-02-27 | Documentation Agent | Initial creation -- documents card-to-datatable migration and 50-record cap update |
