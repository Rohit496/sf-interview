/**
 * @description Service class for logging errors from Lightning Web Components.
 *              Provides a fire-and-forget logging mechanism that creates Error_Log__c
 *              records without throwing exceptions back to the caller.
 * @author ErrorHandlingFramework
 * @since 2026-03-01
 */
public with sharing class ErrorLogService {
    /**
     * @description Logs an error by creating an Error_Log__c record.
     *              This is a fire-and-forget method -- it silently consumes any
     *              insert failures so that logging never breaks the consuming component.
     * @param errorType     The classification of the error (e.g., Apex, Validation, Network, Unknown)
     * @param errorMessage  The human-readable error message
     * @param stackTrace    The stack trace or additional debugging context
     * @param componentName The name of the LWC or Apex component where the error originated
     */
    @AuraEnabled(cacheable=false)
    public static void logError(
        String errorType,
        String errorMessage,
        String stackTrace,
        String componentName
    ) {
        Error_Log__c errorLog = new Error_Log__c(
            Error_Type__c = errorType,
            Error_Message__c = errorMessage,
            Stack_Trace__c = stackTrace,
            Component_Name__c = componentName,
            User__c = UserInfo.getUserId(),
            Occurred_At__c = Datetime.now()
        );

        Database.insert(errorLog, false, AccessLevel.USER_MODE);
    }
}
