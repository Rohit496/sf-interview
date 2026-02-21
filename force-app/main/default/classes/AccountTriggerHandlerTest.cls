/**
 * @description Test class for AccountTriggerHandler.
 *              Validates evaluateHealthRating (before insert/update) and
 *              createAtRiskTasks (after update) with positive, negative,
 *              null-safe, boundary, no-duplicate, and bulk scenarios.
 *
 *              DML uses AccessLevel.SYSTEM_MODE because the running test user
 *              may lack FLS on newly deployed custom fields. The trigger handler
 *              runs in before/after trigger contexts (system mode) so this
 *              accurately reflects production behaviour.
 *
 *              Recursion guards are reset before every update DML call so the
 *              handler fires as it would in a fresh transaction.
 *
 * @see AccountTriggerHandler
 * @see AccountTrigger
 */
@IsTest
private class AccountTriggerHandlerTest {

    // ─── Constants ───────────────────────────────────────────────────────────

    private static final String RATING_GOOD     = 'Good';
    private static final String RATING_AVERAGE  = 'Average';
    private static final String RATING_AT_RISK  = 'At Risk';
    private static final String AT_RISK_SUBJECT_PREFIX = 'Review At Risk Account: ';

    // Revenue / employee values that map cleanly to each tier
    private static final Decimal REVENUE_GOOD    = 15000000; // > 10M
    private static final Integer EMPLOYEES_GOOD  = 600;      // > 500
    private static final Decimal REVENUE_RISK    = 500000;   // < 1M
    private static final Integer EMPLOYEES_RISK  = 50;       // < 100
    private static final Decimal REVENUE_AVG     = 5000000;  // between thresholds
    private static final Integer EMPLOYEES_AVG   = 300;      // between thresholds

    // ─── Helper: build an Account (not inserted) ─────────────────────────────

    private static Account buildAccount(String name, Decimal revenue, Integer employees) {
        return new Account(
            Name              = name,
            AnnualRevenue     = revenue,
            NumberOfEmployees = employees
        );
    }

    // ─── Helper: query an Account with assertion fields ───────────────────────

    private static Account queryAccount(Id accountId) {
        return [
            SELECT Id, Health_Rating__c, Health_Evaluated_Date__c, OwnerId
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];
    }

    // ─── Helper: reset recursion guards for a fresh update transaction ────────

