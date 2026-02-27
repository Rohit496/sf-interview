import { LightningElement, api, wire } from 'lwc';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';

/**
 * @description Displays a configurable number of Account records (2–50) in a
 *              lightning-datatable with a total-count footer.
 */
export default class MyAccounts extends LightningElement {
    /** @type {string} Card header title */
    @api title = 'My Accounts';

    /** @type {number} Accounts to display (clamped server-side to 2–50) */
    @api displayCount = 50;

    accounts = [];
    totalCount = 0;
    isLoading = true;
    errorMessage = '';

    /** Column definitions for the lightning-datatable */
    columns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Industry', fieldName: 'Industry', type: 'text' },
        { label: 'Phone', fieldName: 'Phone', type: 'phone' },
        { label: 'Annual Revenue', fieldName: 'AnnualRevenue', type: 'currency' },
        { label: 'Rating', fieldName: 'Rating', type: 'text' }
    ];

    // ─── Wire ────────────────────────────────────────────────────────────────────

    @wire(getAccounts, { displayCount: '$displayCount' })
    wiredAccounts({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.totalCount = data.totalCount;
            this.accounts = data.accounts;
        } else if (error) {
            this.errorMessage =
                error.body?.message ?? 'An error occurred while loading accounts.';
        }
    }

    // ─── Computed Properties ─────────────────────────────────────────────────────

    get hasError() {
        return !!this.errorMessage;
    }

    /** @returns {string} e.g. "Showing 5 of 247 Accounts" */
    get footerText() {
        return `Showing ${this.accounts.length} of ${this.totalCount} Accounts`;
    }
}
