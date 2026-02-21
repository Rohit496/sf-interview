# Common Issues Found in Reviews

## Design Spec vs Implementation Discrepancies
- In Account Health Indicator (Feb 2026): Design spec specified Task Subject as `"Review At Risk Account: " + Account.Name`. Developer originally used constant `'Review Account Health - At Risk'` (no Account name concatenation). Fixed in re-review: handler now uses `AT_RISK_TASK_SUBJECT_PREFIX = 'Review At Risk Account: '` + `acc.Name`; test asserts `AT_RISK_SUBJECT_PREFIX + acc.Name` dynamically. RESOLVED — APPROVED.

## LWC Deprecation Flags
- `if:true` / `if:false` are deprecated at API 65.0+. Use `lwc:if`, `lwc:elseif`, `lwc:else` instead.
- Hardcoded locale `'en-US'` in `Intl.DateTimeFormat` should use `undefined` or user locale.

## Apex Patterns
- `System.debug` in production code is a recurring WARNING. Always note the TODO comment if present — it signals developer awareness.
- `Database.insert(list, false, AccessLevel.USER_MODE)` is the correct pattern for partial-success DML with USER_MODE. Good to see this used correctly.
