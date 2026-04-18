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

        /** @description Indicates whether more Account records exist beyond the returned page. 🟠 */
        @AuraEnabled
        public Boolean hasMore;
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
    public static AccountResult getAccountss(Integer displayCount) {
        Integer lim = clampDisplayCount(displayCount);

        AccountResult result = new AccountResult();
        // Query one extra row to detect if more records exist without issuing an unbounded COUNT(). 🟠
        List<Account> rows = [
            SELECT Id, Name, Industry, Phone, AnnualRevenue, Rating
            FROM Account
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT :(lim + 1)
        ];

        result.hasMore = rows.size() > lim; // 🟠 set true if extra row was fetched (more data available)
        // In Apex, List.subList(begin, endExclusive) exists, but not on SObject lists in some API levels.
        // Use manual copy to ensure compatibility.
        if (result.hasMore) {
            List<Account> page = new List<Account>();
            for (Integer i = 0; i < lim; i++) {
                page.add(rows[i]);
            }
            result.accounts = page;
        } else {
            result.accounts = rows;
        }

        return result;
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────────

    private static Integer clampDisplayCount(Integer value) {
        if (value == null || value < 2) {
            return 2;
        }
        return value > 5 ? 5 : value;
    }

    /**
     * @description Returns a list of up to 10 Account records.
     * @return List of Account records with Id, Name, and Industry fields.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts() {
        return [SELECT Id, Name, Industry FROM Account WITH USER_MODE LIMIT 10];
    }
}
