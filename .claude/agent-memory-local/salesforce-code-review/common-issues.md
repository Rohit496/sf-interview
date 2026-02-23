# Common Issues Found in Reviews

## Design Spec vs Implementation Discrepancies
- In Account Health Indicator (Feb 2026): Design spec specified Task Subject as `"Review At Risk Account: " + Account.Name`. Developer originally used constant `'Review Account Health - At Risk'` (no Account name concatenation). Fixed in re-review: handler now uses `AT_RISK_TASK_SUBJECT_PREFIX = 'Review At Risk Account: '` + `acc.Name`; test asserts `AT_RISK_SUBJECT_PREFIX + acc.Name` dynamically. RESOLVED — APPROVED.

## LWC Deprecation Flags
- `if:true` / `if:false` are deprecated at API 65.0+. Use `lwc:if`, `lwc:elseif`, `lwc:else` instead.
- Hardcoded locale `'en-US'` in `Intl.DateTimeFormat` should use `undefined` or user locale.

## Apex Patterns
- `System.debug` in production code is a recurring WARNING. Always note the TODO comment if present — it signals developer awareness.
- `Database.insert(list, false, AccessLevel.USER_MODE)` is the correct pattern for partial-success DML with USER_MODE. Good to see this used correctly.
- When a private handler constant (e.g., `AT_RISK_TASK_SUBJECT_PREFIX`) is used in both handler and test class, the test class must duplicate the string literal unless the constant is made `@TestVisible`. Flag as SUGGESTION: make such constants `@TestVisible` to avoid test drift.
- SOQL `WHERE Name IN :lowercaseSet` relies on Salesforce's implicit case-insensitive string comparison. This works in practice but should have a code comment explaining the reliance. Not a bug — flag as WARNING if no comment present.

## Duplicate Prevention Pattern (Accounts, Feb 2026)
- Correct approach: collect `incomingNamesLower` set → single SOQL with `WHERE Name IN :set AND Id NOT IN :excludeIds` → post-process with `toLowerCase()` → `seenInBatchLower` set for within-batch detection.
- `addError()` must be called on the `Name` field (not record-level) for inline UI error display.
- `DUPLICATE_NAME_ERROR` constant must be `@TestVisible` so test assertions can reference it without magic strings.
- Self-update false positive: `excludeIds = oldMap.keySet()` correctly excludes records being updated from the DB check.
