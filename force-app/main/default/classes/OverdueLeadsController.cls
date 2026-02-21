/**
 * @description Controller for the overdueLeads Lightning Web Component.
 *              Provides a cacheable method to retrieve the running user's
 *              overdue, unconverted leads ordered by days since last contact.
 *
 * @see overdueLeads (LWC)
 */
public with sharing class OverdueLeadsController {

    @TestVisible
    private static Boolean forceException = false;

    /**
     * @description Retrieves all unconverted leads owned by the running user
     *              where Is_Overdue__c is true, ordered by
     *              Days_Since_Last_Contact__c descending (most overdue first).
     * @return List of Lead records with Id, Name, Company, and
     *         Days_Since_Last_Contact__c fields.
     * @throws AuraHandledException when the query fails for any reason.
     */
    @AuraEnabled(cacheable=true)
    public static List<Lead> getOverdueLeads() {
        try {
            if (forceException) {
                throw new QueryException('Forced exception for testing');
            }
            List<Lead> leads = [
                SELECT Id, Name, Company, Days_Since_Last_Contact__c
                FROM Lead
                WHERE Is_Overdue__c = true
                    AND OwnerId = :UserInfo.getUserId()
                    AND IsConverted = false
                WITH USER_MODE
                ORDER BY Days_Since_Last_Contact__c DESC
            ];

            // Enforce FLS by stripping inaccessible fields rather than throwing.
            // The class already uses 'with sharing' for record-level security.
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.READABLE, leads
            );
            return (List<Lead>) decision.getRecords();
        } catch (Exception ex) {
            AuraHandledException ahe = new AuraHandledException(ex.getMessage());
            ahe.setMessage(ex.getMessage());
            throw ahe;
        }
    }
}
