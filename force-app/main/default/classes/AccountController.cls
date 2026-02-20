/**
 * @description Controller for the My Accounts LWC component.
 *              Returns a clamped page of Account records alongside the total count. Deploy using MCP and GitHub PR.
 */
public with sharing class AccountController {
    // ─── Inner Types ─────────────────────────────────────────────────────────────

    /**
     * @description Wire-serializable wrapper returned to the LWC.
     */
    public class AccountResult {
        /** @description Subset of Account records to display. */
        @AuraEnabled
        public List<Account> accounts;

        /** @description Total number of Account records visible to the running user. */
        @AuraEnabled
        public Integer totalCount;
    }

    // ─── Public API ──────────────────────────────────────────────────────────────

    /**
     * @description Returns a limited set of Account records and the overall total count.
     *              The display count is clamped to the range [2, 5].
     * @param displayCount Requested number of accounts to return.
     * @return AccountResult containing the clamped accounts list and total count.
     * @example
     *   AccountController.AccountResult result = AccountController.getAccounts(3);
     */
    @AuraEnabled(cacheable=true)
    public static AccountResult getAccounts(Integer displayCount) {
        Integer lim = clampDisplayCount(displayCount);

        AccountResult result = new AccountResult();
        result.accounts = [
            SELECT Id, Name, Industry, Phone, AnnualRevenue, Rating
            FROM Account
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT :lim
        ];
        result.totalCount = [SELECT COUNT() FROM Account WITH USER_MODE];

        return result;
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────────

    private static Integer clampDisplayCount(Integer value) {
        if (value == null || value < 2) {
            return 2;
        }
        return value > 5 ? 5 : value;
    }
}
