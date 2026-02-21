import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getOverdueLeads from '@salesforce/apex/OverdueLeadsController.getOverdueLeads';

/**
 * @description Displays a table of the running user's overdue leads
 *              (leads not contacted in 7+ days). Each lead name links
 *              to the lead record page.
 */
export default class OverdueLeads extends NavigationMixin(LightningElement) {
    leads = [];
    errorMessage;
    isLoading = true;

    /**
     * @description Wires the getOverdueLeads Apex method. On success,
     *              maps each lead record to include a navigation URL.
     *              On error, captures the error message for display.
     */
    @wire(getOverdueLeads)
    wiredLeads({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.leads = data.map((lead) => ({
                ...lead,
                recordUrl: `/lightning/r/Lead/${lead.Id}/view`
            }));
            this.errorMessage = undefined;
        } else if (error) {
            this.leads = [];
            this.errorMessage =
                error?.body?.message || 'An unexpected error occurred while loading overdue leads.';
        }
    }

    /**
     * @description Computed property that returns true when leads exist.
     * @returns {boolean}
     */
    get hasLeads() {
        return this.leads && this.leads.length > 0;
    }

    /**
     * @description Computed property that returns true when no leads exist
     *              and no error or loading state is active.
     * @returns {boolean}
     */
    get hasNoLeads() {
        return !this.isLoading && !this.errorMessage && (!this.leads || this.leads.length === 0);
    }

    /**
     * @description Computed property that returns true when an error occurred.
     * @returns {boolean}
     */
    get hasError() {
        return !!this.errorMessage;
    }

    /**
     * @description Navigates to the selected lead record page using
     *              NavigationMixin.
     * @param {Event} event - The click event from the lead name link.
     */
    handleNavigate(event) {
        event.preventDefault();
        const leadId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: leadId,
                objectApiName: 'Lead',
                actionName: 'view'
            }
        });
    }
}
