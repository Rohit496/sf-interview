# Account-to-Contact Billing Address Sync

## Overview

When an Account's billing address changes, all related Contacts' mailing addresses are automatically synced to match. The sync triggers on any change to the five billing address fields: BillingStreet, BillingCity, BillingState, BillingPostalCode, and BillingCountry.

---

## Components

| Component                       | Type       | Purpose                                                  |
| ------------------------------- | ---------- | -------------------------------------------------------- |
| `AccountTrigger.trigger`        | Trigger    | Already wired — no changes needed                        |
| `AccountTriggerHandler.cls`     | Apex Class | `syncRelatedRecords()` and `hasAddressChanged()` methods |
| `AccountTriggerHandlerTest.cls` | Test Class | 8 test methods covering the sync logic                   |

---

## How It Works

1. **Trigger fires** — `AccountTrigger` delegates to `AccountTriggerHandler` in the `afterUpdate` context.
2. **Detect changes** — `syncRelatedRecords(List<Account> newAccounts, Map<Id, Account> oldMap)` iterates through updated Accounts and calls the private helper `hasAddressChanged(Account newAcc, Account oldAcc)` to detect billing address changes.
3. **Query related Contacts** — For Accounts with changed billing addresses, all related Contacts are queried using `WITH USER_MODE`.
4. **Copy fields with dirty-checking** — The five billing fields are copied to the corresponding mailing fields on each Contact. Per-Contact dirty-checking ensures only actually changed Contacts are included in the DML.
5. **Partial-success DML** — Uses `Database.update(contactsToUpdate, false, AccessLevel.USER_MODE)` for partial-success handling.
6. **Error logging** — Results are passed to `handleSaveResults` for error logging.

---

## Field Mapping

| Account Field     | Contact Field     |
| ----------------- | ----------------- |
| BillingStreet     | MailingStreet     |
| BillingCity       | MailingCity       |
| BillingState      | MailingState      |
| BillingPostalCode | MailingPostalCode |
| BillingCountry    | MailingCountry    |

---

## Architecture

- **One-Trigger-Per-Object** pattern — all logic lives in `AccountTriggerHandler`
- **Sharing**: Handler class uses `with sharing`
- **Security**: SOQL uses `WITH USER_MODE`, DML uses `AccessLevel.USER_MODE`
- **Bulk-safe**: Handles 200+ Accounts with multiple Contacts each
- **Recursion-safe**: Protected by `hasRunAfter` static guard

---

## Test Methods (8 total)

| #   | Test Method                                                    | Scenario                                       |
| --- | -------------------------------------------------------------- | ---------------------------------------------- |
| 1   | `afterUpdate_billingAddressChanged_syncsContactMailingAddress` | Single Account, single Contact sync            |
| 2   | `afterUpdate_billingAddressChanged_syncsMultipleContacts`      | Single Account, multiple Contacts sync         |
| 3   | `afterUpdate_billingAddressUnchanged_contactsNotUpdated`       | No sync when billing address is unchanged      |
| 4   | `afterUpdate_billingAddressChanged_noContacts_noError`         | Graceful handling when Account has no Contacts |
| 5   | `afterUpdate_partialBillingChange_syncsContact`                | Partial billing change triggers full sync      |
| 6   | `afterUpdate_billingAddressCleared_syncsNulls`                 | Null clearing propagates to Contacts           |
| 7   | `afterUpdate_bulkAccounts_syncsAllContacts`                    | 200 Accounts × 2 Contacts = 400 syncs          |
| 8   | `afterUpdate_mixedBatch_onlyChangedAccountsSynced`             | Mixed batch: only changed Accounts sync        |

---

## Known Considerations

- **State/Country Picklists**: The org has State/Country Picklists enabled. Test data avoids `BillingState` and `BillingCountry` fields due to custom picklist integration values. The handler code supports all 5 fields; only test data is limited to Street, City, and PostalCode.
- **Code Coverage**: `AccountTriggerHandler` has **92% coverage** (165/179 lines). The uncovered lines are in the State/Country sync branches (lines 475–484) since tests can't set those fields with the org's picklist configuration.

---

## API Version

- **65.0**

---

## Deployment

- **Org**: `rohitdotnet75.bb85a2297fcd@agentforce.com`
- **Test Results**: All 34 tests passing (26 existing + 8 new address sync tests)
