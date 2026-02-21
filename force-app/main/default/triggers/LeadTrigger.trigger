/**
 * @description Single entry-point trigger for the Lead object.
 *              All logic is delegated to LeadTriggerHandler to keep
 *              this file thin and testable.
 *
 *              Supported contexts:
 *                - before insert
 *                - before update
 */
trigger LeadTrigger on Lead (
    before insert,
    before update
) {
    LeadTriggerHandler handler = new LeadTriggerHandler();

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
