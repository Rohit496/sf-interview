/**
 * @description Unit tests for AccountController.
 *              Validates query results and display-count clamping logic.
 */
@IsTest
private class AccountControllerTest {
    // ─── Test Setup ──────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        List<Account> accounts = new List<Account>();
        String[] ratings = new String[]{ 'Hot', 'Warm', 'Cold' };
        for (Integer i = 0; i < 10; i++) {
            accounts.add(
                new Account(
                    Name = 'Test Account ' + i,
                    Industry = 'Technology',
                    Phone = '555-000' + i,
                    AnnualRevenue = 1000000 * (i + 1),
                    Rating = ratings[Math.mod(i, 3)]
                )
            );
        }
        Database.insert(accounts, AccessLevel.USER_MODE);
    }

    // ─── Test Cases ──────────────────────────────────────────────────────────────

    @IsTest
    static void testGetAccounts_returnsRequestedCount() {
        Test.startTest();
        AccountController.AccountResult result = AccountController.getAccounts(3);
        Test.stopTest();

        System.assertEquals(3, result.accounts.size(), 'Should return exactly 3 accounts');
        System.assert(result.totalCount >= 10, 'Total count should reflect all inserted accounts');
    }

    @IsTest
    static void testGetAccounts_clampedToMin() {
        Test.startTest();
        AccountController.AccountResult result = AccountController.getAccounts(1);
        Test.stopTest();

        System.assertEquals(2, result.accounts.size(), 'Count below 2 should be clamped to 2');
    }

    @IsTest
    static void testGetAccounts_clampedToMax() {
        Test.startTest();
        AccountController.AccountResult result = AccountController.getAccounts(10);
        Test.stopTest();

        System.assertEquals(5, result.accounts.size(), 'Count above 5 should be clamped to 5');
    }

    @IsTest
    static void testGetAccounts_nullCountDefaultsToMin() {
        Test.startTest();
        AccountController.AccountResult result = AccountController.getAccounts(null);
        Test.stopTest();

        System.assertEquals(2, result.accounts.size(), 'Null input should default to min of 2');
    }

    @IsTest
    static void testGetAccounts_resultFieldsPopulated() {
        Test.startTest();
        AccountController.AccountResult result = AccountController.getAccounts(2);
        Test.stopTest();

        Account first = result.accounts[0];
        System.assertNotEquals(null, first.Name, 'Name should be populated');
        System.assertNotEquals(null, first.Id, 'Id should be populated');
    }
}
