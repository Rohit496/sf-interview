/**
 * @description Test class for OverdueLeadsController.
 *              Validates that getOverdueLeads returns only overdue,
 *              unconverted leads owned by the running user.
 *
 * @see OverdueLeadsController
 */
@IsTest
private class OverdueLeadsControllerTest {

    private static final String TEST_COMPANY = 'Controller Test Co';

    @TestSetup
    static void setupTestData() {
        List<Lead> leads = new List<Lead>();

        // Overdue leads (contacted 10 days ago) -- owned by running user
        for (Integer i = 0; i < 5; i++) {
            leads.add(new Lead(
                LastName = 'OverdueLead' + i,
                Company = TEST_COMPANY,
                Last_Contacted_Date__c = Date.today().addDays(-10)
            ));
        }

        // Not overdue leads (contacted today) -- owned by running user
        for (Integer i = 0; i < 3; i++) {
            leads.add(new Lead(
                LastName = 'CurrentLead' + i,
                Company = TEST_COMPANY,
                Last_Contacted_Date__c = Date.today()
            ));
        }

        // Not overdue leads (no contact date) -- owned by running user
        leads.add(new Lead(
            LastName = 'NoDateLead',
            Company = TEST_COMPANY
        ));

        insert leads;
    }

    /**
     * @description Verifies that getOverdueLeads returns only leads
     *              where Is_Overdue__c is true and owned by the running user.
     */
    @IsTest
    static void getOverdueLeads_shouldReturnOnlyOverdueLeads() {
        Test.startTest();
        List<Lead> overdueLeads = OverdueLeadsController.getOverdueLeads();
        Test.stopTest();

        Assert.areEqual(5, overdueLeads.size(),
            'Should return exactly 5 overdue leads');

        for (Lead lead : overdueLeads) {
            Assert.isTrue(lead.Name.startsWith('OverdueLead'),
                'All returned leads should be overdue leads, got: ' + lead.Name);
            Assert.isNotNull(lead.Company,
                'Company field should be returned');
        }
    }

    /**
     * @description Verifies that results are ordered by Days_Since_Last_Contact__c
     *              in descending order.
     */
    @IsTest
    static void getOverdueLeads_shouldBeOrderedDescending() {
        Test.startTest();
        List<Lead> overdueLeads = OverdueLeadsController.getOverdueLeads();
        Test.stopTest();

        Assert.isFalse(overdueLeads.isEmpty(),
            'Should return overdue leads for ordering test');

        // Verify ordering -- only if Days_Since_Last_Contact__c is accessible.
        // Security.stripInaccessible removes inaccessible fields entirely, so
        // check the populated fields map before accessing the value.
        Boolean fieldAccessible = overdueLeads[0]
            .getPopulatedFieldsAsMap()
            .containsKey('Days_Since_Last_Contact__c');

        if (fieldAccessible && overdueLeads.size() > 1) {
            for (Integer i = 0; i < overdueLeads.size() - 1; i++) {
                Decimal current = (Decimal) overdueLeads[i].get('Days_Since_Last_Contact__c');
                Decimal next = (Decimal) overdueLeads[i + 1].get('Days_Since_Last_Contact__c');
                if (current != null && next != null) {
                    Assert.isTrue(
                        current >= next,
                        'Results should be ordered by days since last contact descending'
                    );
                }
            }
        }
    }

    /**
     * @description Verifies that the method returns an empty list when
     *              there are no overdue leads for the running user.
     */
    @IsTest
    static void getOverdueLeads_shouldReturnEmptyWhenNoneOverdue() {
        // Delete all overdue leads from test setup
        delete [SELECT Id FROM Lead WHERE Is_Overdue__c = true];

        Test.startTest();
        List<Lead> overdueLeads = OverdueLeadsController.getOverdueLeads();
        Test.stopTest();

        Assert.isTrue(overdueLeads.isEmpty(),
            'Should return empty list when no overdue leads exist');
    }

    /**
     * @description Verifies that getOverdueLeads throws an AuraHandledException
     *              when an unexpected exception occurs during query execution.
     */
    @IsTest
    static void getOverdueLeads_shouldThrowAuraHandledException_whenQueryFails() {
        OverdueLeadsController.forceException = true;

        try {
            Test.startTest();
            OverdueLeadsController.getOverdueLeads();
            Test.stopTest();
            Assert.fail('Expected AuraHandledException was not thrown');
        } catch (AuraHandledException ex) {
            Assert.isNotNull(ex.getMessage(),
                'Exception message should not be null');
        }
    }
}
