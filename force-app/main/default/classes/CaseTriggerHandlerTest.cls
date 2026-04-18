/**
 * @description Test class for CaseTriggerHandler.
 *              Validates duplicate Case prevention logic covering:
 *              - Unique key inserts succeed (positive path)
 *              - DB duplicate detection via composite key (Subject + AccountId + ContactId + Origin)
 *              - Within-batch duplicate detection (second record in same DML batch fails)
 *              - Null field handling (AccountId, ContactId, Origin all null-safe)
 *              - Non-duplicate variations on Subject and Origin are allowed
 *              - Closed Cases are excluded from the duplicate query so a re-open is allowed
 *              - Recursion guard prevents re-entry
 *              - Bulk scenario (200 unique records all succeed)
 *
 *              DML uses AccessLevel.SYSTEM_MODE because the running test user may
 *              lack FLS on fields involved in the composite key check.
 *
 *              The recursion guard (hasRunBeforeInsert) is reset between pre-insert
 *              setup DML and the test DML so the handler fires for both.
 *
 * @see CaseTriggerHandler
 * @see CaseTrigger
 */
@IsTest
private with sharing class CaseTriggerHandlerTest {
    // --- Constants -----------------------------------------------------------

    private static final String CASE_SUBJECT = 'Billing Issue';
    private static final String CASE_ORIGIN = 'Phone';
    private static final String ALT_ORIGIN = 'Web';
    private static final String ALT_SUBJECT = 'Shipping Issue';
    private static final String STATUS_OPEN = 'New';
    private static final String STATUS_CLOSED = 'Closed';

    // --- @TestSetup: shared Account and Contact ------------------------------

    /**
     * @description Creates a shared Account and Contact used by most test methods.
     *              Each test method queries these back to avoid redundant DML.
     */
    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Corp');
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id
        );
        Database.insert(con, AccessLevel.SYSTEM_MODE);
    }

    // --- Helpers: query setup data -------------------------------------------

    private static Account getTestAccount() {
        return [SELECT Id FROM Account LIMIT 1];
    }

    private static Contact getTestContact() {
        return [SELECT Id FROM Contact LIMIT 1];
    }

    // --- Helper: build a Case (not inserted) with all composite-key fields ---

    private static Case buildCase(
        String subject,
        Id accountId,
        Id contactId,
        String origin
    ) {
        return new Case(
            Subject = subject,
            AccountId = accountId,
            ContactId = contactId,
            Origin = origin,
            Status = STATUS_OPEN
        );
    }

    // --- Helper: reset the recursion guard between DML calls -----------------

    private static void resetGuard() {
        CaseTriggerHandler.hasRunBeforeInsert = false;
    }

    // =========================================================================
    // Positive scenario -- unique key succeeds
    // =========================================================================

    /**
     * @description Inserting a Case with a Subject + AccountId + ContactId + Origin
     *              combination that does not exist in the database must succeed with
     *              no errors. This validates the happy-path baseline.
     */
    @IsTest
    static void insert_uniqueCompositeKey_succeeds() {
        Account acc = getTestAccount();
        Contact con = getTestContact();
        resetGuard();

        Case newCase = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            newCase,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            sr.isSuccess(),
            'Inserting a Case with a unique composite key should succeed'
        );
        Assert.isTrue(
            sr.getErrors().isEmpty(),
            'No errors should be returned for a unique composite key'
        );
    }

    // =========================================================================
    // DB duplicate -- same key already exists as open Case
    // =========================================================================

    /**
     * @description Inserting a Case whose Subject + AccountId + ContactId + Origin
     *              matches an existing OPEN Case must fail with the duplicate error message.
     *              Verifies database-level duplicate detection.
     */
    @IsTest
    static void insert_duplicateKeyMatchesExistingOpenCase_failsWithError() {
        Account acc = getTestAccount();
        Contact con = getTestContact();

        // Pre-insert the existing open Case
        Case existing = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);
        Database.insert(existing, AccessLevel.SYSTEM_MODE);
        resetGuard();

        // Attempt to insert a duplicate
        Case duplicate = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            duplicate,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isFalse(
            sr.isSuccess(),
            'Inserting a Case with the same composite key as an open Case should fail'
        );
        Assert.isFalse(
            sr.getErrors().isEmpty(),
            'At least one error should be returned for a DB-level duplicate'
        );
        Assert.isTrue(
            sr.getErrors()[0]
                .getMessage()
                .contains(CaseTriggerHandler.DUPLICATE_ERROR_MESSAGE),
            'The error message must match the DUPLICATE_ERROR_MESSAGE constant'
        );
    }

    /**
     * @description The composite-key Subject comparison is case-insensitive.
     *              Inserting a Case whose Subject differs only in case from an
     *              existing open Case must be detected as a duplicate.
     */
    @IsTest
    static void insert_duplicateKeySubjectDifferentCase_failsWithError() {
        Account acc = getTestAccount();
        Contact con = getTestContact();

        // Pre-insert with mixed-case subject
        Case existing = buildCase('billing issue', acc.Id, con.Id, CASE_ORIGIN);
        Database.insert(existing, AccessLevel.SYSTEM_MODE);
        resetGuard();

        // Attempt duplicate with uppercase subject
        Case duplicate = buildCase(
            'BILLING ISSUE',
            acc.Id,
            con.Id,
            CASE_ORIGIN
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            duplicate,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isFalse(
            sr.isSuccess(),
            'Subject comparison in the composite key must be case-insensitive'
        );
        Assert.isTrue(
            sr.getErrors()[0]
                .getMessage()
                .contains(CaseTriggerHandler.DUPLICATE_ERROR_MESSAGE),
            'The duplicate error must fire for a case-insensitive subject match'
        );
    }

    // =========================================================================
    // Within-batch duplicate -- two Cases with same key in one DML call
    // =========================================================================

    /**
     * @description When two Cases with the same composite key are submitted in the
     *              same DML batch, the first must succeed and the second must fail
     *              with the duplicate error message. Verifies within-batch detection.
     */
    @IsTest
    static void insert_withinBatchDuplicateKey_secondRecordFails() {
        Account acc = getTestAccount();
        Contact con = getTestContact();
        resetGuard();

        Case first = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);
        Case second = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);
        List<Case> batch = new List<Case>{ first, second };

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(
            batch,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            results[0].isSuccess(),
            'The first Case in the batch should succeed as its key has not been seen yet'
        );
        Assert.isFalse(
            results[1].isSuccess(),
            'The second Case in the batch should fail as it duplicates the first'
        );
        Assert.isTrue(
            results[1].getErrors()[0]
                .getMessage()
                .contains(CaseTriggerHandler.DUPLICATE_ERROR_MESSAGE),
            'The within-batch duplicate error message must match DUPLICATE_ERROR_MESSAGE'
        );
    }

    // =========================================================================
    // Null field handling
    // =========================================================================

    /**
     * @description A Case with null AccountId, null ContactId, and null Origin
     *              must insert successfully without any exception.
     *              Verifies that buildCompositeKey handles null fields gracefully.
     */
    @IsTest
    static void insert_allNullKeyFields_succeedsWithoutException() {
        // Origin is a required picklist in some orgs; build with explicit null override
        Case newCase = new Case(
            Subject = CASE_SUBJECT,
            AccountId = null,
            ContactId = null,
            Status = STATUS_OPEN
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            newCase,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            sr.isSuccess(),
            'A Case with null AccountId, ContactId, and Origin must insert without handler errors'
        );
    }

    /**
     * @description Two Cases with null AccountId, null ContactId, and null Origin
     *              but the SAME Subject submitted in the same batch: the second must
     *              fail. This confirms null fields participate in the composite key
     *              as empty strings and that duplicates are still caught.
     */
    @IsTest
    static void insert_withinBatchDuplicateKey_allNullFields_secondRecordFails() {
        resetGuard();

        Case first = new Case(
            Subject = CASE_SUBJECT,
            AccountId = null,
            ContactId = null,
            Status = STATUS_OPEN
        );
        Case second = new Case(
            Subject = CASE_SUBJECT,
            AccountId = null,
            ContactId = null,
            Status = STATUS_OPEN
        );
        List<Case> batch = new List<Case>{ first, second };

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(
            batch,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            results[0].isSuccess(),
            'First Case with all-null key fields should succeed'
        );
        Assert.isFalse(
            results[1].isSuccess(),
            'Second Case with identical all-null composite key should fail as a duplicate'
        );
    }

    /**
     * @description A Case with only null AccountId (ContactId and Origin populated)
     *              must not throw an exception, proving the accountId null guard works.
     */
    @IsTest
    static void insert_nullAccountId_succeedsWithoutException() {
        Contact con = getTestContact();
        resetGuard();

        Case newCase = buildCase(CASE_SUBJECT, null, con.Id, CASE_ORIGIN);

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            newCase,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            sr.isSuccess(),
            'Inserting a Case with null AccountId should not cause a handler exception'
        );
    }

    /**
     * @description A Case with only null ContactId (AccountId and Origin populated)
     *              must not throw an exception, proving the contactId null guard works.
     */
    @IsTest
    static void insert_nullContactId_succeedsWithoutException() {
        Account acc = getTestAccount();
        resetGuard();

        Case newCase = buildCase(CASE_SUBJECT, acc.Id, null, CASE_ORIGIN);

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            newCase,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            sr.isSuccess(),
            'Inserting a Case with null ContactId should not cause a handler exception'
        );
    }

    // =========================================================================
    // Different Subject / Origin treated as non-duplicates
    // =========================================================================

    /**
     * @description A Case with the same AccountId + ContactId + Origin but a
     *              DIFFERENT Subject must succeed -- it is not a duplicate.
     *              Verifies that Subject is a required part of the composite key.
     */
    @IsTest
    static void insert_differentSubject_isNotADuplicate() {
        Account acc = getTestAccount();
        Contact con = getTestContact();

        Case existing = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);
        Database.insert(existing, AccessLevel.SYSTEM_MODE);
        resetGuard();

        Case different = buildCase(ALT_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            different,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            sr.isSuccess(),
            'A Case with a different Subject should not be flagged as a duplicate'
        );
        Assert.isTrue(
            sr.getErrors().isEmpty(),
            'No errors should be returned when Subject differs'
        );
    }

    /**
     * @description A Case with the same Subject + AccountId + ContactId but a
     *              DIFFERENT Origin must succeed -- it is not a duplicate.
     *              Verifies that Origin is a required part of the composite key.
     */
    @IsTest
    static void insert_differentOrigin_isNotADuplicate() {
        Account acc = getTestAccount();
        Contact con = getTestContact();

        Case existing = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);
        Database.insert(existing, AccessLevel.SYSTEM_MODE);
        resetGuard();

        Case different = buildCase(CASE_SUBJECT, acc.Id, con.Id, ALT_ORIGIN);

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            different,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            sr.isSuccess(),
            'A Case with a different Origin should not be flagged as a duplicate'
        );
        Assert.isTrue(
            sr.getErrors().isEmpty(),
            'No errors should be returned when Origin differs'
        );
    }

    // =========================================================================
    // Closed Case excluded from duplicate check
    // =========================================================================

    /**
     * @description An existing Case with the same composite key that has been
     *              closed (IsClosed = true) must NOT block a new Case with the
     *              same key. The handler only queries open Cases (IsClosed = false).
     */
    @IsTest
    static void insert_duplicateKeyButExistingCaseIsClosed_succeeds() {
        Account acc = getTestAccount();
        Contact con = getTestContact();

        // Insert the first Case
        Case existing = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);
        Database.insert(existing, AccessLevel.SYSTEM_MODE);

        // Close the existing Case by updating its Status to 'Closed'
        existing.Status = STATUS_CLOSED;
        resetGuard();
        Database.update(existing, AccessLevel.SYSTEM_MODE);

        // Verify it is now closed before proceeding
        Case closed = [
            SELECT Id, IsClosed
            FROM Case
            WHERE Id = :existing.Id
            WITH USER_MODE
            LIMIT 1
        ];
        Assert.isTrue(
            closed.IsClosed,
            'Precondition: the existing Case must be closed before the new insert'
        );

        resetGuard();

        // Now insert a new Case with the same composite key
        Case newCase = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            newCase,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            sr.isSuccess(),
            'Inserting a Case whose composite key matches only a CLOSED Case should succeed'
        );
        Assert.isTrue(
            sr.getErrors().isEmpty(),
            'No errors should be returned when the matching existing Case is closed'
        );
    }

    // =========================================================================
    // Recursion guard
    // =========================================================================

    /**
     * @description When hasRunBeforeInsert is already true, beforeInsert must
     *              return immediately without calling preventDuplicateCases.
     *              This means even a "duplicate" can insert successfully when the
     *              guard is pre-set (the guard protects against re-entry, not logic
     *              skipping in production -- but verifies the guard branch executes).
     */
    @IsTest
    static void insert_recursionGuardActive_handlerSkipsLogic() {
        Account acc = getTestAccount();
        Contact con = getTestContact();

        // Pre-insert to create an existing open Case
        Case existing = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);
        Database.insert(existing, AccessLevel.SYSTEM_MODE);

        // Set the guard to true -- beforeInsert will return early
        CaseTriggerHandler.hasRunBeforeInsert = true;

        // Even a "duplicate" must succeed because the guard skips the check
        Case duplicate = buildCase(CASE_SUBJECT, acc.Id, con.Id, CASE_ORIGIN);

        Test.startTest();
        Database.SaveResult sr = Database.insert(
            duplicate,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Assert.isTrue(
            sr.isSuccess(),
            'When hasRunBeforeInsert is true, the handler must skip duplicate checking -- insert succeeds'
        );
        Assert.isTrue(
            sr.getErrors().isEmpty(),
            'No errors should be returned when the recursion guard is active'
        );
    }

    // =========================================================================
    // Bulk scenario -- 200 unique Cases all succeed
    // =========================================================================

    /**
     * @description Bulk insert of 200 Cases each with a unique Subject must all
     *              succeed, verifying that the handler processes large batches
     *              without hitting governor limits or producing false positives.
     */
    @IsTest
    static void bulkInsert_200UniqueCases_allSucceed() {
        Account acc = getTestAccount();
        Contact con = getTestContact();
        resetGuard();

        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(
                buildCase('Bulk Subject ' + i, acc.Id, con.Id, CASE_ORIGIN)
            );
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(
            cases,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Integer successCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            }
        }

        Assert.areEqual(
            200,
            successCount,
            'All 200 Cases with unique composite keys should insert successfully'
        );
    }

    /**
     * @description Bulk insert of 200 Cases where every other Case is a duplicate
     *              of the preceding one. Verifies within-batch detection at scale:
     *              odd-indexed records (0, 2, 4, ...) succeed;
     *              even-indexed duplicates (1, 3, 5, ...) fail.
     */
    @IsTest
    static void bulkInsert_200CasesHalfDuplicates_halfFailWithError() {
        Account acc = getTestAccount();
        Contact con = getTestContact();
        resetGuard();

        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 200; i++) {
            // Even index = unique subject; odd index = duplicate of preceding even
            String subject = 'Bulk Half Subject ' + (i / 2);
            cases.add(buildCase(subject, acc.Id, con.Id, CASE_ORIGIN));
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(
            cases,
            false,
            AccessLevel.SYSTEM_MODE
        );
        Test.stopTest();

        Integer successCount = 0;
        Integer failCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            } else {
                failCount++;
            }
        }

        Assert.areEqual(
            100,
            successCount,
            '100 Cases with unique subjects should succeed in the bulk batch'
        );
        Assert.areEqual(
            100,
            failCount,
            '100 Cases that duplicate the preceding record should fail in the bulk batch'
        );
    }
}
