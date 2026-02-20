import { LightningElement, api, wire } from 'lwc';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';

/** Deterministic palette — index = charCode % length */
const AVATAR_COLORS = [
    '#1589ee',
    '#9c27b0',
    '#e91e63',
    '#ff5722',
    '#4caf50',
    '#00bcd4',
    '#ff9800',
    '#795548'
];

/** Maps Salesforce Rating picklist values to CSS class names */
const RATING_CLASS_MAP = {
    Hot: 'rating-hot',
    Warm: 'rating-warm',
    Cold: 'rating-cold'
};

/**
 * @description Displays a configurable number of Account records (2–5) with
 *              avatar initials, revenue, and rating; shows a total-count footer.
 */
export default class MyAccounts extends LightningElement {
    /** @type {string} Card header title */
    @api title = 'My Accounts';

    /** @type {number} Accounts to display (clamped server-side to 2–5) */
    @api displayCount = 5;

    accounts = [];
    totalCount = 0;
    isLoading = true;
    errorMessage = '';

    // ─── Wire ────────────────────────────────────────────────────────────────────

    @wire(getAccounts, { displayCount: '$displayCount' })
    wiredAccounts({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.totalCount = data.totalCount;
            this.accounts = data.accounts.map((acc) => this._enrichAccount(acc));
        } else if (error) {
            this.errorMessage =
                error.body?.message ?? 'An error occurred while loading accounts.';
        }
    }

    // ─── Computed Properties ─────────────────────────────────────────────────────

    get hasAccounts() {
        return this.accounts && this.accounts.length > 0;
    }

    get hasError() {
        return !!this.errorMessage;
    }

    /** @returns {string} e.g. "Showing 5 of 247 Accounts" */
    get footerText() {
        return `Showing ${this.accounts.length} of ${this.totalCount} Accounts`;
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────────

    /**
     * @description Adds UI-only derived fields to a raw Account record.
     * @param {object} acc Raw Account record from Apex wire.
     * @returns {object} Enriched record with avatar, revenue, and rating metadata.
     */
    _enrichAccount(acc) {
        const firstLetter = acc.Name ? acc.Name.charAt(0).toUpperCase() : '?';
        const colorIndex = firstLetter.charCodeAt(0) % AVATAR_COLORS.length;

        return {
            ...acc,
            avatarLetter: firstLetter,
            avatarStyle: `background-color: ${AVATAR_COLORS[colorIndex]}`,
            formattedRevenue: this._formatCurrency(acc.AnnualRevenue),
            ratingClass: RATING_CLASS_MAP[acc.Rating] ?? 'rating-default',
            isHot: acc.Rating === 'Hot'
        };
    }

    /**
     * @description Formats a numeric value as USD currency string.
     * @param {number|null} value Numeric amount.
     * @returns {string} Formatted string, e.g. "$5,200,000", or "--" if null.
     */
    _formatCurrency(value) {
        if (value == null) return '--';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(value);
    }
}
