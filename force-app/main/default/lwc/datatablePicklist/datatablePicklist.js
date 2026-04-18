import { LightningElement, api } from 'lwc';

export default class DatatablePicklist extends LightningElement {
    static _instanceCounter = 0;

    @api label;
    @api placeholder;
    @api options;
    @api value;
    @api context;
    @api variant;
    @api name;

    showPicklist = false;
    picklistValueChanged = false;

    connectedCallback() {
        this.guid = `datatable-picklist-${DatatablePicklist._instanceCounter++}`;
        this.dispatchEvent(
            new CustomEvent('itemregister', {
                bubbles: true,
                composed: true,
                detail: {
                    callbacks: {
                        reset: this.reset
                    },
                    template: this.template,
                    guid: this.guid,
                    name: 'c-datatable-picklist'
                }
            })
        );
    }

    dispatchCustomEvent(eventName, context, value, label, name) {
        this.dispatchEvent(
            new CustomEvent(eventName, {
                composed: true,
                bubbles: true,
                cancelable: true,
                detail: {
                    data: { context, value, label, name }
                }
            })
        );
    }

    handleClick(event) {
        event.preventDefault();
        event.stopPropagation();
        this.showPicklist = true;
        this.dispatchCustomEvent(
            'edit',
            this.context,
            this.value,
            this.label,
            this.name
        );
    }

    handleChange(event) {
        event.preventDefault();
        this.picklistValueChanged = true;
        // eslint-disable-next-line @lwc/lwc/no-api-reassignments
        this.value = event.detail.value;
        this.showPicklist = false;
        this.dispatchCustomEvent(
            'valuechange',
            this.context,
            this.value,
            this.label,
            this.name
        );
    }

    handleBlur(event) {
        event.preventDefault();
        this.showPicklist = false;
        if (!this.picklistValueChanged) {
            this.dispatchCustomEvent(
                'customtblur',
                this.context,
                this.value,
                this.label,
                this.name
            );
        }
        this.picklistValueChanged = false;
    }

    reset = (context) => {
        if (this.context !== context) {
            this.showPicklist = false;
        }
    };
}