    private static void resetGuards() {
        AccountTriggerHandler.hasRunBefore = false;
        AccountTriggerHandler.hasRunAfter  = false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // evaluateHealthRating — INSERT scenarios
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @description Insert with revenue > $10M and employees > 500 must produce
     *              Health_Rating__c = 'Good' and stamp Health_Evaluated_Date__c.
     */
    @IsTest
    static void insert_goodThresholds_setsGoodRating() {
        Account acc = buildAccount('Good Corp', REVENUE_GOOD, EMPLOYEES_GOOD);

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Insert should succeed for a Good-tier account');

        Account result = queryAccount(sr.getId());
        Assert.areEqual(RATING_GOOD, result.Health_Rating__c,
            'Health_Rating__c should be Good when revenue > $10M and employees > 500');
        Assert.isNotNull(result.Health_Evaluated_Date__c,
            'Health_Evaluated_Date__c should be stamped on insert');
    }

    /**
     * @description Insert with revenue < $1M and employees < 100 must produce
     *              Health_Rating__c = 'At Risk' and stamp Health_Evaluated_Date__c.
     */
    @IsTest
    static void insert_atRiskThresholds_setsAtRiskRating() {
        Account acc = buildAccount('At Risk Corp', REVENUE_RISK, EMPLOYEES_RISK);

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Insert should succeed for an At-Risk-tier account');

        Account result = queryAccount(sr.getId());
        Assert.areEqual(RATING_AT_RISK, result.Health_Rating__c,
            'Health_Rating__c should be At Risk when revenue < $1M and employees < 100');
        Assert.isNotNull(result.Health_Evaluated_Date__c,
            'Health_Evaluated_Date__c should be stamped on insert');
    }

    /**
     * @description Insert with revenue and employees in the middle band must
     *              produce Health_Rating__c = 'Average'.
     */
    @IsTest
    static void insert_averageThresholds_setsAverageRating() {
        Account acc = buildAccount('Average Corp', REVENUE_AVG, EMPLOYEES_AVG);

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Insert should succeed for an Average-tier account');

        Account result = queryAccount(sr.getId());
        Assert.areEqual(RATING_AVERAGE, result.Health_Rating__c,
            'Health_Rating__c should be Average for mid-range revenue and employees');
        Assert.isNotNull(result.Health_Evaluated_Date__c,
            'Health_Evaluated_Date__c should be stamped on insert');
    }

    /**
     * @description Insert with high revenue but low employees must fall through
     *              to Average — Good requires BOTH thresholds to be exceeded.
     */
    @IsTest
    static void insert_highRevenueButLowEmployees_setsAverageRating() {
        Account acc = buildAccount('Half Good Corp', REVENUE_GOOD, EMPLOYEES_RISK);

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Insert should succeed');

        Account result = queryAccount(sr.getId());
        Assert.areEqual(RATING_AVERAGE, result.Health_Rating__c,
            'Health_Rating__c should be Average when only revenue meets the Good threshold');
    }

    /**
     * @description Insert with low revenue but high employees must also fall
     *              through to Average — At Risk requires BOTH to be below threshold.
     */
    @IsTest
    static void insert_lowRevenueButHighEmployees_setsAverageRating() {
        Account acc = buildAccount('Half Risk Corp', REVENUE_RISK, EMPLOYEES_GOOD);

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Insert should succeed');

        Account result = queryAccount(sr.getId());
        Assert.areEqual(RATING_AVERAGE, result.Health_Rating__c,
            'Health_Rating__c should be Average when only employees meets the At-Risk threshold');
    }

    /**
     * @description Insert with null AnnualRevenue and null NumberOfEmployees must
     *              treat both as 0 (< $1M and < 100) and produce 'At Risk'.
     *              Verifies the null-safety guards: revenue != null ? revenue : 0.
     */
    @IsTest
    static void insert_nullRevenueAndEmployees_treatsAsZeroAndSetsAtRiskRating() {
        Account acc = buildAccount('Null Fields Corp', null, null);

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Insert should succeed when revenue and employees are null');

        Account result = queryAccount(sr.getId());
        Assert.areEqual(RATING_AT_RISK, result.Health_Rating__c,
            'Null revenue and employees should be treated as 0, producing At Risk rating');
        Assert.isNotNull(result.Health_Evaluated_Date__c,
            'Health_Evaluated_Date__c should be stamped even when inputs are null');
    }

    /**
     * @description Insert with null AnnualRevenue only (employees > 500) must
     *              produce Average because only the employee count is high.
     */
    @IsTest
    static void insert_nullRevenueWithHighEmployees_setsAverageRating() {
        Account acc = buildAccount('Null Revenue Corp', null, EMPLOYEES_GOOD);

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Insert should succeed when revenue is null');

        Account result = queryAccount(sr.getId());
        Assert.areEqual(RATING_AVERAGE, result.Health_Rating__c,
            'Null revenue treated as 0 (< $1M) with high employees should produce Average');
    }

    /**
     * @description Insert with null NumberOfEmployees only (revenue > $10M) must
     *              produce Average because employees defaults to 0 (not > 500).
     */
    @IsTest
    static void insert_nullEmployeesWithHighRevenue_setsAverageRating() {
        Account acc = buildAccount('Null Emp Corp', REVENUE_GOOD, null);

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Insert should succeed when employees is null');

        Account result = queryAccount(sr.getId());
        Assert.areEqual(RATING_AVERAGE, result.Health_Rating__c,
            'Null employees treated as 0 with high revenue should produce Average (not Good)');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // evaluateHealthRating — UPDATE scenarios
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @description When AnnualRevenue and NumberOfEmployees do NOT change during
     *              an update, the handler must skip re-evaluation — Health_Rating__c
     *              and Health_Evaluated_Date__c must remain as they were after insert.
     */
    @IsTest
    static void update_noChangeToRevenueOrEmployees_doesNotReStampRating() {
        Account acc = buildAccount('Stable Corp', REVENUE_GOOD, EMPLOYEES_GOOD);
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Account inserted = queryAccount(acc.Id);
        DateTime evaluatedAfterInsert = inserted.Health_Evaluated_Date__c;

        resetGuards();

        // Change a field that is not AnnualRevenue or NumberOfEmployees
        acc.Name = 'Stable Corp Updated';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Update should succeed');

        Account result = queryAccount(acc.Id);
        Assert.areEqual(RATING_GOOD, result.Health_Rating__c,
            'Health_Rating__c should remain unchanged when revenue and employees did not change');
        Assert.areEqual(evaluatedAfterInsert, result.Health_Evaluated_Date__c,
            'Health_Evaluated_Date__c should not be re-stamped when relevant fields did not change');
    }

    /**
     * @description When AnnualRevenue changes to Good-tier values, the rating
     *              must be re-evaluated to 'Good' and the date re-stamped.
     */
    @IsTest
    static void update_revenueChangesToGoodTier_setsGoodRating() {
        Account acc = buildAccount('Improving Corp', REVENUE_AVG, EMPLOYEES_GOOD);
        Database.insert(acc, AccessLevel.SYSTEM_MODE);
        resetGuards();

        acc.AnnualRevenue = REVENUE_GOOD; // Crosses Good threshold

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Update should succeed');

        Account result = queryAccount(acc.Id);
        Assert.areEqual(RATING_GOOD, result.Health_Rating__c,
            'Health_Rating__c should update to Good after revenue crosses the $10M threshold');
        Assert.isNotNull(result.Health_Evaluated_Date__c,
            'Health_Evaluated_Date__c should be re-stamped after re-evaluation');
    }

    /**
     * @description When NumberOfEmployees changes to At-Risk-tier, the rating
     *              must be re-evaluated to 'At Risk' and the date re-stamped.
     */
    @IsTest
    static void update_employeesChangesToAtRiskTier_setsAtRiskRating() {
        Account acc = buildAccount('Shrinking Corp', REVENUE_RISK, EMPLOYEES_AVG);
        Database.insert(acc, AccessLevel.SYSTEM_MODE);
        resetGuards();

        acc.NumberOfEmployees = EMPLOYEES_RISK; // Drops below At-Risk threshold

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Update should succeed');

        Account result = queryAccount(acc.Id);
        Assert.areEqual(RATING_AT_RISK, result.Health_Rating__c,
            'Health_Rating__c should update to At Risk after employees drop below 100');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // createAtRiskTasks — UPDATE scenarios
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @description When Health_Rating__c transitions from non-At-Risk to 'At Risk'
     *              during an update, a Task must be created with the correct Subject,
     *              ActivityDate, Status, Priority, OwnerId, and WhatId.
     */
    @IsTest
    static void update_ratingChangesToAtRisk_createsTask() {
        // Start with a Good account (insert sets Good automatically)
        Account acc = buildAccount('At Risk Bound Corp', REVENUE_GOOD, EMPLOYEES_GOOD);
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Account inserted = queryAccount(acc.Id);
        Assert.areEqual(RATING_GOOD, inserted.Health_Rating__c,
            'Precondition: account must start as Good before the transition');
        resetGuards();

        // Drive both revenue and employees below At-Risk thresholds on update
        acc.AnnualRevenue     = REVENUE_RISK;
        acc.NumberOfEmployees = EMPLOYEES_RISK;

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Update should succeed');

        Account updated = queryAccount(acc.Id);
        Assert.areEqual(RATING_AT_RISK, updated.Health_Rating__c,
            'Health_Rating__c should be At Risk after the update');

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, Priority, OwnerId, WhatId
            FROM Task
            WHERE WhatId = :acc.Id
            WITH USER_MODE
        ];
        Assert.areEqual(1, tasks.size(),
            'Exactly one Task should be created when rating transitions to At Risk');

        Task t = tasks[0];
        Assert.areEqual(AT_RISK_SUBJECT_PREFIX + acc.Name, t.Subject,
            'Task Subject should include the Account Name after the prefix');
        Assert.areEqual(Date.today().addDays(3), t.ActivityDate,
            'Task ActivityDate should be today + 3 days');
        Assert.areEqual('Not Started', t.Status,
            'Task Status should be Not Started');
        Assert.areEqual('High', t.Priority,
            'Task Priority should be High');
        Assert.areEqual(updated.OwnerId, t.OwnerId,
            'Task OwnerId should match the Account OwnerId');
        Assert.areEqual(acc.Id, t.WhatId,
            'Task WhatId should reference the Account');
    }

    /**
     * @description When Health_Rating__c was already 'At Risk' before the update
     *              (no transition), no Task must be created to avoid duplicates.
     */
    @IsTest
    static void update_ratingStaysAtRisk_doesNotCreateDuplicateTask() {
        // Insert an At-Risk account directly
        Account acc = buildAccount('Already At Risk Corp', REVENUE_RISK, EMPLOYEES_RISK);
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Account inserted = queryAccount(acc.Id);
        Assert.areEqual(RATING_AT_RISK, inserted.Health_Rating__c,
            'Precondition: account must start as At Risk');
        resetGuards();

        // Update a field that does not change the rating tier
        acc.Name = 'Still At Risk Corp';

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Update should succeed');

        List<Task> tasks = [
            SELECT Id FROM Task WHERE WhatId = :acc.Id WITH USER_MODE
        ];
        Assert.isTrue(tasks.isEmpty(),
            'No Task should be created when Health_Rating__c stays At Risk (no transition)');
    }

    /**
     * @description When Health_Rating__c transitions from 'At Risk' to 'Good',
     *              no Task must be created because the rating is moving away from At Risk.
     */
    @IsTest
    static void update_ratingChangesAwayFromAtRisk_doesNotCreateTask() {
        // Insert as At-Risk
        Account acc = buildAccount('Recovering Corp', REVENUE_RISK, EMPLOYEES_RISK);
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Account inserted = queryAccount(acc.Id);
        Assert.areEqual(RATING_AT_RISK, inserted.Health_Rating__c,
            'Precondition: account must start as At Risk');
        resetGuards();

        // Drive values above Good threshold — rating transitions to Good
        acc.AnnualRevenue     = REVENUE_GOOD;
        acc.NumberOfEmployees = EMPLOYEES_GOOD;

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Update should succeed');

        Account updated = queryAccount(acc.Id);
        Assert.areEqual(RATING_GOOD, updated.Health_Rating__c,
            'Health_Rating__c should be Good after recovery');

        List<Task> tasks = [
            SELECT Id FROM Task WHERE WhatId = :acc.Id WITH USER_MODE
        ];
        Assert.isTrue(tasks.isEmpty(),
            'No Task should be created when rating transitions away from At Risk');
    }

    /**
     * @description When Health_Rating__c transitions from 'Average' to 'At Risk',
     *              exactly one Task must be created (covers non-Good prior states).
     */
    @IsTest
    static void update_ratingFromAverageToAtRisk_createsTask() {
        // Insert as Average
        Account acc = buildAccount('Average Declining Corp', REVENUE_AVG, EMPLOYEES_AVG);
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Account inserted = queryAccount(acc.Id);
        Assert.areEqual(RATING_AVERAGE, inserted.Health_Rating__c,
            'Precondition: account must start as Average');
        resetGuards();

        acc.AnnualRevenue     = REVENUE_RISK;
        acc.NumberOfEmployees = EMPLOYEES_RISK;

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Update should succeed');

        List<Task> tasks = [
            SELECT Id FROM Task WHERE WhatId = :acc.Id WITH USER_MODE
        ];
        Assert.areEqual(1, tasks.size(),
            'One Task should be created when rating transitions from Average to At Risk');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Recursion guard — before context
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @description When hasRunBefore is true before insert, the handler must
     *              skip evaluateHealthRating — Health_Rating__c stays null.
     */
    @IsTest
    static void insert_recursionGuardBeforeActive_skipsEvaluation() {
        AccountTriggerHandler.hasRunBefore = true;

        Account acc = buildAccount('Skipped Corp', REVENUE_GOOD, EMPLOYEES_GOOD);

        Test.startTest();
        Database.SaveResult sr = Database.insert(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Insert should succeed even when before-guard is active');

        Account result = queryAccount(sr.getId());
        Assert.isNull(result.Health_Rating__c,
            'Health_Rating__c should be null when before recursion guard is active');
        Assert.isNull(result.Health_Evaluated_Date__c,
            'Health_Evaluated_Date__c should be null when before recursion guard is active');
    }

    /**
     * @description When hasRunAfter is true before update, the handler must
     *              skip createAtRiskTasks — no Task should be created.
     */
    @IsTest
    static void update_recursionGuardAfterActive_skipsTaskCreation() {
        // Insert a Good account without the guard
        Account acc = buildAccount('After Guard Corp', REVENUE_GOOD, EMPLOYEES_GOOD);
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        // Set only the after guard; leave before guard clear so evaluateHealthRating fires
        AccountTriggerHandler.hasRunBefore = false;
        AccountTriggerHandler.hasRunAfter  = true;

        acc.AnnualRevenue     = REVENUE_RISK;
        acc.NumberOfEmployees = EMPLOYEES_RISK;

        Test.startTest();
        Database.SaveResult sr = Database.update(acc, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Update should succeed');

        List<Task> tasks = [
            SELECT Id FROM Task WHERE WhatId = :acc.Id WITH USER_MODE
        ];
        Assert.isTrue(tasks.isEmpty(),
            'No Task should be created when the after recursion guard is already active');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Bulk scenarios — 200 records
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @description Bulk insert of 200 accounts with mixed revenue/employee profiles
     *              must correctly stamp Health_Rating__c on every record without
     *              hitting governor limits.
     */
    @IsTest
    static void bulkInsert_200Records_stampsCorrectRatings() {
        List<Account> accounts = new List<Account>();
        // Distribution: 0-66 Good, 67-133 Average, 134-199 At Risk
        for (Integer i = 0; i < 200; i++) {
            Decimal  rev;
            Integer  emp;
            if (i < 67) {
                rev = REVENUE_GOOD;
                emp = EMPLOYEES_GOOD;
            } else if (i < 134) {
                rev = REVENUE_AVG;
                emp = EMPLOYEES_AVG;
            } else {
                rev = REVENUE_RISK;
                emp = EMPLOYEES_RISK;
            }
            accounts.add(buildAccount('Bulk Corp ' + i, rev, emp));
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(accounts, true, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            Assert.isTrue(sr.isSuccess(), 'Every bulk insert should succeed');
        }

        // Query back and validate rating distribution
        Map<Id, Account> inserted = new Map<Id, Account>([
            SELECT Id, Health_Rating__c, Health_Evaluated_Date__c
            FROM Account
            WHERE Id IN :new Map<Id, Account>(accounts).keySet()
            WITH USER_MODE
        ]);

        Integer goodCount = 0;
        Integer avgCount  = 0;
        Integer riskCount = 0;
        for (Account a : inserted.values()) {
            Assert.isNotNull(a.Health_Evaluated_Date__c,
                'Health_Evaluated_Date__c must be stamped on every inserted account');
            if (a.Health_Rating__c == RATING_GOOD) {
                goodCount++;
            } else if (a.Health_Rating__c == RATING_AVERAGE) {
                avgCount++;
            } else if (a.Health_Rating__c == RATING_AT_RISK) {
                riskCount++;
            }
        }

        Assert.areEqual(67,  goodCount, 'Should be 67 Good accounts in bulk insert');
        Assert.areEqual(67,  avgCount,  'Should be 67 Average accounts in bulk insert');
        Assert.areEqual(66,  riskCount, 'Should be 66 At Risk accounts in bulk insert');
    }

    /**
     * @description Bulk update of 200 accounts — half transition to At Risk — must
     *              create exactly 100 Tasks and not create duplicates for the other half.
     */
    @IsTest
    static void bulkUpdate_halfTransitionToAtRisk_creates100Tasks() {
        // Insert 200 Good accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(buildAccount('Bulk Update Corp ' + i, REVENUE_GOOD, EMPLOYEES_GOOD));
        }
        Database.insert(accounts, true, AccessLevel.SYSTEM_MODE);
        resetGuards();

        // Drive the first 100 to At Risk; leave the other 100 as Good
        for (Integer i = 0; i < 200; i++) {
            if (i < 100) {
                accounts[i].AnnualRevenue     = REVENUE_RISK;
                accounts[i].NumberOfEmployees = EMPLOYEES_RISK;
            }
            // i >= 100: no field change — handler skips re-evaluation
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.update(accounts, true, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            Assert.isTrue(sr.isSuccess(), 'Every bulk update should succeed');
        }

        // Verify exactly 100 At-Risk tasks were created
        Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
        List<Task> tasks = [
            SELECT Id FROM Task
            WHERE WhatId IN :accountIds
            AND Subject LIKE :( AT_RISK_SUBJECT_PREFIX + '%' )
            WITH USER_MODE
        ];
        Assert.areEqual(100, tasks.size(),
            'Exactly 100 Tasks should be created for the 100 accounts that transitioned to At Risk');
    }
}
