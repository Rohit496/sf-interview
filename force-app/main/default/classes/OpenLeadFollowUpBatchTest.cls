/**
 * @description Test class for OpenLeadFollowUpBatch.
 *              Business logic in execute() is tested by calling the method directly,
 *              bypassing the start() QueryLocator whose CreatedDate filter cannot be
 *              reliably satisfied in test context without real committed data.
 *              start() and finish() are covered separately via Database.executeBatch
 *              with the default 60-day threshold (no test Leads qualify, so execute
 *              is skipped and finish runs cleanly).
 */
@IsTest
private class OpenLeadFollowUpBatchTest {

    private static final String TASK_SUBJECT = 'Close the Lead or mark it Bogus';
    private static final Integer TASK_DUE_DAYS = 2;

    @TestSetup
    static void makeData() {
        insert new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'StaleA', Company = 'Stale Corp', Status = 'Open - Not Contacted'),
            new Lead(FirstName = 'Jane', LastName = 'StaleB', Company = 'Old Inc', Status = 'Working - Contacted'),
            new Lead(FirstName = 'New', LastName = 'Recent', Company = 'Fresh LLC', Status = 'Open - Not Contacted')
        };
    }

    // ─── execute() Tests ──────────────────────────────────────────────────────

    @IsTest
    static void executorCreatesOneTaskPerLead() {
        List<Lead> leads = [SELECT Id, OwnerId FROM Lead WHERE IsConverted = false];

        Test.startTest();
        new OpenLeadFollowUpBatch().execute(null, leads);
        Test.stopTest();

        Set<Id> leadIds = new Map<Id, Lead>(leads).keySet();
        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate
            FROM Task
            WHERE WhoId IN :leadIds
        ];

        Assert.areEqual(leads.size(), tasks.size(), 'Should create one task per lead');
        for (Task t : tasks) {
            Assert.areEqual(TASK_SUBJECT, t.Subject, 'Task subject should match');
            Assert.areEqual(
                Date.today().addDays(TASK_DUE_DAYS),
                t.ActivityDate,
                'Task due date should be 2 days from today'
            );
        }
    }

    @IsTest
    static void taskIsAssignedToLeadOwner() {
        Lead lead = [SELECT Id, OwnerId FROM Lead WHERE LastName = 'StaleA' LIMIT 1];

        Test.startTest();
        new OpenLeadFollowUpBatch().execute(null, new List<Lead>{ lead });
        Test.stopTest();

        Task t = [SELECT OwnerId FROM Task WHERE WhoId = :lead.Id LIMIT 1];
        Assert.areEqual(lead.OwnerId, t.OwnerId, 'Task should be assigned to the Lead owner');
    }

    @IsTest
    static void executorHandlesEmptyScope() {
        Test.startTest();
        new OpenLeadFollowUpBatch().execute(null, new List<Lead>());
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE Subject = :TASK_SUBJECT];
        Assert.isTrue(tasks.isEmpty(), 'No tasks should be created for an empty scope');
    }

    // ─── start() and finish() Tests ───────────────────────────────────────────

    @IsTest
    static void startReturnsNonNullQueryLocator() {
        Test.startTest();
        Database.QueryLocator ql = new OpenLeadFollowUpBatch().start(null);
        Test.stopTest();

        Assert.isNotNull(ql, 'start() should return a non-null QueryLocator');
    }

    @IsTest
    static void batchRunsToCompletionWithNoQualifyingLeads() {
        // Default threshold (60 days ago) — no test Leads qualify; covers start() and finish()
        Test.startTest();
        Database.executeBatch(new OpenLeadFollowUpBatch());
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE Subject = :TASK_SUBJECT];
        Assert.isTrue(tasks.isEmpty(), 'No tasks should be created when no Leads exceed the 60-day threshold');
    }

    // ─── Constructor Tests ────────────────────────────────────────────────────

    @IsTest
    static void defaultConstructorSetsThresholdTo60DaysAgo() {
        OpenLeadFollowUpBatch batchJob = new OpenLeadFollowUpBatch();
        Assert.areEqual(
            Date.today().addDays(-60),
            batchJob.queryThresholdDate,
            'Default threshold should be 60 days ago'
        );
    }

    @IsTest
    static void customConstructorPreservesThresholdDate() {
        Date customDate = Date.today().addDays(-30);
        OpenLeadFollowUpBatch batchJob = new OpenLeadFollowUpBatch(customDate);
        Assert.areEqual(customDate, batchJob.queryThresholdDate, 'Custom threshold date should be preserved');
    }
}
