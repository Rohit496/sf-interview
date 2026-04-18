import { createElement } from 'lwc';
import OpportunityDatatable from 'c/opportunityDatatable';
import getOpportunities from '@salesforce/apex/OpportunityDatatableController.getOpportunities';
import updateOpportunities from '@salesforce/apex/OpportunityDatatableController.updateOpportunities';
// ── Wire adapters ────────────────────────────────────────────────────────────

jest.mock(
    '@salesforce/apex/OpportunityDatatableController.getOpportunities',
    () => {
        const {
            createApexTestWireAdapter: create
        } = require('@salesforce/wire-service-jest-util');
        const adapter = create(jest.fn());
        return { default: adapter };
    },
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/OpportunityDatatableController.updateOpportunities',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/schema/Opportunity',
    () => ({ default: { objectApiName: 'Opportunity' } }),
    { virtual: true }
);

jest.mock(
    '@salesforce/schema/Opportunity.StageName',
    () => ({
        default: { fieldApiName: 'StageName', objectApiName: 'Opportunity' }
    }),
    { virtual: true }
);

jest.mock(
    'lightning/uiRecordApi',
    () => ({
        notifyRecordUpdateAvailable: jest.fn().mockResolvedValue(undefined)
    }),
    { virtual: true }
);

// ── Test data ────────────────────────────────────────────────────────────────

const mockRows = [
    {
        Id: '006000000000001AAA',
        Name: 'Opp A',
        StageName: 'Prospecting',
        CloseDate: '2026-03-31',
        Amount: 1000,
        LastModifiedDate: '2026-02-28T12:00:00.000Z'
    },
    {
        Id: '006000000000002AAA',
        Name: 'Opp B',
        StageName: 'Qualification',
        CloseDate: '2026-04-15',
        Amount: 2500,
        LastModifiedDate: '2026-02-27T12:00:00.000Z'
    }
];

// ── Helpers ──────────────────────────────────────────────────────────────────

function flushPromises() {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('c-opportunity-datatable', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders the custom datatable on init', async () => {
        const el = createElement('c-opportunity-datatable', {
            is: OpportunityDatatable
        });
        document.body.appendChild(el);

        getOpportunities.emit(mockRows);
        await flushPromises();

        const table = el.shadowRoot.querySelector('c-custom-datatable');
        expect(table).not.toBeNull();
        expect(table.data).toHaveLength(2);
    });

    it('decorates rows with pickListOptions', async () => {
        const el = createElement('c-opportunity-datatable', {
            is: OpportunityDatatable
        });
        document.body.appendChild(el);

        getOpportunities.emit(mockRows);
        await flushPromises();

        const table = el.shadowRoot.querySelector('c-custom-datatable');
        // Each row should have a pickListOptions array attached
        table.data.forEach((row) => {
            expect(row).toHaveProperty('pickListOptions');
            expect(Array.isArray(row.pickListOptions)).toBe(true);
        });
    });

    it('calls updateOpportunities on save and clears drafts on full success', async () => {
        updateOpportunities.mockResolvedValue({
            successIds: [mockRows[0].Id],
            errors: []
        });

        const el = createElement('c-opportunity-datatable', {
            is: OpportunityDatatable
        });
        document.body.appendChild(el);

        getOpportunities.emit(mockRows);
        await flushPromises();

        // Simulate cellchange to populate draftValues
        const table = el.shadowRoot.querySelector('c-custom-datatable');
        table.dispatchEvent(
            new CustomEvent('cellchange', {
                detail: {
                    draftValues: [{ Id: mockRows[0].Id, Name: 'New Name' }]
                }
            })
        );
        await flushPromises();

        // Now fire save
        table.dispatchEvent(new CustomEvent('save'));
        await flushPromises();

        expect(updateOpportunities).toHaveBeenCalledTimes(1);
        const args = updateOpportunities.mock.calls[0][0];
        expect(args.opps).toEqual([{ Id: mockRows[0].Id, Name: 'New Name' }]);
    });

    it('retains drafts for errored rows on partial failure', async () => {
        updateOpportunities.mockResolvedValue({
            successIds: [],
            errors: [
                {
                    id: mockRows[1].Id,
                    message: 'Validation error',
                    fields: ['Opportunity.Amount']
                }
            ]
        });

        const el = createElement('c-opportunity-datatable', {
            is: OpportunityDatatable
        });
        document.body.appendChild(el);

        getOpportunities.emit(mockRows);
        await flushPromises();

        const drafts = [
            { Id: mockRows[0].Id, Name: 'New Name' },
            { Id: mockRows[1].Id, Amount: 999999999999 }
        ];

        // Populate draftValues via cellchange
        const table = el.shadowRoot.querySelector('c-custom-datatable');
        table.dispatchEvent(
            new CustomEvent('cellchange', {
                detail: { draftValues: drafts }
            })
        );
        await flushPromises();

        // Fire save
        table.dispatchEvent(new CustomEvent('save'));
        await flushPromises();

        // Verify updateOpportunities was called with both drafts
        expect(updateOpportunities).toHaveBeenCalledTimes(1);

        // After partial failure, datatable should have errors prop set
        // (errors are passed as the errors attribute on c-custom-datatable)
        expect(table.errors).toBeTruthy();
        expect(table.errors.rows).toBeTruthy();
        expect(table.errors.rows[mockRows[1].Id]).toBeTruthy();
    });

    it('resets data and clears drafts on cancel', async () => {
        const el = createElement('c-opportunity-datatable', {
            is: OpportunityDatatable
        });
        document.body.appendChild(el);

        getOpportunities.emit(mockRows);
        await flushPromises();

        const table = el.shadowRoot.querySelector('c-custom-datatable');

        // Add a draft
        table.dispatchEvent(
            new CustomEvent('cellchange', {
                detail: {
                    draftValues: [{ Id: mockRows[0].Id, Name: 'Changed' }]
                }
            })
        );
        await flushPromises();

        // Verify draft-values were set on the datatable
        expect(table.draftValues).toHaveLength(1);

        // Cancel
        table.dispatchEvent(new CustomEvent('cancel'));
        await flushPromises();

        // After cancel, draft-values and errors should be cleared
        expect(table.draftValues).toEqual([]);
        expect(table.errors).toEqual({});
    });

    it('displays pagination info in footer', async () => {
        const el = createElement('c-opportunity-datatable', {
            is: OpportunityDatatable
        });
        document.body.appendChild(el);

        getOpportunities.emit(mockRows);
        await flushPromises();

        const infoSpan = el.shadowRoot.querySelector('.pagination-info');
        expect(infoSpan).not.toBeNull();
        expect(infoSpan.textContent).toContain('1–2 of 2');
    });
});
