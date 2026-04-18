/**
 * @description Single entry-point trigger for the Case object.
 *              All logic is delegated to CaseTriggerHandler to keep
 *              this file thin and testable.
 *
 *              Supported contexts:
 *                - before insert
 */
trigger CaseTrigger on Case(before insert) {
    CaseTriggerHandler handler = new CaseTriggerHandler();
    if (Trigger.isBefore && Trigger.isInsert) {
        handler.beforeInsert(Trigger.new);
    }
}
