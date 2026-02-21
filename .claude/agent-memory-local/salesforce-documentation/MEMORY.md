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
- Account: AccountTriggerHandler (extended with Health Rating + At Risk Task features)
  - Fields: Health_Rating__c (Picklist), Health_Evaluated_Date__c (DateTime)
  - Permission Set: AccountHealth_Fields
  - LWC: accountHealthIndicator (wire-based badge card on record page)
- Lead: LeadTriggerHandler (contact metrics: Days_Since_Last_Contact__c, Is_Overdue__c)
  - Fields: Last_Contacted_Date__c (Date), Days_Since_Last_Contact__c (Number), Is_Overdue__c (Checkbox)
  - Fields (admin only): Primary__c (Picklist), ProductInterest__c (Picklist)
  - Permission Set: LeadMgmt_Lead_FollowUp_Fields
  - Controller: OverdueLeadsController (cacheable AuraEnabled, stripInaccessible, USER_MODE)
  - LWC: overdueLeads (NavigationMixin table, multi-page-target)
  - Overdue threshold: 7 days constant OVERDUE_THRESHOLD_DAYS
  - Single hasRun guard (not separate before/after) because handler only uses before contexts

## Multi-Feature Projects
- When a project has multiple features, create one doc per feature plus a docs/README.md index
- README.md should include: full component inventory table, shared conventions table, architecture overview diagram, permission set assignment guide, and known project-wide limitations
