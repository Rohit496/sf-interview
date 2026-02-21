/**
 * @description Test class for LeadTriggerHandler.
 *              Validates Days_Since_Last_Contact__c and Is_Overdue__c
 *              calculations on insert and update scenarios.
 *
 *              DML operations use AccessLevel.SYSTEM_MODE because the running
 *              test user may lack FLS on newly deployed custom fields.  The
 *              trigger handler runs in before-trigger context (system mode)
 *              so this accurately reflects production behaviour.
 *
 * @see LeadTriggerHandler
 * @see LeadTrigger
 */
@IsTest
private class LeadTriggerHandlerTest {

    private static final String TEST_COMPANY = 'Test Company';
    private static final String TEST_LAST_NAME = 'TestLead';

    // ─── Insert Tests ───────────────────────────────────────────────────────────

    /**
     * @description Verifies that a lead contacted today is NOT marked overdue
     *              and Days_Since_Last_Contact__c is 0.
     */
    @IsTest
    static void insertWithTodayDate_shouldNotBeOverdue() {
        Lead testLead = buildLead(Date.today());

        Test.startTest();
        Database.SaveResult sr = Database.insert(testLead, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Lead insert should succeed');

        Lead result = queryLead(sr.getId());
        Assert.areEqual(0, result.Days_Since_Last_Contact__c,
            'Days since last contact should be 0 for today');
        Assert.isFalse(result.Is_Overdue__c,
            'Lead contacted today should not be overdue');
    }

    /**
     * @description Verifies that a lead contacted 10 days ago IS marked overdue
     *              and Days_Since_Last_Contact__c equals 10.
     */
    @IsTest
    static void insertWithTenDaysAgo_shouldBeOverdue() {
        Lead testLead = buildLead(Date.today().addDays(-10));

        Test.startTest();
        Database.SaveResult sr = Database.insert(testLead, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Lead insert should succeed');

        Lead result = queryLead(sr.getId());
        Assert.areEqual(10, result.Days_Since_Last_Contact__c,
            'Days since last contact should be 10');
        Assert.isTrue(result.Is_Overdue__c,
            'Lead contacted 10 days ago should be overdue');
    }

    /**
     * @description Verifies that inserting a lead without Last_Contacted_Date__c
     *              leaves both calculated fields as null/false.
     */
    @IsTest
    static void insertWithNullDate_shouldHaveNullMetrics() {
        Lead testLead = buildLead(null);

        Test.startTest();
        Database.SaveResult sr = Database.insert(testLead, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Lead insert should succeed');

        Lead result = queryLead(sr.getId());
        Assert.isNull(result.Days_Since_Last_Contact__c,
            'Days since last contact should be null when date is not set');
        Assert.isFalse(result.Is_Overdue__c,
            'Is_Overdue__c should be false when date is not set');
    }

    // ─── Update Tests ───────────────────────────────────────────────────────────

    /**
     * @description Verifies that updating Last_Contacted_Date__c to a date
     *              10 days ago recalculates the metrics correctly.
     */
    @IsTest
    static void updateLastContactedDate_shouldRecalculate() {
        Lead testLead = buildLead(Date.today());
        Database.insert(testLead, AccessLevel.SYSTEM_MODE);

        // Reset recursion guard for the update trigger fire
        LeadTriggerHandler.hasRun = false;

        testLead.Last_Contacted_Date__c = Date.today().addDays(-10);

        Test.startTest();
        Database.SaveResult sr = Database.update(testLead, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Lead update should succeed');

        Lead result = queryLead(sr.getId());
        Assert.areEqual(10, result.Days_Since_Last_Contact__c,
            'Days since last contact should be recalculated to 10');
        Assert.isTrue(result.Is_Overdue__c,
            'Lead should now be overdue after date change');
    }

    /**
     * @description Verifies that clearing Last_Contacted_Date__c to null
     *              sets Days_Since_Last_Contact__c to null and Is_Overdue__c to false.
     */
    @IsTest
    static void clearLastContactedDate_shouldResetMetrics() {
        Lead testLead = buildLead(Date.today().addDays(-10));
        Database.insert(testLead, AccessLevel.SYSTEM_MODE);

        // Reset recursion guard for the update trigger fire
        LeadTriggerHandler.hasRun = false;

        testLead.Last_Contacted_Date__c = null;

        Test.startTest();
        Database.SaveResult sr = Database.update(testLead, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Lead update should succeed');

        Lead result = queryLead(sr.getId());
        Assert.isNull(result.Days_Since_Last_Contact__c,
            'Days since last contact should be null after clearing date');
        Assert.isFalse(result.Is_Overdue__c,
            'Is_Overdue__c should be false after clearing date');
    }

    /**
     * @description Verifies that updating a field OTHER than Last_Contacted_Date__c
     *              does not recalculate the contact metrics.
     */
    @IsTest
    static void updateUnrelatedField_shouldNotRecalculate() {
        Lead testLead = buildLead(Date.today().addDays(-10));
        Database.insert(testLead, AccessLevel.SYSTEM_MODE);

        // Reset recursion guard for the update trigger fire
        LeadTriggerHandler.hasRun = false;

        testLead.Company = 'Updated Company';

        Test.startTest();
        Database.SaveResult sr = Database.update(testLead, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Lead update should succeed');

        Lead result = queryLead(sr.getId());
        Assert.areEqual(10, result.Days_Since_Last_Contact__c,
            'Days since last contact should remain unchanged');
        Assert.isTrue(result.Is_Overdue__c,
            'Overdue status should remain unchanged');
    }

    // ─── Recursion Guard Tests ──────────────────────────────────────────────────

    /**
     * @description Verifies that when hasRun is already true before insert,
     *              the handler skips processing and leaves metrics unset.
     *              Covers Line 41: the early return in beforeInsert.
     */
    @IsTest
    static void beforeInsert_recursionGuard_shouldSkipWhenHasRunIsTrue() {
        LeadTriggerHandler.hasRun = true;

        Lead testLead = buildLead(Date.today().addDays(-10));

        Test.startTest();
        Database.SaveResult sr = Database.insert(testLead, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Lead insert should succeed even when handler is skipped');

        Lead result = queryLead(sr.getId());
        Assert.isNull(result.Days_Since_Last_Contact__c,
            'Days_Since_Last_Contact__c should be null when handler was skipped by recursion guard');
        Assert.isFalse(result.Is_Overdue__c,
            'Is_Overdue__c should be false when handler was skipped by recursion guard');
    }

    /**
     * @description Verifies that when hasRun is already true before update,
     *              the handler skips processing and leaves metrics unchanged.
     *              Covers Line 57: the early return in beforeUpdate.
     */
    @IsTest
    static void beforeUpdate_recursionGuard_shouldSkipWhenHasRunIsTrue() {
        Lead testLead = buildLead(null);
        Database.insert(testLead, AccessLevel.SYSTEM_MODE);

        // Set recursion guard before the update
        LeadTriggerHandler.hasRun = true;

        testLead.Last_Contacted_Date__c = Date.today().addDays(-10);

        Test.startTest();
        Database.SaveResult sr = Database.update(testLead, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Lead update should succeed even when handler is skipped');

        Lead result = queryLead(sr.getId());
        Assert.isNull(result.Days_Since_Last_Contact__c,
            'Days_Since_Last_Contact__c should remain null when handler was skipped by recursion guard');
        Assert.isFalse(result.Is_Overdue__c,
            'Is_Overdue__c should remain false when handler was skipped by recursion guard');
    }

    // ─── Future Date Test ─────────────────────────────────────────────────────────

    /**
     * @description Verifies that a future Last_Contacted_Date__c produces a
     *              positive Days_Since_Last_Contact__c (absolute value).
     *              Covers Line 101: daysSince = daysSince * -1 (negative correction).
     */
    @IsTest
    static void insertWithFutureDate_shouldCalculatePositiveDays() {
        Lead testLead = buildLead(Date.today().addDays(5));

        Test.startTest();
        Database.SaveResult sr = Database.insert(testLead, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Lead insert should succeed with future date');

        Lead result = queryLead(sr.getId());
        Assert.areEqual(5, result.Days_Since_Last_Contact__c,
            'Days_Since_Last_Contact__c should be 5 (absolute value) for a date 5 days in the future');
        Assert.isFalse(result.Is_Overdue__c,
            'Is_Overdue__c should be false when days since contact is less than 7');
    }

    // ─── Bulk Test ──────────────────────────────────────────────────────────────

    /**
     * @description Verifies bulkified trigger handling with 200 records,
     *              mixing overdue and non-overdue leads.
     */
    @IsTest
    static void bulkInsert_shouldHandleTwoHundredRecords() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            Date contactDate = (Math.mod(i, 2) == 0)
                ? Date.today()
                : Date.today().addDays(-10);
            leads.add(new Lead(
                LastName = TEST_LAST_NAME + i,
                Company = TEST_COMPANY + i,
                Last_Contacted_Date__c = contactDate
            ));
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(leads, true, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            Assert.isTrue(sr.isSuccess(), 'All bulk inserts should succeed');
        }

        List<Lead> overdueLeads = [
            SELECT Id FROM Lead
            WHERE Is_Overdue__c = true AND LastName LIKE 'TestLead%'
            WITH USER_MODE
        ];
        List<Lead> notOverdueLeads = [
            SELECT Id FROM Lead
            WHERE Is_Overdue__c = false AND LastName LIKE 'TestLead%'
            WITH USER_MODE
        ];

        Assert.areEqual(100, overdueLeads.size(),
            'Half of the bulk leads should be overdue');
        Assert.areEqual(100, notOverdueLeads.size(),
            'Half of the bulk leads should not be overdue');
    }

    // ─── Helper Methods ─────────────────────────────────────────────────────────

    /**
     * @description Builds a Lead record with the given Last_Contacted_Date__c.
     * @param lastContactedDate The date to set, or null.
     * @return A new Lead record (not yet inserted).
     */
    private static Lead buildLead(Date lastContactedDate) {
        return new Lead(
            LastName = TEST_LAST_NAME,
            Company = TEST_COMPANY,
            Last_Contacted_Date__c = lastContactedDate
        );
    }

    /**
     * @description Queries a Lead by Id with the fields needed for assertions.
     * @param leadId The Id of the lead to query.
     * @return The queried Lead record.
     */
    private static Lead queryLead(Id leadId) {
        return [
            SELECT Id, Days_Since_Last_Contact__c, Is_Overdue__c
            FROM Lead
            WHERE Id = :leadId
            WITH USER_MODE
            LIMIT 1
        ];
    }
}
