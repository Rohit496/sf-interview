/**
 * @description Test class for CaseLookupAction.
 *              Validates the @InvocableMethod getCaseDetails covering:
 *              - Positive path: valid CaseNumber returns full case details with caseFound = true
 *              - Negative path: non-existent CaseNumber returns caseFound = false with errorMessage
 *              - Null/empty input: null caseNumber handled gracefully via catch block
 *              - Bulk invocation: multiple CaseRequest items in one call, each resolved independently
 *              - Case without Account: accountName is null-safe when Account is not linked
 *
 *              Test data is created without namespace prefix (no custom namespace in this org).
 *              DML uses AccessLevel.SYSTEM_MODE because the test user may lack FLS
 *              on fields queried by the production class under WITH SECURITY_ENFORCED.
 *
 * @see CaseLookupAction
 */
@IsTest
private with sharing class CaseLookupActionTest {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    private static final String ACCOUNT_NAME = 'Lookup Test Corp';
    private static final String CASE_SUBJECT = 'Billing Inquiry';
    private static final String CASE_STATUS = 'New';
    private static final String CASE_PRIORITY = 'Medium';
    private static final String CASE_ORIGIN = 'Phone';
    private static final String CASE_DESC = 'Test case description';
    private static final String NONEXISTENT_NUM = '000000000';

    // -------------------------------------------------------------------------
    // @TestSetup: shared Account + Case used by multiple test methods
    // -------------------------------------------------------------------------

    /**
     * @description Creates a shared Account and one linked Case used by most
     *              test methods.  Each test queries them back via SOQL to avoid
     *              stale references.
     */
    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = ACCOUNT_NAME);
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Case c = new Case(
            Subject = CASE_SUBJECT,
            Status = CASE_STATUS,
            Priority = CASE_PRIORITY,
            Origin = CASE_ORIGIN,
            Description = CASE_DESC,
            AccountId = acc.Id
        );
        Database.insert(c, AccessLevel.SYSTEM_MODE);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /** Queries and returns the shared Account created in @TestSetup. */
    private static Account getTestAccount() {
        return [
            SELECT Id, Name
            FROM Account
            WHERE Name = :ACCOUNT_NAME
            WITH USER_MODE
            LIMIT 1
        ];
    }

    /** Queries and returns the shared Case created in @TestSetup. */
    private static Case getTestCase() {
        return [
            SELECT Id, CaseNumber
            FROM Case
            WHERE Subject = :CASE_SUBJECT
            WITH USER_MODE
            LIMIT 1
        ];
    }

    /**
     * @description Builds a CaseRequest wrapper for the given case number string.
     * @param caseNum The CaseNumber string to place in the request.
     * @return A populated CaseRequest.
     */
    private static CaseLookupAction.CaseRequest buildRequest(String caseNum) {
        CaseLookupAction.CaseRequest req = new CaseLookupAction.CaseRequest();
        req.caseNumber = caseNum;
        return req;
    }

    // =========================================================================
    // Positive path — valid CaseNumber returns full details with caseFound = true
    // =========================================================================

    /**
     * @description Calling getCaseDetails with a CaseNumber that exists in the
     *              database must return caseFound = true and populate all result
     *              fields from the stored Case record.
     */
    @IsTest
    static void getCaseDetails_validCaseNumber_returnsCaseFoundTrue() {
        Case existingCase = getTestCase();

        List<CaseLookupAction.CaseRequest> requests = new List<CaseLookupAction.CaseRequest>{
            buildRequest(existingCase.CaseNumber)
        };

        Test.startTest();
        List<CaseLookupAction.CaseResult> results = CaseLookupAction.getCaseDetails(
            requests
        );
        Test.stopTest();

        System.assertEquals(
            1,
            results.size(),
            'Exactly one CaseResult should be returned for one request'
        );

        CaseLookupAction.CaseResult result = results[0];

        System.assertEquals(
            true,
            result.caseFound,
            'caseFound must be true when the case exists'
        );
        System.assertNotEquals(
            null,
            result.caseId,
            'caseId must be populated when the case is found'
        );
        System.assertEquals(
            CASE_SUBJECT,
            result.subject,
            'subject must match the inserted Case subject'
        );
        System.assertEquals(
            CASE_STATUS,
            result.status,
            'status must match the inserted Case status'
        );
        System.assertEquals(
            CASE_PRIORITY,
            result.priority,
            'priority must match the inserted Case priority'
        );
        System.assertEquals(
            CASE_DESC,
            result.description,
            'description must match the inserted Case description'
        );
        System.assertEquals(
            ACCOUNT_NAME,
            result.accountName,
            'accountName must reflect the linked Account name'
        );
        System.assertNotEquals(
            null,
            result.ownerName,
            'ownerName must be populated from the Case owner'
        );
        System.assertNotEquals(
            null,
            result.createdDate,
            'createdDate must be populated as a date string'
        );
        System.assertNotEquals(
            null,
            result.lastModifiedDate,
            'lastModifiedDate must be populated as a date string'
        );
        System.assertEquals(
            null,
            result.errorMessage,
            'errorMessage must be null when the case is found successfully'
        );
    }

    /**
     * @description getCaseDetails must trim leading/trailing whitespace from
     *              the supplied CaseNumber before querying. A CaseNumber padded
     *              with spaces must still resolve to the same Case as the exact
     *              CaseNumber.
     */
    @IsTest
    static void getCaseDetails_caseNumberWithWhitespace_trimsAndFindsCase() {
        Case existingCase = getTestCase();
        String paddedNumber = '  ' + existingCase.CaseNumber + '  ';

        List<CaseLookupAction.CaseRequest> requests = new List<CaseLookupAction.CaseRequest>{
            buildRequest(paddedNumber)
        };

        Test.startTest();
        List<CaseLookupAction.CaseResult> results = CaseLookupAction.getCaseDetails(
            requests
        );
        Test.stopTest();

        System.assertEquals(
            1,
            results.size(),
            'One result should be returned for the padded request'
        );
        System.assertEquals(
            true,
            results[0].caseFound,
            'caseFound must be true after trimming whitespace from the CaseNumber'
        );
    }

    // =========================================================================
    // Case without linked Account — accountName null-safe navigation
    // =========================================================================

    /**
     * @description When a Case is not linked to an Account, the accountName
     *              field in the result must be null (null-safe navigation),
     *              and caseFound must still be true.
     */
    @IsTest
    static void getCaseDetails_caseWithoutAccount_accountNameIsNull() {
        Case unlinkedCase = new Case(
            Subject = 'No Account Case',
            Status = CASE_STATUS,
            Priority = CASE_PRIORITY,
            Origin = CASE_ORIGIN
        );
        Database.insert(unlinkedCase, AccessLevel.SYSTEM_MODE);

        Case queried = [
            SELECT Id, CaseNumber
            FROM Case
            WHERE Subject = 'No Account Case'
            WITH USER_MODE
            LIMIT 1
        ];

        List<CaseLookupAction.CaseRequest> requests = new List<CaseLookupAction.CaseRequest>{
            buildRequest(queried.CaseNumber)
        };

        Test.startTest();
        List<CaseLookupAction.CaseResult> results = CaseLookupAction.getCaseDetails(
            requests
        );
        Test.stopTest();

        System.assertEquals(
            1,
            results.size(),
            'One result should be returned for the unlinked Case request'
        );
        System.assertEquals(
            true,
            results[0].caseFound,
            'caseFound must be true even when no Account is linked'
        );
        System.assertEquals(
            null,
            results[0].accountName,
            'accountName must be null when the Case has no linked Account'
        );
    }

    // =========================================================================
    // Negative path — non-existent CaseNumber returns caseFound = false
    // =========================================================================

    /**
     * @description Calling getCaseDetails with a CaseNumber that does not exist
     *              in the database must return caseFound = false and set an
     *              appropriate error message. No exception should propagate.
     */
    @IsTest
    static void getCaseDetails_nonExistentCaseNumber_returnsCaseFoundFalse() {
        List<CaseLookupAction.CaseRequest> requests = new List<CaseLookupAction.CaseRequest>{
            buildRequest(NONEXISTENT_NUM)
        };

        Test.startTest();
        List<CaseLookupAction.CaseResult> results = CaseLookupAction.getCaseDetails(
            requests
        );
        Test.stopTest();

        System.assertEquals(
            1,
            results.size(),
            'Exactly one CaseResult should be returned even when the case is not found'
        );

        CaseLookupAction.CaseResult result = results[0];

        System.assertEquals(
            false,
            result.caseFound,
            'caseFound must be false when no matching Case exists'
        );
        System.assertNotEquals(
            null,
            result.errorMessage,
            'errorMessage must be set when the case is not found'
        );
        System.assertEquals(
            true,
            result.errorMessage.contains(NONEXISTENT_NUM),
            'errorMessage must reference the supplied CaseNumber'
        );
        System.assertEquals(
            null,
            result.caseId,
            'caseId must be null when no Case is found'
        );
        System.assertEquals(
            null,
            result.subject,
            'subject must be null when no Case is found'
        );
    }

    // =========================================================================
    // Null / empty input — graceful exception handling
    // =========================================================================

    /**
     * @description Passing a null caseNumber causes req.caseNumber.trim() to
     *              throw a NullPointerException. The catch block must intercept
     *              this and return caseFound = false with an errorMessage.
     *              The method must not throw an unhandled exception.
     */
    @IsTest
    static void getCaseDetails_nullCaseNumber_returnsCaseFoundFalseWithError() {
        List<CaseLookupAction.CaseRequest> requests = new List<CaseLookupAction.CaseRequest>{
            buildRequest(null)
        };

        Test.startTest();
        List<CaseLookupAction.CaseResult> results = CaseLookupAction.getCaseDetails(
            requests
        );
        Test.stopTest();

        System.assertEquals(
            1,
            results.size(),
            'One CaseResult should be returned even for a null caseNumber input'
        );

        CaseLookupAction.CaseResult result = results[0];

        System.assertEquals(
            false,
            result.caseFound,
            'caseFound must be false when caseNumber is null'
        );
        System.assertNotEquals(
            null,
            result.errorMessage,
            'errorMessage must be populated describing the exception'
        );
        System.assertEquals(
            true,
            result.errorMessage.startsWith('Error retrieving case:'),
            'errorMessage must begin with the standard error prefix from the catch block'
        );
    }

    /**
     * @description Passing an empty-string caseNumber causes the SOQL WHERE
     *              clause to find no matching Case (no real Case has CaseNumber = '').
     *              The method must return caseFound = false with an appropriate
     *              error message and must not throw an exception.
     */
    @IsTest
    static void getCaseDetails_emptyCaseNumber_returnsCaseFoundFalse() {
        List<CaseLookupAction.CaseRequest> requests = new List<CaseLookupAction.CaseRequest>{
            buildRequest('')
        };

        Test.startTest();
        List<CaseLookupAction.CaseResult> results = CaseLookupAction.getCaseDetails(
            requests
        );
        Test.stopTest();

        System.assertEquals(
            1,
            results.size(),
            'One CaseResult should be returned for an empty caseNumber'
        );
        System.assertEquals(
            false,
            results[0].caseFound,
            'caseFound must be false when caseNumber is an empty string'
        );
        System.assertNotEquals(
            null,
            results[0].errorMessage,
            'errorMessage must be set when no Case matches an empty string CaseNumber'
        );
    }

    // =========================================================================
    // Bulk invocation — multiple CaseRequest items in a single call
    // =========================================================================

    /**
     * @description getCaseDetails must process multiple CaseRequest items in a
     *              single invocation and return one CaseResult per request in
     *              the same order. Valid case numbers resolve to caseFound = true
     *              and invalid ones resolve to caseFound = false.
     */
    @IsTest
    static void getCaseDetails_bulkMixedRequests_eachResolvedIndependently() {
        Case existingCase = getTestCase();

        // Build 3 requests: valid, nonexistent, null
        List<CaseLookupAction.CaseRequest> requests = new List<CaseLookupAction.CaseRequest>{
            buildRequest(existingCase.CaseNumber),
            buildRequest(NONEXISTENT_NUM),
            buildRequest(null)
        };

        Test.startTest();
        List<CaseLookupAction.CaseResult> results = CaseLookupAction.getCaseDetails(
            requests
        );
        Test.stopTest();

        System.assertEquals(
            3,
            results.size(),
            'Three CaseResult entries should be returned for three requests'
        );

        // Request 0: valid case number
        System.assertEquals(
            true,
            results[0].caseFound,
            'First result (valid CaseNumber) must have caseFound = true'
        );
        System.assertEquals(
            CASE_SUBJECT,
            results[0].subject,
            'First result must carry the correct Case subject'
        );

        // Request 1: non-existent case number
        System.assertEquals(
            false,
            results[1].caseFound,
            'Second result (non-existent CaseNumber) must have caseFound = false'
        );
        System.assertNotEquals(
            null,
            results[1].errorMessage,
            'Second result must carry a not-found error message'
        );

        // Request 2: null case number — handled by catch block
        System.assertEquals(
            false,
            results[2].caseFound,
            'Third result (null caseNumber) must have caseFound = false'
        );
        System.assertNotEquals(
            null,
            results[2].errorMessage,
            'Third result must carry an error message from the exception handler'
        );
    }

    /**
     * @description Bulk invocation of 200 requests each pointing to the same
     *              existing CaseNumber must all return caseFound = true. This
     *              verifies there are no governor limit issues with the per-item
     *              SOQL loop at scale.
     */
    @IsTest
    static void getCaseDetails_bulk200ValidRequests_allReturnCaseFoundTrue() {
        Case existingCase = getTestCase();

        List<CaseLookupAction.CaseRequest> requests = new List<CaseLookupAction.CaseRequest>();
        for (Integer i = 0; i < 200; i++) {
            requests.add(buildRequest(existingCase.CaseNumber));
        }

        Test.startTest();
        List<CaseLookupAction.CaseResult> results = CaseLookupAction.getCaseDetails(
            requests
        );
        Test.stopTest();

        System.assertEquals(
            200,
            results.size(),
            '200 CaseResult entries should be returned for 200 requests'
        );

        Integer foundCount = 0;
        for (CaseLookupAction.CaseResult r : results) {
            if (r.caseFound) {
                foundCount++;
            }
        }

        System.assertEquals(
            200,
            foundCount,
            'All 200 results must have caseFound = true for a valid CaseNumber'
        );
    }
}
