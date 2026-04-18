/**
 * @description Handler class for CaseTrigger. Implements duplicate Case prevention
 *              by detecting open Cases with the same Subject, Account, Contact, and Origin.
 * @author Claude
 * @date 2026-02-26
 */
public with sharing class CaseTriggerHandler {
    /** Error message added to Cases that are detected as duplicates. */
    @TestVisible
    private static final String DUPLICATE_ERROR_MESSAGE = 'A duplicate open Case already exists with the same Subject, Account/Contact, and Origin.';

    /** Separator used between fields in composite keys. */
    @TestVisible
    private static final String KEY_SEPARATOR = '|';

    /** Recursion guard to prevent re-entry on before-insert. */
    @TestVisible
    private static Boolean hasRunBeforeInsert = false;

    /**
     * @description Entry point called from CaseTrigger on before insert.
     * @param newCases The list of Cases being inserted (Trigger.new).
     */
    public void beforeInsert(List<Case> newCases) {
        if (hasRunBeforeInsert) {
            return;
        }
        hasRunBeforeInsert = true;
        preventDuplicateCases(newCases);
    }

    /**
     * @description Prevents insertion of Cases that duplicate an existing open Case
     *              or another Case in the same batch. A duplicate is identified by a
     *              composite key of Subject (case-insensitive) + AccountId + ContactId + Origin.
     * @param newCases The list of Cases being inserted.
     */
    @TestVisible
    private void preventDuplicateCases(List<Case> newCases) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }

        // Build composite keys for all incoming Cases
        Set<String> incomingKeys = new Set<String>();
        Map<String, List<Case>> keyToCasesMap = new Map<String, List<Case>>();

        for (Case newCase : newCases) {
            String compositeKey = buildCompositeKey(newCase);
            if (!keyToCasesMap.containsKey(compositeKey)) {
                keyToCasesMap.put(compositeKey, new List<Case>());
            }
            keyToCasesMap.get(compositeKey).add(newCase);
            incomingKeys.add(compositeKey);
        }

        // Detect within-batch duplicates: if multiple Cases share the same key,
        // mark all but the first as duplicates
        for (String key : keyToCasesMap.keySet()) {
            List<Case> casesWithKey = keyToCasesMap.get(key);
            if (casesWithKey.size() > 1) {
                for (Integer i = 1; i < casesWithKey.size(); i++) {
                    casesWithKey[i].addError(DUPLICATE_ERROR_MESSAGE);
                }
            }
        }

        // Collect bind variable sets from the incoming batch to narrow the query
        Set<String> subjects = new Set<String>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        Set<String> origins = new Set<String>();
        for (Case c : newCases) {
            if (String.isNotBlank(c.Subject)) {
                subjects.add(c.Subject.toLowerCase());
            }
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
            if (c.ContactId != null) {
                contactIds.add(c.ContactId);
            }
            if (String.isNotBlank(c.Origin)) {
                origins.add(c.Origin);
            }
        }

        // Query existing open Cases from the database (narrowed to relevant records)
        Set<String> existingKeys = new Set<String>();
        List<Case> existingOpenCases = [
            SELECT Id, Subject, AccountId, ContactId, Origin
            FROM Case
            WHERE
                IsClosed = FALSE
                AND (Subject IN :subjects
                OR AccountId IN :accountIds
                OR ContactId IN :contactIds
                OR Origin IN :origins)
            WITH USER_MODE
        ];

        for (Case existingCase : existingOpenCases) {
            String existingKey = buildCompositeKey(existingCase);
            if (incomingKeys.contains(existingKey)) {
                existingKeys.add(existingKey);
            }
        }

        // Mark incoming Cases that match an existing open Case as duplicates
        for (Case newCase : newCases) {
            String compositeKey = buildCompositeKey(newCase);
            if (existingKeys.contains(compositeKey)) {
                newCase.addError(DUPLICATE_ERROR_MESSAGE);
            }
        }
    }

    /**
     * @description Builds a composite key string from a Case's Subject, AccountId,
     *              ContactId, and Origin fields.
     * @param c The Case record.
     * @return A pipe-delimited composite key with lowercase Subject.
     */
    private String buildCompositeKey(Case c) {
        String subject = c.Subject != null ? c.Subject.toLowerCase() : '';
        String accountId = c.AccountId != null
            ? String.valueOf(c.AccountId)
            : '';
        String contactId = c.ContactId != null
            ? String.valueOf(c.ContactId)
            : '';
        String origin = c.Origin != null ? c.Origin : '';
        return subject +
            KEY_SEPARATOR +
            accountId +
            KEY_SEPARATOR +
            contactId +
            KEY_SEPARATOR +
            origin;
    }
}
