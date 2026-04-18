# Documentation Agent Memory

## Project Conventions

- API version: 65.0 for all metadata
- Package directory: force-app/main/default
- Documentation output directory: docs/ in project root
- Docs filename format: docs/[task-name].md (user-specified name) or docs/[YYYY-MM-DD]-[task-name].md

## Documentation Patterns That Work Well

- Always read ALL source files before writing (fields, classes, triggers, LWC, test class, design requirements)
- Include a Health Rating Logic or equivalent business-rule section with a table of all thresholds/constants
- Include a full test method inventory table (not just a count) so future devs know what is covered
- Architecture diagram using ASCII box-and-arrow style works well in markdown
- Deployment Order note is useful whenever admin metadata must precede Apex

## Project Architecture Patterns

- Trigger pattern: one trigger per object, all logic delegated to a Handler class
- Handler pattern: separate hasRunBefore / hasRunAfter static flags as recursion guards (both @TestVisible)
- DML pattern: Database.insert/update with allOrNone=false, AccessLevel.USER_MODE
- Error logging: handleSaveResults helper with System.debug(LoggingLevel.ERROR) -- flag as limitation in docs
- Enums + label maps instead of magic strings for picklist values
- SOQL uses WITH USER_MODE

## Common Objects Documented

- Account: AccountTriggerHandler (extended with Health Rating + At Risk Task + Duplicate Name Prevention features)
    - Fields: Health_Rating**c (Picklist), Health_Evaluated_Date**c (DateTime)
    - Permission Set: AccountHealth_Fields
    - LWC: accountHealthIndicator (wire-based badge card on record page)
    - Duplicate prevention: preventDuplicateAccounts() -- single SOQL, case-insensitive, within-batch detection, excludeIds on update
- Lead: LeadTriggerHandler (contact metrics: Days_Since_Last_Contact**c, Is_Overdue**c)
    - Fields: Last_Contacted_Date**c (Date), Days_Since_Last_Contact**c (Number), Is_Overdue\_\_c (Checkbox)
    - Fields (admin only): Primary**c (Picklist), ProductInterest**c (Picklist)
    - Permission Set: LeadMgmt_Lead_FollowUp_Fields
    - Controller: OverdueLeadsController (cacheable AuraEnabled, stripInaccessible, USER_MODE)
    - LWC: overdueLeads (NavigationMixin table, multi-page-target)
    - Overdue threshold: 7 days constant OVERDUE_THRESHOLD_DAYS
    - Single hasRun guard (not separate before/after) because handler only uses before contexts
- Case: CaseTriggerHandler (duplicate Case prevention on before insert)
    - No custom fields or permission sets -- uses standard Case fields only
    - Composite key: Subject.toLowerCase() + '|' + AccountId + '|' + ContactId + '|' + Origin
    - Two detection passes: (1) within-batch via keyToCasesMap, (2) DB via single SOQL WITH USER_MODE
    - SOQL uses OR across bind sets (wider net); key match is the precise gate
    - Constants: DUPLICATE_ERROR_MESSAGE, KEY_SEPARATOR
    - 13 test methods; test class resets hasRunBeforeInsert guard between setup DML and test DML

## Agentforce Agent Script Pattern (CaseLookupAgent)

