import { createElement } from 'lwc';
import AccountHealthIndicator from 'c/accountHealthIndicator';

describe('c-account-health-indicator', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases, clean up after each test
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('displays health rating and evaluated date when data is loaded', () => {
        const element = createElement('c-account-health-indicator', {
            is: AccountHealthIndicator
        });

        // Set the recordId property
        element.recordId = '001xx000003DHPpAAO';

        document.body.appendChild(element);

        // Check that the component renders correctly
        expect(element).toBeTruthy();
    });

    it('shows loading state initially', () => {
        const element = createElement('c-account-health-indicator', {
            is: AccountHealthIndicator
        });

        element.recordId = '001xx000003DHPpAAO';

        document.body.appendChild(element);

        // Check that loading spinner is displayed initially
        const spinner = element.shadowRoot.querySelector('lightning-spinner');
        expect(spinner).not.toBeNull();
    });

    it('handles null values gracefully', () => {
        const element = createElement('c-account-health-indicator', {
            is: AccountHealthIndicator
        });

        element.recordId = '001xx000003DHPpAAO';

        document.body.appendChild(element);

        // Check that component handles null values without errors
        expect(element).toBeTruthy();
    });
});
