import { createElement } from 'lwc';
import MyAccounts from 'c/myAccounts';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';
import { createApexTestWireAdapter } from '@salesforce/wire-service-jest-util';

/*
 * The @lwc/jest-transformer wraps @salesforce/apex imports in a try/catch that
 * reads `.default` from the required module.  The factory must therefore export
 * the adapter as `{ default: adapter }` so the component and the test both
 * receive the same adapter instance.
 */
jest.mock(
    '@salesforce/apex/AccountController.getAccounts',
    () => {
        const { createApexTestWireAdapter: create } = require('@salesforce/wire-service-jest-util');
        const adapter = create(jest.fn());
        return { default: adapter };
    },
    { virtual: true }
);

const MOCK_DATA = {
    totalCount: 247,
    accounts: [
        {
            Id: '001000000000001AAA',
            Name: 'Acme Corporation',
            Industry: 'Technology',
            Phone: '(415) 555-1234',
            AnnualRevenue: 5200000,
            Rating: 'Hot'
        },
        {
            Id: '001000000000002AAA',
            Name: 'Global Industries',
            Industry: 'Manufacturing',
            Phone: '(312) 555-9876',
            AnnualRevenue: 1850000,
            Rating: 'Warm'
        }
    ]
};

describe('c-my-accounts', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders the correct number of account cards', () => {
        const element = createElement('c-my-accounts', { is: MyAccounts });
        document.body.appendChild(element);

        getAccounts.emit(MOCK_DATA);

        return Promise.resolve().then(() => {
            const cards = element.shadowRoot.querySelectorAll('.account-card');
            expect(cards.length).toBe(2);
        });
    });

    it('displays footer with showing count and total', () => {
        const element = createElement('c-my-accounts', { is: MyAccounts });
        document.body.appendChild(element);

        getAccounts.emit(MOCK_DATA);

        return Promise.resolve().then(() => {
            const footer = element.shadowRoot.querySelector('.footer-text');
            expect(footer.textContent).toBe('Showing 2 of 247 Accounts');
        });
    });

    it('shows the Hot rating with correct CSS class', () => {
        const element = createElement('c-my-accounts', { is: MyAccounts });
        document.body.appendChild(element);

        getAccounts.emit(MOCK_DATA);

        return Promise.resolve().then(() => {
            const hotSpan = element.shadowRoot.querySelector('.rating-hot');
            expect(hotSpan).not.toBeNull();
            expect(hotSpan.textContent).toBe('Hot');
        });
    });

    it('shows the Warm rating with correct CSS class', () => {
        const element = createElement('c-my-accounts', { is: MyAccounts });
        document.body.appendChild(element);

        getAccounts.emit(MOCK_DATA);

        return Promise.resolve().then(() => {
            const warmSpan = element.shadowRoot.querySelector('.rating-warm');
            expect(warmSpan).not.toBeNull();
            expect(warmSpan.textContent).toBe('Warm');
        });
    });

    it('renders error message when wire returns an error', () => {
        const element = createElement('c-my-accounts', { is: MyAccounts });
        document.body.appendChild(element);

        getAccounts.error({ body: { message: 'Test error' } });

        return Promise.resolve().then(() => {
            const errEl = element.shadowRoot.querySelector('.slds-text-color_error');
            expect(errEl).not.toBeNull();
        });
    });

    it('uses the title @api property in the header', () => {
        const element = createElement('c-my-accounts', { is: MyAccounts });
        element.title = 'Customer Accounts';
        document.body.appendChild(element);

        getAccounts.emit(MOCK_DATA);

        return Promise.resolve().then(() => {
            const heading = element.shadowRoot.querySelector('.accounts-title');
            expect(heading.textContent).toBe('Customer Accounts');
        });
    });
});
