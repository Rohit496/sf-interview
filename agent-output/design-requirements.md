===============================================================================
                    DESIGN REQUIREMENTS
===============================================================================

TARGET: WHAT USER REQUESTED:
Create a duplicate prevention trigger on the Account object that blocks
insert and update of Account records when a duplicate Account Name already
exists (case-insensitive). Follow the existing handler class pattern.
Use API version 65.0.

-------------------------------------------------------------------------------
                    ADMIN WORK (salesforce-admin)
-------------------------------------------------------------------------------

No admin work required for this request.

(No new fields, objects, validation rules, or declarative components were
requested. The Account object and AccountTrigger already exist.)

-------------------------------------------------------------------------------
                    DEVELOPMENT WORK (salesforce-developer)
-------------------------------------------------------------------------------

Modify the existing AccountTriggerHandler to add duplicate Account Name
detection logic:

  - Object: Account
  - Trigger events: before insert, before update (trigger already exists)
  - Duplicate detection field: Account Name (standard Name field)
  - Matching: Case-insensitive (e.g., "Acme Corp" = "acme corp")
  - Scope: Check against ALL existing Account records in the org
  - On update: Exclude the current record being updated from the duplicate check
  - Error message: "A duplicate Account with this name already exists."
  - Behavior: Use addError() on the record to prevent save

  Existing files to modify:
  - force-app/main/default/classes/AccountTriggerHandler.cls

  Existing trigger file (NO changes needed -- already handles before insert
  and before update):
  - force-app/main/default/triggers/AccountTrigger.trigger

  Implementation notes:
  - The handler already has a validateAccounts(List<Account>, Map<Id,Account>)
    method called in both beforeInsert and beforeUpdate -- the duplicate
    detection logic belongs there (or in a new private method called from it).
  - Must be bulkified: collect all Names from Trigger.new, query existing
    Accounts in a single SOQL query, then compare.
  - Also check for duplicates within the same batch (two records in the same
    insert with the same Name).
  - Use case-insensitive comparison (e.g., compare lowercased values).
  - Use WITH USER_MODE for SOQL queries per project conventions.
  - On update, exclude current record Ids from the SOQL results.

-------------------------------------------------------------------------------
                    EXECUTION ORDER
-------------------------------------------------------------------------------

1. Developer work only -- modify AccountTriggerHandler.cls to add duplicate
   detection logic inside the existing validateAccounts method (or a new
   helper method called from it).

No dependencies on Admin work. No new metadata to create first.

-------------------------------------------------------------------------------
                    PROMPTS FOR SPECIALIST AGENTS
-------------------------------------------------------------------------------

PROMPT FOR salesforce-admin:
"""
No admin work required for this request.
"""

PROMPT FOR salesforce-developer:
"""
Modify the existing AccountTriggerHandler class to add duplicate Account
Name prevention logic. Do NOT modify AccountTrigger.trigger -- it already
handles before insert and before update.

File to modify:
  force-app/main/default/classes/AccountTriggerHandler.cls

Requirements:
1. Detect duplicate Account Names on before insert and before update.
2. Matching must be case-insensitive ("Acme Corp" matches "acme corp").
3. Check against ALL existing Account records in the org.
4. On update, exclude the current record's Id from the duplicate check
   so renaming an Account to its own current name does not trigger a false
   positive.
5. Also detect duplicates within the same trigger batch (e.g., two records
   in one insert with the same Name).
6. When a duplicate is found, call addError() on the record with the
   message: "A duplicate Account with this name already exists."
7. The logic should be bulkified -- collect all Names, run one SOQL query,
   then iterate.
8. Use WITH USER_MODE for the SOQL query.
9. The existing validateAccounts method is called in both beforeInsert and
   beforeUpdate. Add the duplicate logic there or in a new private helper
   method called from validateAccounts.
10. Follow existing code patterns: with sharing, named constants for error
    messages, Database methods where applicable, API version 65.0.
11. Do not add validation rules, permission sets, test classes, or any
    work not listed above.
"""

===============================================================================
