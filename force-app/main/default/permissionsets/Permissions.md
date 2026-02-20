# My Accounts Component — Permission Sets

## Overview

The **My Accounts** LWC component requires two permission sets that work together.
Neither set grants modify/delete access; they are read-only by design.

---

## Permission Sets

### 1. `MyAcct_Account_Read`

| Property    | Value                                              |
| ----------- | -------------------------------------------------- |
| Label       | MyAcct Account Read                                |
| License     | Salesforce                                         |
| Object      | Account (read only)                                |
| Fields      | Industry, Phone, AnnualRevenue, Rating (read only) |

**Purpose:** Grants read access to the Account object and the four fields surfaced by the component.

---

### 2. `MyAcct_AccountController_Execute`

| Property | Value                         |
| -------- | ----------------------------- |
| Label    | MyAcct AccountController Execute |
| License  | Salesforce                    |
| Class    | AccountController (enabled)   |

**Purpose:** Allows users to invoke the `AccountController` Apex class via `@AuraEnabled`.

---

## Dependency Mapping

```
MyAcct_AccountController_Execute
        └── requires ──▶  MyAcct_Account_Read
```

Both permission sets must be assigned together for the component to load data.

---

## User Role Assignment Matrix

| User Persona         | MyAcct_Account_Read | MyAcct_AccountController_Execute |
| -------------------- | :-----------------: | :------------------------------: |
| Sales Rep            | ✅                  | ✅                               |
| Sales Manager        | ✅                  | ✅                               |
| Executive / Read-only| ✅                  | ✅                               |
| System Administrator | Built-in            | Built-in                         |

---

## Testing Validation Checklist

- [ ] Create a test user without either permission set — component should show an error/empty state
- [ ] Assign only `MyAcct_Account_Read` — Apex callout fails; component should surface error message
- [ ] Assign both permission sets — component loads and displays accounts correctly
- [ ] Verify the `displayCount` property clamps correctly (set to 1 → shows 2; set to 10 → shows 5)
- [ ] Confirm no Account records are modified (read-only validation)
