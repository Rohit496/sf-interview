/**
 * @description Trigger handler for the Lead object.
 *              Separates trigger logic from the trigger itself following the
 *              One-Trigger-Per-Object pattern.
 *
 *              Calculates Days_Since_Last_Contact__c and Is_Overdue__c based
 *              on the Last_Contacted_Date__c field. A lead is considered overdue
 *              when it has not been contacted for 7 or more days.
 *
 *              Recursion is prevented via the static {@link hasRun} flag;
 *              reset it in tests when simulating re-entrant scenarios.
 *
 * @see LeadTrigger
 */
public with sharing class LeadTriggerHandler {

    // ─── Constants ──────────────────────────────────────────────────────────────

    private static final Integer OVERDUE_THRESHOLD_DAYS = 7;

    // ─── Recursion Guard ────────────────────────────────────────────────────────

    /**
     * @description Prevents recursive trigger execution within a single transaction.
     *              Set to true after the first handler invocation; reset per test
     *              using `LeadTriggerHandler.hasRun = false;` when needed.
     */
    @TestVisible
    private static Boolean hasRun = false;

    // ─── Context Dispatchers ────────────────────────────────────────────────────

    /**
     * @description Executes before-insert logic. Calculates days since last contact
     *              and overdue status for every new Lead that has a populated
     *              Last_Contacted_Date__c.
     * @param newLeads List of Lead records being inserted (Trigger.new).
     */
    public void beforeInsert(List<Lead> newLeads) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        calculateContactMetrics(newLeads, null);
    }

    /**
     * @description Executes before-update logic. Recalculates days since last contact
     *              and overdue status only when Last_Contacted_Date__c has changed
     *              or been cleared.
     * @param newLeads List of updated Lead records (Trigger.new).
     * @param oldMap   Map of Lead Id to old record state (Trigger.oldMap).
     */
    public void beforeUpdate(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        calculateContactMetrics(newLeads, oldMap);
    }

    // ─── Private Helpers ────────────────────────────────────────────────────────

    /**
     * @description Calculates Days_Since_Last_Contact__c and Is_Overdue__c for the
     *              given leads. On insert (oldMap is null), processes every lead with
     *              a populated Last_Contacted_Date__c. On update, only processes leads
     *              where Last_Contacted_Date__c has changed.
     *
     *              If Last_Contacted_Date__c is cleared to null, both formula fields
     *              are reset (Days_Since_Last_Contact__c = null, Is_Overdue__c = false).
     *
     * @param newLeads List of Lead records being saved.
     * @param oldMap   Previous field values; null during insert.
     */
    private void calculateContactMetrics(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        Date today = Date.today();

        for (Lead lead : newLeads) {
            Boolean isInsert = (oldMap == null);

            if (!isInsert) {
                Lead oldLead = oldMap.get(lead.Id);
                Boolean lastContactChanged = (lead.Last_Contacted_Date__c != oldLead.Last_Contacted_Date__c);

                if (!lastContactChanged) {
                    continue;
                }
            }

            if (lead.Last_Contacted_Date__c == null) {
                lead.Days_Since_Last_Contact__c = null;
                lead.Is_Overdue__c = false;
                continue;
            }

            Integer daysSince = lead.Last_Contacted_Date__c.daysBetween(today);
            if (daysSince < 0) {
                daysSince = daysSince * -1;
            }
            lead.Days_Since_Last_Contact__c = daysSince;
            lead.Is_Overdue__c = (daysSince >= OVERDUE_THRESHOLD_DAYS);
        }
    }
}
