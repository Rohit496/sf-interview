/**
 * @description Trigger handler for the Account object.
 *              Separates trigger logic from the trigger itself following the
 *              One-Trigger-Per-Object pattern.
 *
 *              Each context method receives bulkified collections — never
 *              perform SOQL or DML inside loops.
 *
 *              Recursion is prevented via the static {@link hasRun} flag;
 *              reset it in tests when simulating re-entrant scenarios.
 *
 * @see AccountTrigger
 */
public with sharing class AccountTriggerHandler {

    // ─── Recursion Guard ─────────────────────────────────────────────────────

    /**
     * @description Prevents recursive trigger execution within a single transaction.
     *              Set to true after the first handler invocation; reset per test
     *              using `AccountTriggerHandler.hasRun = false;` when needed.
     */
    @TestVisible
    private static Boolean hasRun = false;

    // ─── Context Dispatchers ─────────────────────────────────────────────────

    /**
     * @description Executes before-insert logic. Fires synchronously before
     *              records are written to the database, allowing field defaults
     *              and validations to be applied without a DML statement.
     * @param newAccounts List of Account records being inserted (Trigger.new).
     */
    public void beforeInsert(List<Account> newAccounts) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        setAccountDefaults(newAccounts);
        validateAccounts(newAccounts, null);
    }

    /**
     * @description Executes before-update logic. Fires synchronously before
     *              records are written to the database, allowing field changes
     *              and cross-field validations against the previous values.
     * @param newAccounts List of updated Account records (Trigger.new).
     * @param oldMap      Map of Account Id → old record state (Trigger.oldMap).
     */
    public void beforeUpdate(List<Account> newAccounts, Map<Id, Account> oldMap) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        validateAccounts(newAccounts, oldMap);
    }

    /**
     * @description Executes after-insert logic. Fires after records are
     *              committed; safe to create related records or enqueue async work.
     * @param newAccounts List of inserted Account records with Ids populated (Trigger.new).
     * @param newMap      Map of Account Id → new record (Trigger.newMap).
     */
    public void afterInsert(List<Account> newAccounts, Map<Id, Account> newMap) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        createRelatedRecords(newAccounts);
        enqueueAsyncWork(newMap.keySet());
    }

    /**
     * @description Executes after-update logic. Fires after records are
     *              committed; use to cascade changes to related records
     *              or notify external systems.
     * @param newAccounts List of updated Account records (Trigger.new).
     * @param newMap      Map of Account Id → new record (Trigger.newMap).
     * @param oldMap      Map of Account Id → old record state (Trigger.oldMap).
     */
    public void afterUpdate(List<Account> newAccounts, Map<Id, Account> newMap, Map<Id, Account> oldMap) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        syncRelatedRecords(newAccounts, oldMap);
        enqueueAsyncWork(newMap.keySet());
    }

    // ─── Before-Insert Helpers ───────────────────────────────────────────────

    /**
     * @description Applies default field values on new Account records.
     *              Called in before-insert so no extra DML is needed.
     * @param newAccounts Accounts being inserted.
     */
    private void setAccountDefaults(List<Account> newAccounts) {
        for (Account acc : newAccounts) {
            // TODO: Set default field values, e.g.:
            //   if (acc.Rating == null) { acc.Rating = 'Warm'; }
        }
    }

    /**
     * @description Validates Account fields before write.
     *              Pass {@code null} for {@code oldMap} on insert.
     * @param newAccounts Accounts being saved.
     * @param oldMap      Previous field values; null during insert.
     */
    private void validateAccounts(List<Account> newAccounts, Map<Id, Account> oldMap) {
        for (Account acc : newAccounts) {
            Account oldAcc = (oldMap != null) ? oldMap.get(acc.Id) : null;

            // TODO: Add field validation, e.g.:
            //   if (String.isBlank(acc.Phone)) {
            //       acc.Phone.addError('Phone is required for this account type.');
            //   }

            // TODO: Add cross-field validation comparing acc vs oldAcc, e.g.:
            //   if (oldAcc != null && acc.AnnualRevenue < oldAcc.AnnualRevenue) {
            //       acc.AnnualRevenue.addError('Annual Revenue cannot decrease.');
            //   }
        }
    }

    // ─── After-Insert Helpers ────────────────────────────────────────────────

    /**
     * @description Creates records related to newly inserted Accounts.
     *              Collects all inserts and performs a single bulkified DML call.
     * @param newAccounts Newly inserted Accounts (Ids are available).
     */
    private void createRelatedRecords(List<Account> newAccounts) {
        // TODO: Build related records in bulk, e.g.:
        //   List<Contact> contacts = new List<Contact>();
        //   for (Account acc : newAccounts) {
        //       contacts.add(new Contact(AccountId = acc.Id, LastName = 'Primary'));
        //   }
        //   if (!contacts.isEmpty()) {
        //       List<Database.SaveResult> results =
        //           Database.insert(contacts, false, AccessLevel.USER_MODE);
        //       handleSaveResults(results, contacts);
        //   }
    }

    // ─── After-Update Helpers ────────────────────────────────────────────────

    /**
     * @description Cascades field changes from updated Accounts to related records.
     *              Query related records once, update in bulk.
     * @param newAccounts Updated Accounts.
     * @param oldMap      Previous field values for change detection.
     */
    private void syncRelatedRecords(List<Account> newAccounts, Map<Id, Account> oldMap) {
        // Collect only the Ids where a relevant field actually changed
        Set<Id> changedIds = new Set<Id>();
        for (Account acc : newAccounts) {
            Account oldAcc = oldMap.get(acc.Id);

            // TODO: Add field-change guards, e.g.:
            //   if (acc.Industry != oldAcc.Industry) {
            //       changedIds.add(acc.Id);
            //   }
        }

        if (changedIds.isEmpty()) {
            return;
        }

        // TODO: Query related records and apply updates, e.g.:
        //   List<Opportunity> opps = [
        //       SELECT Id, StageName
        //       FROM Opportunity
        //       WHERE AccountId IN :changedIds
        //       WITH USER_MODE
        //   ];
        //   for (Opportunity opp : opps) { ... }
        //   Database.update(opps, false, AccessLevel.USER_MODE);
    }

    // ─── Shared Async Helper ─────────────────────────────────────────────────

    /**
     * @description Enqueues a Queueable job for work that must run asynchronously
     *              (e.g., callouts, heavy processing). Implements System.Finalizer
     *              for robust error handling.
     * @param accountIds Set of Account Ids to process.
     */
    private void enqueueAsyncWork(Set<Id> accountIds) {
        if (accountIds.isEmpty()) {
            return;
        }

        // TODO: Replace with a concrete Queueable + Finalizer, e.g.:
        //   System.enqueueJob(new AccountSyncQueueable(accountIds));
    }

    // ─── Result Handling ─────────────────────────────────────────────────────

    /**
     * @description Logs any failed DML results without throwing to allow
     *              successful records in the batch to commit.
     * @param results    List of Database.SaveResult from a partial DML call.
     * @param records    The SObject list aligned by index to {@code results}.
     */
    private void handleSaveResults(List<Database.SaveResult> results, List<SObject> records) {
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                for (Database.Error err : results[i].getErrors()) {
                    // TODO: Route to a custom error logging framework or platform event
                    //   instead of relying on debug logs in production.
                    System.debug(
                        LoggingLevel.ERROR,
                        'DML failed for record Id: ' + records[i].Id +
                        ' | Code: ' + err.getStatusCode() +
                        ' | Message: ' + err.getMessage()
                    );
                }
            }
        }
    }
}
