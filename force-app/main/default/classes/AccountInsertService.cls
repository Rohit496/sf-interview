public with sharing class AccountInsertService {
    public static Account insertAccount(String accountName) {
        if (String.isBlank(accountName)) {
            throw new IllegalArgumentException('Account Name cannot be blank.');
        }

        Account acc = new Account(Name = accountName);
        Database.SaveResult result = Database.insert(acc, false);

        if (!result.isSuccess()) {
            String errors = result.getErrors()[0].getMessage();
            throw new AccountInsertException(
                'Failed to insert Account: ' + errors
            );
        }

        return acc;
    }

    public class AccountInsertException extends Exception {
    }
}
