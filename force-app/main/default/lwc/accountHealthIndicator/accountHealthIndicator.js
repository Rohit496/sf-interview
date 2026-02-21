import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import HEALTH_RATING_FIELD from '@salesforce/schema/Account.Health_Rating__c';
import HEALTH_EVALUATED_DATE_FIELD from '@salesforce/schema/Account.Health_Evaluated_Date__c';

const FIELDS = [HEALTH_RATING_FIELD, HEALTH_EVALUATED_DATE_FIELD];

/**
 * @description Displays the Account Health Rating as a colored badge with
 *              the last evaluated date. Designed for the Account record page.
 */
export default class AccountHealthIndicator extends LightningElement {
    /** @type {string} Record Id injected by the Lightning record page. */
    @api recordId;

    /** @type {object} Wire result containing Account health fields. */
    _wireResult;

    /**
     * @description Wires to getRecord to reactively fetch health fields.
     * @param {object} result - Wire adapter result with data and error.
     */
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount(result) {
        this._wireResult = result;
    }

    /**
     * @description Returns true while the wire adapter has not yet returned data or error.
     * @returns {boolean}
     */
    get isLoading() {
        return !this._wireResult || (!this._wireResult.data && !this._wireResult.error);
    }

    /**
     * @description Returns true when the wire adapter returned an error.
     * @returns {boolean}
     */
    get hasError() {
        return this._wireResult && this._wireResult.error;
    }

    /**
     * @description Returns the Health_Rating__c picklist value.
     * @returns {string|null}
     */
    get healthRating() {
        if (!this._wireResult || !this._wireResult.data) {
            return null;
        }
        return getFieldValue(this._wireResult.data, HEALTH_RATING_FIELD);
    }

    /**
     * @description Returns a formatted date/time string for the last evaluated date,
     *              or 'Not yet evaluated' when the field is null.
     * @returns {string}
     */
    get formattedEvaluatedDate() {
        if (!this._wireResult || !this._wireResult.data) {
            return '';
        }
        const rawDate = getFieldValue(this._wireResult.data, HEALTH_EVALUATED_DATE_FIELD);
        if (!rawDate) {
            return 'Not yet evaluated';
        }
        const dateObj = new Date(rawDate);
        return new Intl.DateTimeFormat(undefined, {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(dateObj);
    }

    /**
     * @description Returns the SLDS badge CSS class based on the health rating value.
     *              Good = green (success), Average = warning, At Risk = red (error).
     * @returns {string}
     */
    get badgeClass() {
        const rating = this.healthRating;
        switch (rating) {
            case 'Good':
                return 'slds-badge slds-theme_success';
            case 'Average':
                return 'slds-badge slds-theme_warning';
            case 'At Risk':
                return 'slds-badge slds-theme_error';
            default:
                return 'slds-badge';
        }
    }
}
