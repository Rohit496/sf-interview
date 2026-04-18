@IsTest
private class OpportunityDatatableControllerTest {
    @TestSetup
    static void setup() {
        Account a = new Account(Name = 'Test Acct');
        insert a;

        List<Opportunity> opps = new List<Opportunity>();
        // Open opps
        opps.add(
            new Opportunity(
                Name = 'Open Opp 1',
                StageName = 'Prospecting',
                CloseDate = System.today().addDays(30),
                Amount = 1000,
                AccountId = a.Id
            )
        );
        opps.add(
            new Opportunity(
                Name = 'Open Opp 2',
                StageName = 'Qualification',
                CloseDate = System.today().addDays(10),
                Amount = 5000,
                AccountId = a.Id
            )
        );
        // Closed opp (should be filtered out)
        opps.add(
            new Opportunity(
                Name = 'Closed Won Opp',
                StageName = 'Closed Won',
                CloseDate = System.today().addDays(-5),
                Amount = 7000,
                IsClosed = true,
                AccountId = a.Id
            )
        );
        insert opps;
    }

    @IsTest
    static void testGetOpportunitiesFiltersOpenOnlyAndFields() {
        Test.startTest();
        List<Opportunity> rows = OpportunityDatatableController.getOpportunities(
            200
        );
        Test.stopTest();

        System.assertNotEquals(0, rows.size(), 'Should return some rows');
        // Ensure none are closed
        for (Opportunity o : rows) {
            System.assertEquals(
                false,
                o.IsClosed,
                'Only open opps should be returned'
            );
            // Ensure expected fields are populated
            System.assertNotEquals(null, o.Name, 'Name should be selected');
            System.assertNotEquals(
                null,
                o.StageName,
                'StageName should be selected'
            );
            System.assertNotEquals(
                null,
                o.CloseDate,
                'CloseDate should be selected'
            );
        }
    }

    @IsTest
    static void testUpdateOpportunitiesSuccessAndPartialFailures() {
        // Get one open opp
        Opportunity openOpp = [
            SELECT Id, Name, StageName, CloseDate, Amount, AccountId
            FROM Opportunity
            WHERE IsClosed = FALSE
            LIMIT 1
        ];

        // Build updates: one valid, one with missing Id (should be ignored by DML but we include to see error handling)
        Opportunity valid = new Opportunity(
            Id = openOpp.Id,
            Name = 'Updated Name',
            StageName = 'Proposal/Price Quote',
            CloseDate = System.today().addDays(15),
            Amount = 1234
        );

        Opportunity invalidMissingId = new Opportunity(); // no Id

        Test.startTest();
        OpportunityDatatableController.UpdateResult res = OpportunityDatatableController.updateOpportunities(
            new List<Opportunity>{ valid, invalidMissingId }
        );
        Test.stopTest();

        // One success expected
        System.assert(
            res.successIds != null && res.successIds.size() == 1,
            'Exactly one record should succeed'
        );
        System.assert(res.errors != null, 'Errors list should exist');
        System.assertEquals(
            1,
            res.errors.size(),
            'One error expected for the invalid record'
        );

        // Verify the update actually persisted
        Opportunity after = [
            SELECT Id, Name, StageName, CloseDate, Amount
            FROM Opportunity
            WHERE Id = :openOpp.Id
        ];
        System.assertEquals(
            'Updated Name',
            after.Name,
            'Name should be updated'
        );
        System.assertEquals(
            'Proposal/Price Quote',
            after.StageName,
            'Stage should be updated'
        );
        System.assertEquals(
            Date.today().addDays(15),
            after.CloseDate,
            'CloseDate should be updated'
        );
        System.assertEquals(1234, after.Amount, 'Amount should be updated');
    }

    @IsTest
    static void testUpdateOpportunitiesNoInput() {
        Test.startTest();
        OpportunityDatatableController.UpdateResult res = OpportunityDatatableController.updateOpportunities(
            new List<Opportunity>()
        );
        Test.stopTest();

        System.assertNotEquals(null, res, 'Result should not be null');
        System.assertEquals(0, res.successIds.size(), 'No successes expected');
        System.assertEquals(0, res.errors.size(), 'No errors expected');
    }
}
