/**
 * @description Test class for the Tescribe fluent test data generation library.
 *              Covers all public entry points, every token type, precision selectors,
 *              positional value mapping, template-based building, and error paths.
 *
 *              Test strategy:
 *              - build() is used for in-memory assertions (no DML, faster)
 *              - save()  is used only where database persistence must be verified
 *              - mockTemplate is used for template-path tests to avoid SOQL
 *                dependency on deployed Custom Metadata records
 *
 * @see Tescribe
 */
@IsTest
private class TescribeTest {
    // ─── Constants ───────────────────────────────────────────────────────────

    private static final String ACCOUNT_TYPE_PROSPECT = 'Prospect';
    private static final String ACCOUNT_INDUSTRY_TECH = 'Technology';
    private static final String TEMPLATE_OBJECT_ACCOUNT = 'Account';

    // ─── 1. BASIC BUILDER ────────────────────────────────────────────────────

    @IsTest
    static void build_returnsSingleRecordByDefault() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .setFieldValue(Account.Name, 'Test Account')
            .build();

        Assert.areEqual(
            1,
            result.size(),
            'Default repeat should produce 1 record'
        );
    }

    @IsTest
    static void repeat_returnsCorrectCount() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(10)
            .setFieldValue(Account.Name, 'Account')
            .build();

        Assert.areEqual(
            10,
            result.size(),
            'repeat(10) should produce exactly 10 records'
        );
    }

    @IsTest
    static void build_doesNotInsertRecords() {
        Tescribe.builder(Account.SObjectType)
            .repeat(5)
            .setFieldValue(Account.Name, 'In Memory Account')
            .build();

        Integer dbCount = [
            SELECT COUNT()
            FROM Account
            WHERE Name = 'In Memory Account'
        ];
        Assert.areEqual(
            0,
            dbCount,
            'build() must not insert records into the database'
        );
    }

    @IsTest
    static void save_insertsRecordsAndReturnsWithIds() {
        Test.startTest();
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue(Account.Name, 'Saved Account {alpha}')
            .save();
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'save() should return 3 records');
        for (SObject rec : result) {
            Assert.isNotNull(rec.Id, 'Every saved record must have an Id');
        }
        Assert.areEqual(
            3,
            [SELECT COUNT() FROM Account WHERE Name LIKE 'Saved Account %'],
            'All 3 records should be in the database'
        );
    }

    // ─── 2. SOBJECTFIELD TYPED OVERLOADS ─────────────────────────────────────

    @IsTest
    static void setFieldValue_typedField_setsValueCorrectly() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .setFieldValue(Account.Type, ACCOUNT_TYPE_PROSPECT)
            .build();

        Assert.areEqual(ACCOUNT_TYPE_PROSPECT, (String) result[0].get('Type'));
    }

    @IsTest
    static void setFieldValue_typedFieldWithSelectors_appliesOnlyToTargets() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(4)
            .setFieldValue(Account.Name, 'Account')
            .setFieldValue(
                Account.Industry,
                ACCOUNT_INDUSTRY_TECH,
                new List<String>{ '0-1' }
            )
            .build();

        Assert.areEqual(
            ACCOUNT_INDUSTRY_TECH,
            (String) result[0].get('Industry')
        );
        Assert.areEqual(
            ACCOUNT_INDUSTRY_TECH,
            (String) result[1].get('Industry')
        );
        Assert.isNull(
            result[2].get('Industry'),
            'Record 2 should not have Industry set'
        );
        Assert.isNull(
            result[3].get('Industry'),
            'Record 3 should not have Industry set'
        );
    }

    // ─── 3. TOKEN ENGINE — {alpha} ───────────────────────────────────────────

    @IsTest
    static void token_alpha_generatesAlphabeticSequence() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(4)
            .setFieldValue(Account.Name, 'Account {alpha}')
            .build();

        Assert.areEqual('Account A', (String) result[0].get('Name'));
        Assert.areEqual('Account B', (String) result[1].get('Name'));
        Assert.areEqual('Account C', (String) result[2].get('Name'));
        Assert.areEqual('Account D', (String) result[3].get('Name'));
    }

    @IsTest
    static void token_alphaWithOffset_startsFromSpecifiedLetter() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue(Account.Name, 'Account {alpha:C}')
            .build();

        Assert.areEqual('Account C', (String) result[0].get('Name'));
        Assert.areEqual('Account D', (String) result[1].get('Name'));
        Assert.areEqual('Account E', (String) result[2].get('Name'));
    }

    // ─── 4. TOKEN ENGINE — {counter} ─────────────────────────────────────────

    @IsTest
    static void token_counter_generatesOneBasedSequence() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue(Account.Name, 'Account {counter}')
            .build();

        Assert.areEqual('Account 1', (String) result[0].get('Name'));
        Assert.areEqual('Account 2', (String) result[1].get('Name'));
        Assert.areEqual('Account 3', (String) result[2].get('Name'));
    }

    @IsTest
    static void token_counterWithOffset_startsFromSpecifiedNumber() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue(Account.Name, 'Account {counter:5}')
            .build();

        Assert.areEqual('Account 5', (String) result[0].get('Name'));
        Assert.areEqual('Account 6', (String) result[1].get('Name'));
        Assert.areEqual('Account 7', (String) result[2].get('Name'));
    }

    // ─── 5. TOKEN ENGINE — {index} ───────────────────────────────────────────

    @IsTest
    static void token_index_generatesZeroBasedSequence() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue(Account.Name, 'Account {index}')
            .build();

        Assert.areEqual('Account 0', (String) result[0].get('Name'));
        Assert.areEqual('Account 1', (String) result[1].get('Name'));
        Assert.areEqual('Account 2', (String) result[2].get('Name'));
    }

    // ─── 6. TOKEN ENGINE — {random} ──────────────────────────────────────────

    @IsTest
    static void token_random_producesNonBlankUniqueValues() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue(Account.Name, 'Account {random}')
            .build();

        Set<String> names = new Set<String>();
        for (SObject rec : result) {
            String name = (String) rec.get('Name');
            Assert.isFalse(
                String.isBlank(name),
                'Random token must not produce blank value'
            );
            names.add(name);
        }
        Assert.areEqual(
            3,
            names.size(),
            'Each {random} value should be unique across records'
        );
    }

    // ─── 7. TOKEN ENGINE — {0N} zero-padded ──────────────────────────────────

    @IsTest
    static void token_zeroPadded_producesLeftPaddedNumbers() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue(Account.Name, 'Account {003}')
            .build();

        Assert.areEqual('Account 001', (String) result[0].get('Name'));
        Assert.areEqual('Account 002', (String) result[1].get('Name'));
        Assert.areEqual('Account 003', (String) result[2].get('Name'));
    }

    // ─── 8. TOKEN ENGINE — non-string & no-token passthrough ─────────────────

    @IsTest
    static void nonStringValue_passedThroughUnchanged() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .setFieldValue(Account.NumberOfEmployees, 500)
            .build();

        Assert.areEqual(
            500,
            (Integer) result[0].get('NumberOfEmployees'),
            'Integer values must not be processed as tokens'
        );
    }

    @IsTest
    static void stringWithNoToken_passedThroughUnchanged() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .setFieldValue(Account.Name, 'PlainName')
            .build();

        Assert.areEqual(
            'PlainName',
            (String) result[0].get('Name'),
            'String with no token must be returned as-is'
        );
    }

    // ─── 9. PRECISION SELECTORS — specific index ─────────────────────────────

    @IsTest
    static void selector_specificIndex_appliesOnlyToThatRecord() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(4)
            .setFieldValue(Account.Name, 'Standard')
            .setFieldValue(
                Account.Type,
                ACCOUNT_TYPE_PROSPECT,
                new List<String>{ '2' }
            )
            .build();

        Assert.isNull(result[0].get('Type'), 'Record 0 should not have Type');
        Assert.isNull(result[1].get('Type'), 'Record 1 should not have Type');
        Assert.areEqual(
            ACCOUNT_TYPE_PROSPECT,
            (String) result[2].get('Type'),
            'Record 2 should have Type set'
        );
        Assert.isNull(result[3].get('Type'), 'Record 3 should not have Type');
    }

    // ─── 10. PRECISION SELECTORS — range ─────────────────────────────────────

    @IsTest
    static void selector_range_appliesOnlyToRecordsInRange() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(5)
            .setFieldValue(Account.Name, 'Account')
            .setFieldValue(
                Account.Industry,
                ACCOUNT_INDUSTRY_TECH,
                new List<String>{ '1-3' }
            )
            .build();

        Assert.isNull(result[0].get('Industry'), 'Record 0 is outside range');
        Assert.areEqual(
            ACCOUNT_INDUSTRY_TECH,
            (String) result[1].get('Industry')
        );
        Assert.areEqual(
            ACCOUNT_INDUSTRY_TECH,
            (String) result[2].get('Industry')
        );
        Assert.areEqual(
            ACCOUNT_INDUSTRY_TECH,
            (String) result[3].get('Industry')
        );
        Assert.isNull(result[4].get('Industry'), 'Record 4 is outside range');
    }

    @IsTest
    static void selector_rangeOverridesGlobalRule() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(4)
            .setFieldValue(Account.Name, 'Account {alpha}')
            .setFieldValue(
                Account.Name,
                'Override {alpha}',
                new List<String>{ '0-1' }
            )
            .build();

        Assert.areEqual('Override A', (String) result[0].get('Name'));
        Assert.areEqual('Override B', (String) result[1].get('Name'));
        Assert.areEqual('Account C', (String) result[2].get('Name'));
        Assert.areEqual('Account D', (String) result[3].get('Name'));
    }

    // ─── 11. SETFIELDVALUES — positional mapping ──────────────────────────────

    @IsTest
    static void setFieldValues_objectList_mapsValuesByPosition() {
        List<Object> types = new List<Object>{
            'Analyst',
            'Partner',
            'Competitor'
        };

        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue(Account.Name, 'Account {alpha}')
            .setFieldValues(Account.Type, types)
            .build();

        Assert.areEqual('Analyst', (String) result[0].get('Type'));
        Assert.areEqual('Partner', (String) result[1].get('Type'));
        Assert.areEqual('Competitor', (String) result[2].get('Type'));
    }

    @IsTest
    static void setFieldValues_listShorterThanQuantity_returnsNullForOverflow() {
        List<Object> types = new List<Object>{ 'Analyst' };

        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue(Account.Name, 'Account {alpha}')
            .setFieldValues(Account.Type, types)
            .build();

        Assert.areEqual('Analyst', (String) result[0].get('Type'));
        Assert.isNull(
            result[1].get('Type'),
            'Record beyond list size should get null'
        );
        Assert.isNull(
            result[2].get('Type'),
            'Record beyond list size should get null'
        );
    }

    @IsTest
    static void setFieldValues_nullList_doesNotThrow() {
        List<Object> nullList = null;

        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(2)
            .setFieldValue(Account.Name, 'Account')
            .setFieldValues(Account.Type, nullList)
            .build();

        Assert.areEqual(
            2,
            result.size(),
            'Null value list must not prevent build'
        );
    }

    @IsTest
    static void setFieldValues_sobjectList_mapsIdsToField() {
        List<Account> accounts = (List<Account>) Tescribe.builder(
                Account.SObjectType
            )
            .repeat(2)
            .setFieldValue(Account.Name, 'Parent {alpha}')
            .save();

        List<SObject> contacts = Tescribe.builder(Contact.SObjectType)
            .repeat(2)
            .setFieldValue(Contact.LastName, 'Contact {alpha}')
            .setFieldValues(Contact.AccountId, accounts)
            .build();

        Assert.areEqual(accounts[0].Id, (Id) contacts[0].get('AccountId'));
        Assert.areEqual(accounts[1].Id, (Id) contacts[1].get('AccountId'));
    }

    // ─── 12. STRING-BASED setFieldValue OVERLOAD ──────────────────────────────

    @IsTest
    static void setFieldValue_stringFieldName_setsValueCorrectly() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .setFieldValue('Name', 'String Field Test')
            .build();

        Assert.areEqual('String Field Test', (String) result[0].get('Name'));
    }

    @IsTest
    static void setFieldValue_stringFieldNameWithSelectors_appliesCorrectly() {
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(3)
            .setFieldValue('Name', 'Account {alpha}')
            .setFieldValue(
                'Type',
                ACCOUNT_TYPE_PROSPECT,
                new List<String>{ '0' }
            )
            .build();

        Assert.areEqual(ACCOUNT_TYPE_PROSPECT, (String) result[0].get('Type'));
        Assert.isNull(result[1].get('Type'));
        Assert.isNull(result[2].get('Type'));
    }

    // ─── 13. TEMPLATE BUILDER — mock path ────────────────────────────────────

    @IsTest
    static void templateBuilder_withMock_appliesJsonFields() {
        Tescribe.mockTemplate = new Tescribe_Template__mdt(
            Object_API_Name__c = TEMPLATE_OBJECT_ACCOUNT,
            JSON_Data__c = '{"Type": "Prospect", "Industry": "Technology"}',
            Is_Active__c = true
        );

        List<SObject> result = Tescribe.builder('any_template_name')
            .setFieldValue(Account.Name, 'Template Account')
            .build();

        Assert.areEqual(ACCOUNT_TYPE_PROSPECT, (String) result[0].get('Type'));
        Assert.areEqual(
            ACCOUNT_INDUSTRY_TECH,
            (String) result[0].get('Industry')
        );
        Assert.areEqual('Template Account', (String) result[0].get('Name'));
    }

    @IsTest
    static void templateBuilder_withMockAndBlankJson_buildsWithNoDefaultFields() {
        Tescribe.mockTemplate = new Tescribe_Template__mdt(
            Object_API_Name__c = TEMPLATE_OBJECT_ACCOUNT,
            JSON_Data__c = '',
            Is_Active__c = true
        );

        List<SObject> result = Tescribe.builder('any_template_name')
            .setFieldValue(Account.Name, 'Blank JSON Account')
            .build();

        Assert.areEqual(1, result.size());
        Assert.areEqual('Blank JSON Account', (String) result[0].get('Name'));
    }

    @IsTest
    static void templateBuilder_mockOverridesCanOverrideJsonDefaults() {
        Tescribe.mockTemplate = new Tescribe_Template__mdt(
            Object_API_Name__c = TEMPLATE_OBJECT_ACCOUNT,
            JSON_Data__c = '{"Type": "Prospect"}',
            Is_Active__c = true
        );

        List<SObject> result = Tescribe.builder('any_template_name')
            .setFieldValue(Account.Name, 'Override Account')
            .setFieldValue(Account.Type, 'Partner')
            .build();

        Assert.areEqual(
            'Partner',
            (String) result[0].get('Type'),
            'Explicit setFieldValue after template builder should override JSON default'
        );
    }

    // ─── 14. TEMPLATE BUILDER — error paths ──────────────────────────────────

    @IsTest
    static void templateBuilder_invalidObjectInMock_throwsIllegalArgumentException() {
        Tescribe.mockTemplate = new Tescribe_Template__mdt(
            Object_API_Name__c = 'InvalidObject__xyz',
            JSON_Data__c = null,
            Is_Active__c = true
        );

        Boolean exceptionThrown = false;
        try {
            Tescribe.builder('any_template_name');
        } catch (IllegalArgumentException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('Invalid Object'),
                'Exception message should mention Invalid Object'
            );
        }
        Assert.isTrue(
            exceptionThrown,
            'IllegalArgumentException must be thrown for invalid object'
        );
    }

    @IsTest
    static void templateBuilder_templateNotFound_throwsIllegalArgumentException() {
        // Do NOT set mockTemplate — force the SOQL path with a name that won't exist
        // Reset mock in case a prior test set it
        Tescribe.mockTemplate = null;

        Boolean exceptionThrown = false;
        try {
            Tescribe.builder('NonExistent_Template_XYZ_99999');
        } catch (IllegalArgumentException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('Active template not found'),
                'Exception message should mention template not found'
            );
        }
        Assert.isTrue(
            exceptionThrown,
            'IllegalArgumentException must be thrown for missing template'
        );
    }

    // ─── 15. ENTERPRISE ACCOUNT TEMPLATE (live CMT record) ───────────────────

    @IsTest
    static void enterpriseAccountTemplate_createsAccountsWithExpectedFieldValues() {
        Test.startTest();
        List<SObject> result = Tescribe.builder('Enterprise_Account_Template')
            .repeat(3)
            .save();
        Test.stopTest();

        Assert.areEqual(3, result.size());
        for (SObject rec : result) {
            Assert.isNotNull(rec.Id);
            String name = (String) rec.get('Name');
            Assert.isTrue(
                name.startsWith('Enterprise Client '),
                'Name should start with "Enterprise Client " but was: ' + name
            );
            Assert.areEqual(ACCOUNT_TYPE_PROSPECT, (String) rec.get('Type'));
            Assert.areEqual(
                ACCOUNT_INDUSTRY_TECH,
                (String) rec.get('Industry')
            );
        }
    }

    // ─── 16. BULK TEST ───────────────────────────────────────────────────────

    @IsTest
    static void bulk_200Records_buildsWithinGovernorLimits() {
        Test.startTest();
        List<SObject> result = Tescribe.builder(Account.SObjectType)
            .repeat(200)
            .setFieldValue(Account.Name, 'Bulk Account {counter}')
            .save();
        Test.stopTest();

        Assert.areEqual(200, result.size(), '200 records should be created');
        Assert.areEqual('Bulk Account 1', (String) result[0].get('Name'));
        Assert.areEqual('Bulk Account 200', (String) result[199].get('Name'));
    }
}
