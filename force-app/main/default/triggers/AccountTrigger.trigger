/**
 * @description Single entry-point trigger for the Account object.
 *              All logic is delegated to AccountTriggerHandler to keep
 *              this file thin and testable.
 *
 *              Supported contexts:
 *                - before insert
 *                - before update
 *                - after insert
 *                - after update
 */
trigger AccountTrigger on Account (
    before insert,
    before update,
    after insert,
    after update
) {
    AccountTriggerHandler handler = new AccountTriggerHandler();

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.afterInsert(Trigger.new, Trigger.newMap);
        } else if (Trigger.isUpdate) {
            handler.afterUpdate(Trigger.new, Trigger.newMap, Trigger.oldMap);
        }
    }
}