- Agent bundles live in aiAuthoringBundles/ (not agents/) — actual deployed path confirmed by Glob
- Bundle metadata uses <AiAuthoringBundle> element, not <AgentBundle> (guide was wrong; existing Soft_Drink_Agent_Test was the source of truth)
- target convention: <target>AgentName.v6</target>
- .agent file structure: system > config > language > variables > knowledge > start_agent > topic(s)
- start_agent uses topic_selector label pattern; reasoning block uses -> arrow syntax
- Actions inside topic reasoning use @utils.transition and @utils.setVariables built-ins
- Action definitions go in a separate topic-level actions: block (not inside reasoning)
- Action outputs have is_displayable flag — set False for caseFound/errorMessage, True for display fields
- caseId should be declared as output but agent instructed (via system block) to never display it
- Deployment order: Apex class must precede agent bundle (agent references apex://ClassName)
- Known limitation to always document: SOQL-in-loop governor risk when invocable used outside agent

## LWC Service Module Pattern (errorUtils)

- Service modules have no HTML template -- only a .js and .js-meta.xml file (no .html)
- isExposed=false in meta.xml; no targets listed
- Import path for consumers: import { fn } from 'c/errorUtils'
- logErrorToServer is async; wraps imperative Apex call in try/catch that silently discards errors
- Document all error shape priority order in a table (priority 1..N), not just a list
- Key limitation: allOrNone=false with SaveResult[] ignored means insert failures are completely silent
- Legacy if:true vs lwc:if directive difference is worth flagging as a known limitation

## LWC Error Handling Framework (ErrorLogService + errorUtils + errorPanel)

- Error_Log\_\_c object: Auto Number name (ERR-{00000}), sharingModel=ReadWrite, reports+search enabled
- No permission set was created; document that access must be granted separately
- Test class uses SYSTEM_MODE for setup DML but production class exercises USER_MODE (document this contrast)
- errorPanel isInline getter uses `type !== 'banner'` (not strict equality) -- any non-banner value falls through to inline mode; document this in config details

## Apex Retry Callout Pattern (CalloutService)

- Class name: CalloutService (with sharing, no Named Credential or Remote Site Setting shipped with the class)
- Constants: MAX_RETRIES=3, DELAY_MILLIS=5000, both @TestVisible private static final
- Retry triggers: any non-2xx status code OR any Exception -- both paths decrement numAttempts and call sleep()
- sleep() is @TestVisible private static; uses DateTime busy-wait loop -- document CPU governor limitation
- Two inner mock classes in test: FixedResponseMock (stateless) + SequentialResponseMock (stateful list)
- Always document: busy-wait CPU cost, no exception-type discrimination, System.debug-only failure logging
- 10 test methods; includes constants regression test, boundary tests (299 success / 300 failure), and sleep(0) smoke test
- No permission set or admin components; access via standard Apex class security

## Apex HTTP Callout Pattern (JsonPlaceholderService)

- Remote Site Setting path: force-app/main/default/remoteSiteSettings/<Name>.remoteSite-meta.xml
- Pattern: Remote Site Setting + typed PostWrapper response model + @AuraEnabled(cacheable=true) service class
- All constants are @TestVisible private statics; a dedicated constants test method asserts their values (regression guard)
- Test strategy: inner MockHttpCallout implements HttpCalloutMock; accepts any statusCode + body at construction; respond() also asserts correct HTTP method and endpoint constant
- Non-200 path: throws CalloutException inside try block, which is caught and re-thrown as AuraHandledException
- Key limitations to document: no retry logic, cacheable=true stale data risk, callout-after-DML restriction
- No permission set needed; access governed by standard Apex class security
- Deployment order: Remote Site Setting first (required for runtime), then Apex classes

## Tescribe Test Data Library

- Tescribe is a project-wide test utility (without sharing); not tied to a single object or feature
- builder(SObjectType) -- no SOQL; builder(String templateName) -- fires one SOQL on Tescribe_Template\_\_mdt
- Tescribe.mockTemplate @TestVisible static allows bypassing the SOQL in template-path tests
- save() uses allOrNone=true (native insert), not allOrNone=false — document as exception to project DML convention
- README.md requires a Custom Metadata Types section when CMTs are present (separate from Custom Fields table)
- No dedicated test class for Tescribe itself; flag as known limitation

## Multi-Feature Projects

- When a project has multiple features, create one doc per feature plus a docs/README.md index
- README.md should include: full component inventory table, shared conventions table, architecture overview diagram, permission set assignment guide, and known project-wide limitations
- When updating README.md: update Feature Documents table, Custom Metadata Types section (if applicable), Custom Fields section, Apex Classes section, Lightning Web Components section, Permission Sets section, Known Limitations, and Last Updated date
