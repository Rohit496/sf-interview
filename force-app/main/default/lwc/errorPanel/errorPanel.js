/**
 * @description Reusable error panel component for inline or banner error display.
 *              Accepts any LWC error shape and renders human-readable messages
 *              using SLDS styling.
 */
import { LightningElement, api } from 'lwc';
import { reduceErrors } from 'c/errorUtils';

export default class ErrorPanel extends LightningElement {
    /** @type {*} Error object or array in any supported LWC error shape */
    @api errors;

    /** @type {'inline'|'banner'} Display mode -- 'inline' (default) or 'banner' */
    @api type = 'inline';

    /**
     * Derived list of error message strings from the errors property.
     * @returns {string[]}
     */
    get errorMessages() {
        if (this.errors == null) {
            return [];
        }
        return reduceErrors(this.errors);
    }

    /**
     * Whether there are any errors to display.
     * @returns {boolean}
     */
    get hasErrors() {
        return this.errorMessages.length > 0;
    }

    /**
     * Whether the component should render in inline mode.
     * @returns {boolean}
     */
    get isInline() {
        return this.type !== 'banner';
    }

    /**
     * Whether the component should render in banner mode.
     * @returns {boolean}
     */
    get isBanner() {
        return this.type === 'banner';
    }
}
