/**
 * @description Interactive test harness for the Error Handling Framework.
 *              Simulates various error shapes and demonstrates classifyError,
 *              normalizeError, the error-panel component, and ErrorLogService logging.
 */
import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceErrors, normalizeError, classifyError } from 'c/errorUtils';
import logError from '@salesforce/apex/ErrorLogService.logError';

export default class ErrorFrameworkDemo extends LightningElement {
    /** @type {*} The active error object, null when no error is triggered */
    currentError = null;

    /** @type {string} Classification string from classifyError */
    classifiedType = '';

    /** @type {string} Normalized message string from normalizeError */
    normalizedMessage = '';

    /** @type {''|'success'|'error'} Status of the last logError call */
    logStatus = '';

    /**
     * @description Returns true when an error is currently active.
     * @returns {boolean}
     */
    get hasError() {
        return this.currentError !== null;
    }

    /**
     * @description Returns the SLDS text color class based on log status.
     * @returns {string}
     */
    get logStatusClass() {
        if (this.logStatus === 'success') {
            return 'slds-text-color_success';
        }
        if (this.logStatus === 'error') {
            return 'slds-text-color_error';
        }
        return '';
    }

    /**
     * @description Returns a human-readable status message based on log status.
     * @returns {string}
     */
    get logStatusText() {
        if (this.logStatus === 'success') {
            return 'Logged to Error_Log__c';
        }
        if (this.logStatus === 'error') {
            return 'Logging failed';
        }
        return '';
    }

    /**
     * @description Simulates an Apex error shape and logs it.
     */
    handleApexError() {
        const error = {
            body: {
                message: 'Apex: Record is read-only and cannot be updated.'
            }
        };
        this._processError(error);
    }

    /**
     * @description Simulates a network error shape and logs it.
     */
    handleNetworkError() {
        const error = {
            status: 503,
            statusText: 'Service Unavailable'
        };
        this._processError(error);
    }

    /**
     * @description Simulates a validation error shape with multiple messages and logs it.
     */
    handleValidationError() {
        const error = {
            body: {
                output: {
                    errors: [
                        {
                            message:
                                'Validation rule failed: Amount must be positive.'
                        },
                        { message: 'CloseDate cannot be in the past.' }
                    ]
                }
            }
        };
        this._processError(error);
    }

    /**
     * @description Simulates an unknown JS Error and logs it.
     */
    handleUnknownError() {
        const error = new Error('Unexpected null reference at line 42');
        this._processError(error);
    }

    /**
     * @description Resets all state to initial values.
     */
    handleClear() {
        this.currentError = null;
        this.classifiedType = '';
        this.normalizedMessage = '';
        this.logStatus = '';
    }

    /**
     * @description Processes a simulated error: classifies, normalizes, and logs it.
     * @param {*} error - The simulated error object
     */
    async _processError(error) {
        this.currentError = error;
        this.classifiedType = classifyError(error);
        this.normalizedMessage = normalizeError(error);

        try {
            await logError({
                errorType: this.classifiedType,
                errorMessage: this.normalizedMessage,
                stackTrace: error.stack || '',
                componentName: 'errorFrameworkDemo'
            });
            this.logStatus = 'success';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Logged!',
                    message: 'Error saved to Error_Log__c',
                    variant: 'success'
                })
            );
        } catch (logErr) {
            this.logStatus = 'error';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Log Failed',
                    message: reduceErrors(logErr).join('; '),
                    variant: 'error'
                })
            );
        }
    }
}
