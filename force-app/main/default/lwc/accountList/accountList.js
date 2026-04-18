import { LightningElement, wire, track } from 'lwc';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';

export default class AccountList extends LightningElement {
    // Tracked reactive state
    @track accounts = [];
    @track errorMessage = null;
    @track isLoading = true;

    // Wire Apex and manage loading/error states
    @wire(getAccounts)
    wiredAccounts({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.accounts = Array.isArray(data) ? data : [];
            this.errorMessage = null;
        } else if (error) {
            // Normalize error to string for display fallback
            this.errorMessage =
                (error && (error.body?.message || error.message)) ||
                'An unexpected error occurred.';
            this.accounts = [];
        }
    }

    // Computed getters for template conditions
    get hasAccounts() {
        return Array.isArray(this.accounts) && this.accounts.length > 0;
    }

    get hasError() {
        return !!this.errorMessage;
    }
}
