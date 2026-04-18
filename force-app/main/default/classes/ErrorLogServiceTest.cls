/**
 * @description Test class for ErrorLogService.
 *              Validates the @AuraEnabled logError method covering:
 *              - Happy path: all four valid Error_Type__c picklist values insert a record
 *              - Field accuracy: every mapped field is stored with the correct value
 *              - System-populated fields: User__c and Occurred_At__c are set automatically
 *              - Null parameters: method is fire-and-forget and must not throw when inputs are null
 *              - Blank parameters: method must not throw when inputs are empty strings
 *              - Invalid error type: invalid picklist value causes a silent insert failure;
 *                no exception propagates to the caller
 *
 *              DML in this test class uses AccessLevel.SYSTEM_MODE because the test user
 *              may lack FLS on Error_Log__c custom fields; the production class itself
 *              runs with AccessLevel.USER_MODE which is exercised during Test.startTest/stopTest.
 *
 * @see ErrorLogService
 */
@IsTest
private with sharing class ErrorLogServiceTest {
    // -------------------------------------------------------------------------
    // Constants — picklist values for Error_Type__c
    // -------------------------------------------------------------------------

    private static final String ERROR_TYPE_APEX = 'Apex';
    private static final String ERROR_TYPE_NETWORK = 'Network';
    private static final String ERROR_TYPE_VALIDATION = 'Validation';
    private static final String ERROR_TYPE_UNKNOWN = 'Unknown';
    private static final String ERROR_TYPE_INVALID = 'NotARealType';

    private static final String SAMPLE_MESSAGE = 'Something went wrong in the component.';
    private static final String SAMPLE_STACK = 'at MyComponent.handleError (myComponent.js:42)';
    private static final String SAMPLE_COMPONENT = 'myComponent';

    // =========================================================================
    // Happy-path — one test per valid picklist value
    // =========================================================================

    /**
     * @description Calling logError with Error_Type__c = 'Apex' must insert one
     *              Error_Log__c record that is immediately queryable from the database.
     */
    @IsTest
    static void logError_apexType_insertsOneRecord() {
        Test.startTest();
        ErrorLogService.logError(
            ERROR_TYPE_APEX,
            SAMPLE_MESSAGE,
            SAMPLE_STACK,
            SAMPLE_COMPONENT
        );
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Id
            FROM Error_Log__c
            WHERE Error_Type__c = :ERROR_TYPE_APEX
            WITH USER_MODE
        ];

        Assert.areEqual(
            1,
            logs.size(),
            'Exactly one Error_Log__c record should exist after logError with type Apex'
        );
    }

    /**
     * @description Calling logError with Error_Type__c = 'Network' must insert one
     *              Error_Log__c record that is immediately queryable from the database.
     */
    @IsTest
    static void logError_networkType_insertsOneRecord() {
        Test.startTest();
        ErrorLogService.logError(
            ERROR_TYPE_NETWORK,
            SAMPLE_MESSAGE,
            SAMPLE_STACK,
            SAMPLE_COMPONENT
        );
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Id
            FROM Error_Log__c
            WHERE Error_Type__c = :ERROR_TYPE_NETWORK
            WITH USER_MODE
        ];

        Assert.areEqual(
            1,
            logs.size(),
            'Exactly one Error_Log__c record should exist after logError with type Network'
        );
    }

    /**
     * @description Calling logError with Error_Type__c = 'Validation' must insert one
     *              Error_Log__c record that is immediately queryable from the database.
     */
    @IsTest
    static void logError_validationType_insertsOneRecord() {
        Test.startTest();
        ErrorLogService.logError(
            ERROR_TYPE_VALIDATION,
            SAMPLE_MESSAGE,
            SAMPLE_STACK,
            SAMPLE_COMPONENT
        );
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Id
            FROM Error_Log__c
            WHERE Error_Type__c = :ERROR_TYPE_VALIDATION
            WITH USER_MODE
        ];

        Assert.areEqual(
            1,
            logs.size(),
            'Exactly one Error_Log__c record should exist after logError with type Validation'
        );
    }

    /**
     * @description Calling logError with Error_Type__c = 'Unknown' must insert one
     *              Error_Log__c record that is immediately queryable from the database.
     */
    @IsTest
    static void logError_unknownType_insertsOneRecord() {
        Test.startTest();
        ErrorLogService.logError(
            ERROR_TYPE_UNKNOWN,
            SAMPLE_MESSAGE,
            SAMPLE_STACK,
            SAMPLE_COMPONENT
        );
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Id
            FROM Error_Log__c
            WHERE Error_Type__c = :ERROR_TYPE_UNKNOWN
            WITH USER_MODE
        ];

        Assert.areEqual(
            1,
            logs.size(),
            'Exactly one Error_Log__c record should exist after logError with type Unknown'
        );
    }

    // =========================================================================
    // Field accuracy — all mapped fields carry the correct values
    // =========================================================================

    /**
     * @description After logError completes, every field on the inserted Error_Log__c
     *              record must reflect exactly the values passed to the method.
     *              System-populated fields (User__c, Occurred_At__c) must also be set.
     */
    @IsTest
    static void logError_allFieldsPopulated_fieldValuesMatchInput() {
        Datetime beforeCall = Datetime.now();

        Test.startTest();
        ErrorLogService.logError(
            ERROR_TYPE_APEX,
            SAMPLE_MESSAGE,
            SAMPLE_STACK,
            SAMPLE_COMPONENT
        );
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT
                Error_Type__c,
                Error_Message__c,
                Stack_Trace__c,
                Component_Name__c,
                User__c,
                Occurred_At__c
            FROM Error_Log__c
            WHERE Error_Type__c = :ERROR_TYPE_APEX
            WITH USER_MODE
            LIMIT 1
        ];

        Assert.areEqual(
            1,
            logs.size(),
            'One Error_Log__c record must be present for the field-accuracy assertion'
        );

        Error_Log__c log = logs[0];

        Assert.areEqual(
            ERROR_TYPE_APEX,
            log.Error_Type__c,
            'Error_Type__c must match the errorType argument'
        );

        Assert.areEqual(
            SAMPLE_MESSAGE,
            log.Error_Message__c,
            'Error_Message__c must match the errorMessage argument'
        );

        Assert.areEqual(
            SAMPLE_STACK,
            log.Stack_Trace__c,
            'Stack_Trace__c must match the stackTrace argument'
        );

        Assert.areEqual(
            SAMPLE_COMPONENT,
            log.Component_Name__c,
            'Component_Name__c must match the componentName argument'
        );

        Assert.areEqual(
            UserInfo.getUserId(),
            log.User__c,
            'User__c must be set to the running user via UserInfo.getUserId()'
        );

        Assert.isNotNull(
            log.Occurred_At__c,
            'Occurred_At__c must be populated by the service method'
        );

        Assert.isTrue(
            log.Occurred_At__c >= beforeCall,
            'Occurred_At__c must be at or after the timestamp captured before the call'
        );
    }

    // =========================================================================
    // Null / blank parameters — fire-and-forget must never throw
    // =========================================================================

    /**
     * @description Passing null for every parameter must not cause any exception to
     *              propagate. Error_Type__c is a required picklist field, so the insert
     *              will fail; the method silently consumes that failure (allOrNone=false).
     */
    @IsTest
    static void logError_allNullParameters_doesNotThrow() {
        Test.startTest();
        try {
            ErrorLogService.logError(null, null, null, null);
        } catch (Exception e) {
            Assert.fail(
                'logError must not throw any exception when all parameters are null. ' +
                    'Caught: ' +
                    e.getTypeName() +
                    ' — ' +
                    e.getMessage()
            );
        }
        Test.stopTest();

        // The insert is expected to fail silently because Error_Type__c is required;
        // assert that zero records were created so the test is self-documenting.
        Integer logCount = [
            SELECT COUNT()
            FROM Error_Log__c
            WITH USER_MODE
        ];

        Assert.areEqual(
            0,
            logCount,
            'No Error_Log__c record should be created when Error_Type__c is null (required field)'
        );
    }

    /**
     * @description Passing empty strings for every parameter must not cause any
     *              exception to propagate. An empty string for a required picklist
     *              field is treated the same as null by Salesforce and the insert
     *              will fail silently.
     */
    @IsTest
    static void logError_allBlankParameters_doesNotThrow() {
        Test.startTest();
        try {
            ErrorLogService.logError('', '', '', '');
        } catch (Exception e) {
            Assert.fail(
                'logError must not throw any exception when all parameters are blank. ' +
                    'Caught: ' +
                    e.getTypeName() +
                    ' — ' +
                    e.getMessage()
            );
        }
        Test.stopTest();

        Integer logCount = [
            SELECT COUNT()
            FROM Error_Log__c
            WITH USER_MODE
        ];

        Assert.areEqual(
            0,
            logCount,
            'No Error_Log__c record should be created when Error_Type__c is blank (required field)'
        );
    }

    /**
     * @description Only the errorType parameter is non-null; all other parameters
     *              are null. The insert must succeed because only Error_Type__c is
     *              required. The remaining null fields are simply stored as null.
     */
    @IsTest
    static void logError_onlyErrorTypeProvided_insertsRecordWithNullOptionalFields() {
        Test.startTest();
        ErrorLogService.logError(ERROR_TYPE_UNKNOWN, null, null, null);
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT
                Error_Type__c,
                Error_Message__c,
                Stack_Trace__c,
                Component_Name__c
            FROM Error_Log__c
            WHERE Error_Type__c = :ERROR_TYPE_UNKNOWN
            WITH USER_MODE
            LIMIT 1
        ];

        Assert.areEqual(
            1,
            logs.size(),
            'One Error_Log__c must be inserted when only the required Error_Type__c is supplied'
        );

        Assert.areEqual(
            ERROR_TYPE_UNKNOWN,
            logs[0].Error_Type__c,
            'Error_Type__c must be stored correctly'
        );

        Assert.isNull(
            logs[0].Error_Message__c,
            'Error_Message__c must be null when null was passed'
        );

        Assert.isNull(
            logs[0].Stack_Trace__c,
            'Stack_Trace__c must be null when null was passed'
        );

        Assert.isNull(
            logs[0].Component_Name__c,
            'Component_Name__c must be null when null was passed'
        );
    }

    // =========================================================================
    // Invalid picklist value — silent insert failure, no exception propagated
    // =========================================================================

    /**
     * @description Passing a value that is not in the Error_Type__c picklist causes
     *              the Database.insert to fail with a field-integrity error. Because
     *              allOrNone=false, the failure is silently consumed and the method
     *              must not throw. No record must be created.
     */
    @IsTest
    static void logError_invalidErrorType_silentlyFailsWithoutThrowing() {
        Test.startTest();
        try {
            ErrorLogService.logError(
                ERROR_TYPE_INVALID,
                SAMPLE_MESSAGE,
                SAMPLE_STACK,
                SAMPLE_COMPONENT
            );
        } catch (Exception e) {
            Assert.fail(
                'logError must not throw even for an invalid Error_Type__c value. ' +
                    'Caught: ' +
                    e.getTypeName() +
                    ' — ' +
                    e.getMessage()
            );
        }
        Test.stopTest();

        Integer logCount = [
            SELECT COUNT()
            FROM Error_Log__c
            WITH USER_MODE
        ];

        Assert.areEqual(
            0,
            logCount,
            'No Error_Log__c record must be created when an invalid picklist value is supplied'
        );
    }
}
