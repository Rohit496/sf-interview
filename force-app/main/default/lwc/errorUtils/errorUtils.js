/**
 * @description LWC service module for error handling utilities.
 *              Provides functions to reduce, normalize, classify, and log errors
 *              from any LWC error shape (Apex, UI API, DML, network, plain JS).
 *              This module has NO HTML template -- it is imported as a utility.
 */
import logErrorApex from '@salesforce/apex/ErrorLogService.logError';

/**
 * Reduces any LWC error shape into an array of human-readable message strings.
 * Handles AuraHandledException, UI API errors, DML errors, FetchResponse,
 * plain JS Error objects, plain strings, and null/undefined.
 * @param {*} error - The error object in any supported shape
 * @returns {string[]} Array of error message strings
 */
export function reduceErrors(error) {
    if (error == null) {
        return ['Unknown error'];
    }

    // Plain string
    if (typeof error === 'string') {
        return [error];
    }

    // Array of errors -- recursively reduce each
    if (Array.isArray(error)) {
        const messages = error.flatMap((item) => reduceErrors(item));
        return messages.length > 0 ? messages : ['Unknown error'];
    }

    // Object-shaped errors
    if (typeof error === 'object') {
        // DML errors: { body: { output: { errors: [{ message }] } } }
        if (error.body?.output?.errors) {
            const dmlMessages = error.body.output.errors
                .map((e) => e.message)
                .filter(Boolean);
            if (dmlMessages.length > 0) {
                return dmlMessages;
            }
        }

        // UI API array errors: { body: [{ message }] }
        if (Array.isArray(error.body)) {
            const bodyMessages = error.body
                .map((e) => e.message)
                .filter(Boolean);
            if (bodyMessages.length > 0) {
                return bodyMessages;
            }
        }

        // AuraHandledException: { body: { message } }
        if (error.body?.message) {
            return [error.body.message];
        }

        // Network / FetchResponse: { status, statusText }
        if (error.status != null && error.statusText != null) {
            return [`${error.status} ${error.statusText}`];
        }

        // Plain JS Error: { message }
        if (error.message) {
            return [error.message];
        }
    }

    return ['Unknown error'];
}

/**
 * Normalizes an error into a single semicolon-delimited string.
 * @param {*} error - The error object in any supported shape
 * @returns {string} All error messages joined with '; '
 */
export function normalizeError(error) {
    return reduceErrors(error).join('; ');
}

/**
 * Classifies an error by its shape into a category string.
 * @param {*} error - The error object
 * @returns {'Apex'|'Validation'|'Network'|'Unknown'} The error classification
 */
export function classifyError(error) {
    if (error == null || typeof error !== 'object') {
        return 'Unknown';
    }

    if (error.body?.output?.errors) {
        return 'Validation';
    }

    if (error.body?.message) {
        return 'Apex';
    }

    if (error.status != null) {
        return 'Network';
    }

    return 'Unknown';
}

/**
 * Logs an error to the server by calling ErrorLogService.logError.
 * This is a fire-and-forget async function -- failures are silently caught
 * so that logging never breaks the consuming component.
 * @param {Object} params
 * @param {*} params.error - The error object
 * @param {string} params.componentName - The name of the component where the error occurred
 */
export async function logErrorToServer({ error, componentName }) {
    try {
        const errorType = classifyError(error);
        const errorMessage = normalizeError(error);
        const stackTrace = error?.stack || error?.body?.stackTrace || '';

        await logErrorApex({
            errorType,
            errorMessage,
            stackTrace,
            componentName
        });
    } catch {
        // Silently consume -- logging must never break the consuming component
    }
}
