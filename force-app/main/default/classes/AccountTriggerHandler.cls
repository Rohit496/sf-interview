/**
 * @description Trigger handler for the Account object.
 *              Separates trigger logic from the trigger itself following the
 *              One-Trigger-Per-Object pattern.
 *
 *              Each context method receives bulkified collections — never
 *              perform SOQL or DML inside loops.
 *
 *              Recursion is prevented via separate static flags for before/after
 *              contexts; reset them in tests when simulating re-entrant scenarios.
 *
 * @see AccountTrigger
 */
public with sharing class AccountTriggerHandler {

    // ─── Health Rating Constants ────────────────────────────────────────────

    /** @description Enum representing Account Health Rating picklist values. */
    public enum HealthRating {
        GOOD,
        AVERAGE,
        AT_RISK
    }

    /** @description Maps HealthRating enum values to their picklist API strings. */
    private static final Map<HealthRating, String> HEALTH_RATING_LABELS = new Map<HealthRating, String>{
        HealthRating.GOOD     => 'Good',
        HealthRating.AVERAGE  => 'Average',
        HealthRating.AT_RISK  => 'At Risk'
    };

    /** @description Revenue threshold for Good rating (exclusive). */
    private static final Decimal REVENUE_HIGH_THRESHOLD = 10000000;
    /** @description Revenue threshold for At Risk rating (exclusive). */
    private static final Decimal REVENUE_LOW_THRESHOLD  = 1000000;
    /** @description Employee threshold for Good rating (exclusive). */
    private static final Integer EMPLOYEES_HIGH_THRESHOLD = 500;
    /** @description Employee threshold for At Risk rating (exclusive). */
    private static final Integer EMPLOYEES_LOW_THRESHOLD  = 100;

    private static final String AT_RISK_TASK_SUBJECT_PREFIX = 'Review At Risk Account: ';
    private static final Integer AT_RISK_TASK_DUE_DAYS = 3;

    // ─── Recursion Guards ───────────────────────────────────────────────────

    /**
     * @description Prevents recursive before-trigger execution within a single transaction.
     */
    @TestVisible
    private static Boolean hasRunBefore = false;

    /**
     * @description Prevents recursive after-trigger execution within a single transaction.
     */
    @TestVisible
    private static Boolean hasRunAfter = false;

    /**
     * @description Legacy recursion guard kept for backward compatibility.
     *              Maps to hasRunBefore for existing code that references it.
     */
    @TestVisible
    private static Boolean hasRun {
        get { return hasRunBefore && hasRunAfter; }
        set {
            hasRunBefore = value;
            hasRunAfter = value;
        }
    }

    // ─── Context Dispatchers ─────────────────────────────────────────────────

    /**
     * @description Executes before-insert logic. Fires synchronously before
     *              records are written to the database, allowing field defaults
     *              and validations to be applied without a DML statement.
     * @param newAccounts List of Account records being inserted (Trigger.new).
     */
    public void beforeInsert(List<Account> newAccounts) {
        if (hasRunBefore) {
            return;
        }
        hasRunBefore = true;

        setAccountDefaults(newAccounts);
        validateAccounts(newAccounts, null);
        evaluateHealthRating(newAccounts, null);
    }

    /**
     * @description Executes before-update logic. Fires synchronously before
     *              records are written to the database, allowing field changes
     *              and cross-field validations against the previous values.
     * @param newAccounts List of updated Account records (Trigger.new).
     * @param oldMap      Map of Account Id → old record state (Trigger.oldMap).
     */
    public void beforeUpdate(List<Account> newAccounts, Map<Id, Account> oldMap) {
        if (hasRunBefore) {
            return;
        }
        hasRunBefore = true;

        validateAccounts(newAccounts, oldMap);
        evaluateHealthRating(newAccounts, oldMap);
    }

    /**
     * @description Executes after-insert logic. Fires after records are
     *              committed; safe to create related records or enqueue async work.
     * @param newAccounts List of inserted Account records with Ids populated (Trigger.new).
     * @param newMap      Map of Account Id → new record (Trigger.newMap).
     */
    public void afterInsert(List<Account> newAccounts, Map<Id, Account> newMap) {
        if (hasRunAfter) {
            return;
        }
        hasRunAfter = true;

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
        if (hasRunAfter) {
            return;
        }
        hasRunAfter = true;

        syncRelatedRecords(newAccounts, oldMap);
        createAtRiskTasks(newAccounts, oldMap);
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

    // ─── Health Rating Evaluation ──────────────────────────────────────────

    /**
     * @description Evaluates the Health_Rating__c field on Account records based on
     *              AnnualRevenue and NumberOfEmployees thresholds. On insert, always
     *              evaluates. On update, only evaluates when AnnualRevenue or
     *              NumberOfEmployees has changed. Stamps Health_Evaluated_Date__c
     *              with the current DateTime whenever the rating is set.
     *
     *              Rating rules:
     *              - Good:    AnnualRevenue > $10M AND NumberOfEmployees > 500
     *              - At Risk: AnnualRevenue < $1M AND NumberOfEmployees < 100
     *              - Average: Everything else (default)
     *
     * @param newAccounts Accounts being inserted or updated (Trigger.new).
     * @param oldMap      Previous field values; null during insert.
     */
    @TestVisible
    private void evaluateHealthRating(List<Account> newAccounts, Map<Id, Account> oldMap) {
        for (Account acc : newAccounts) {
            // On update, only re-evaluate if relevant fields changed
            if (oldMap != null) {
                Account oldAcc = oldMap.get(acc.Id);
                if (oldAcc != null
                    && acc.AnnualRevenue == oldAcc.AnnualRevenue
                    && acc.NumberOfEmployees == oldAcc.NumberOfEmployees) {
                    continue;
                }
            }

            Decimal revenue = acc.AnnualRevenue != null ? acc.AnnualRevenue : 0;
            Integer employees = acc.NumberOfEmployees != null ? acc.NumberOfEmployees : 0;

            if (revenue > REVENUE_HIGH_THRESHOLD && employees > EMPLOYEES_HIGH_THRESHOLD) {
                acc.Health_Rating__c = HEALTH_RATING_LABELS.get(HealthRating.GOOD);
            } else if (revenue < REVENUE_LOW_THRESHOLD && employees < EMPLOYEES_LOW_THRESHOLD) {
                acc.Health_Rating__c = HEALTH_RATING_LABELS.get(HealthRating.AT_RISK);
            } else {
                // Average: covers all combinations not meeting Good or At Risk thresholds
                // (e.g., high revenue with low employees, or mid-range values for both)
                acc.Health_Rating__c = HEALTH_RATING_LABELS.get(HealthRating.AVERAGE);
            }

            acc.Health_Evaluated_Date__c = DateTime.now();
        }
    }

    // ─── At Risk Task Creation ──────────────────────────────────────────────

    /**
     * @description Creates a high-priority follow-up Task for each Account whose
     *              Health_Rating__c changed to 'At Risk' during an update.
     *              Uses Database.insert with allOrNone=false so partial failures
     *              do not block the entire batch.
     * @param newAccounts Updated Accounts (Trigger.new).
     * @param oldMap      Previous field values (Trigger.oldMap).
     */
    @TestVisible
    private void createAtRiskTasks(List<Account> newAccounts, Map<Id, Account> oldMap) {
        List<Task> tasksToInsert = new List<Task>();
        String atRiskLabel = HEALTH_RATING_LABELS.get(HealthRating.AT_RISK);

        for (Account acc : newAccounts) {
            Account oldAcc = oldMap.get(acc.Id);
            if (oldAcc == null) {
                continue;
            }

            // Only create task when rating changed TO 'At Risk' from something else
            if (acc.Health_Rating__c == atRiskLabel
                && oldAcc.Health_Rating__c != atRiskLabel) {

                tasksToInsert.add(new Task(
                    Subject     = AT_RISK_TASK_SUBJECT_PREFIX + acc.Name,
                    ActivityDate = Date.today().addDays(AT_RISK_TASK_DUE_DAYS),
                    OwnerId     = acc.OwnerId,
                    WhatId      = acc.Id,
                    Status      = 'Not Started',
                    Priority    = 'High'
                ));
            }
        }

        if (tasksToInsert.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = Database.insert(
            tasksToInsert, false, AccessLevel.USER_MODE
        );
        handleSaveResults(results, tasksToInsert);
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
