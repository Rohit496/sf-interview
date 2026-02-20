/**
 * @description Test class for SoftDrinkArchiveBatch.
 *              Validates that records with Tags__c = 'Archive' are correctly archived
 *              and non-matching records remain untouched.
 */
@IsTest
private class SoftDrinkArchiveBatchTest {

    private static final String TAG_ARCHIVE = 'Archive';
    private static final String STATUS_ARCHIVE = 'Archive';
    private static final String STATUS_AVAILABLE = 'Available';
    private static final String STATUS_SAFE = 'Safe to Use';

    @TestSetup
    static void makeData() {
        List<Soft_Drink__c> drinks = new List<Soft_Drink__c>{
            new Soft_Drink__c(
                Name = 'Cola Classic',
                Tags__c = TAG_ARCHIVE,
                Status__c = STATUS_AVAILABLE,
                Total_Quantity__c = 100
            ),
            new Soft_Drink__c(
                Name = 'Orange Fizz',
                Tags__c = TAG_ARCHIVE,
                Status__c = STATUS_SAFE,
                Total_Quantity__c = 50
            ),
            new Soft_Drink__c(
                Name = 'Lemon Splash',
                Tags__c = 'Premium',
                Status__c = STATUS_AVAILABLE,
                Total_Quantity__c = 200
            ),
            new Soft_Drink__c(
                Name = 'Already Archived',
                Tags__c = TAG_ARCHIVE,
                Status__c = STATUS_ARCHIVE,
                Total_Quantity__c = 10
            )
        };
        insert drinks;
    }

    @IsTest
    static void archivesRecordsWithArchiveTag() {
        Test.startTest();
        Database.executeBatch(new SoftDrinkArchiveBatch());
        Test.stopTest();

        List<Soft_Drink__c> archivedDrinks = [
            SELECT Id, Name, Status__c
            FROM Soft_Drink__c
            WHERE Tags__c = :TAG_ARCHIVE
        ];

        for (Soft_Drink__c drink : archivedDrinks) {
            Assert.areEqual(STATUS_ARCHIVE, drink.Status__c,
                'Record "' + drink.Name + '" should have Status set to Archive');
        }
    }

    @IsTest
    static void doesNotUpdateNonMatchingRecords() {
        Test.startTest();
        Database.executeBatch(new SoftDrinkArchiveBatch());
        Test.stopTest();

        Soft_Drink__c nonMatchingDrink = [
            SELECT Id, Status__c
            FROM Soft_Drink__c
            WHERE Name = 'Lemon Splash'
            LIMIT 1
        ];

        Assert.areEqual(STATUS_AVAILABLE, nonMatchingDrink.Status__c,
            'Record without Archive tag should not be updated');
    }

    @IsTest
    static void handlesEmptyScope() {
        delete [SELECT Id FROM Soft_Drink__c WHERE Tags__c = :TAG_ARCHIVE AND Status__c != :STATUS_ARCHIVE];

        Test.startTest();
        Database.executeBatch(new SoftDrinkArchiveBatch());
        Test.stopTest();

        List<Soft_Drink__c> allDrinks = [SELECT Id, Status__c FROM Soft_Drink__c];
        Assert.isFalse(allDrinks.isEmpty(), 'Non-matching records should still exist');
    }
}
