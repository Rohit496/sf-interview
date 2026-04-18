# Code Review Agent Memory

## Project-Specific Patterns

### Intentional Design Decisions (Not Bugs)

- `handleSaveResults` uses `System.debug(LoggingLevel.ERROR, ...)` — documented as a TODO to replace with a custom logging framework. Flag as WARNING, not CRITICAL.
- `AccessLevel.SYSTEM_MODE` in test classes is acceptable when test user may lack FLS on newly deployed custom fields. The class-level comment explains the justification. Do not flag as CRITICAL.
- The `hasRun` legacy property on AccountTriggerHandler is intentionally kept for backward compatibility — documented with comment. Do not flag.
- `@TestSetup` absence is a WARNING, not CRITICAL, when tests are short-lived and each test creates minimal data.

### Known False Positives to Avoid

- Static recursion flags (`hasRunBefore`, `hasRunAfter`) being `@TestVisible` and reset in tests is an intentional and correct pattern for this project. Do not flag.

## LWC Best Practices (API 65.0)

- `if:true` / `if:false` template directives are DEPRECATED at API 65.0. Use `lwc:if` / `lwc:else` / `lwc:elseif` instead. Flag as WARNING (deprecated but still functional).
- `Intl.DateTimeFormat` with hardcoded `'en-US'` locale ignores Salesforce user locale settings — flag as WARNING.

## LWC Custom Type Patterns (lightning-datatable)

- Valid to use a single `template` with `standardCellLayout: true` plus an internal show/hide toggle for inline edit — the design spec's two-template pattern (`template` + `editTemplate`) is an alternative approach, not the only correct one. Do not flag single-template implementations as defective.
- `static _instanceCounter` on LWC class is the correct deterministic GUID strategy for `itemregister` pattern — do not flag as missing crypto/uuid.
- Dispatch `itemregister` from `connectedCallback`, never `renderedCallback` — to avoid repeated registration on re-renders.
- Draft merge in `handleSave` must combine `this.draftValues` (picklist/custom-type drafts) with `event.detail.draftValues` (standard-column drafts) via a Map keyed by Id to avoid losing edits from either source.
- `@track` properties accessed directly in Jest tests (`el.draftValues`) is standard LWC Jest practice — flag as WARNING (not CRITICAL); it works because Jest does not enforce shadow encapsulation.

## Common Issues Found

- Design spec vs implementation discrepancy: always check Task Subject / other field values against design-requirements.md. Developers sometimes use a slightly different string constant than specified.
- `handleRefresh` with `refreshApex` call inside try/finally but no catch: user gets no toast if refresh fails. Recurring WARNING pattern.
- See `common-issues.md` for detailed notes.
