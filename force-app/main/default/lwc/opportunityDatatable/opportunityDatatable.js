import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import STAGENAME_FIELD from '@salesforce/schema/Opportunity.StageName';
import getOpportunities from '@salesforce/apex/OpportunityDatatableController.getOpportunities';
import updateOpportunities from '@salesforce/apex/OpportunityDatatableController.updateOpportunities';

export default class OpportunityDatatable extends LightningElement {
    @track pickListOptions = [];
    @track allData = [];
    @track draftValues = [];
    @track tableErrors = {};
    @track lastSavedData = [];
    isLoading = false;
    _rawData;

    // Pagination
    pageNumber = 1;
    pageSize = 10;

    columns = [
        { label: 'Name', fieldName: 'Name', type: 'text', editable: true },
        {
            label: 'Stage',
            fieldName: 'StageName',
            type: 'picklistColumn',
            editable: true,
            typeAttributes: {
                placeholder: 'Choose Stage',
                options: { fieldName: 'pickListOptions' },
                value: { fieldName: 'StageName' },
                context: { fieldName: 'Id' },
                label: 'Stage',
                variant: 'label-hidden',
                name: 'StageName'
            }
        },
        {
            label: 'Close Date',
            fieldName: 'CloseDate',
            type: 'date-local',
            typeAttributes: {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit'
            },
            editable: true
        },
        {
            label: 'Amount',
            fieldName: 'Amount',
            type: 'number',
            typeAttributes: {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            },
            editable: true
        },
        {
            label: 'Last Modified',
            fieldName: 'LastModifiedDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            },
            sortable: true,
            initialWidth: 200
        }
    ];

    // ── Pagination getters ──
    get totalRecords() {
        return this.allData.length;
    }

    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize) || 1;
    }

    get displayedData() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.allData.slice(start, end);
    }

    get rowNumberOffset() {
        return (this.pageNumber - 1) * this.pageSize;
    }

    get isFirstPage() {
        return this.pageNumber <= 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }

    get pageInfo() {
        const start = (this.pageNumber - 1) * this.pageSize + 1;
        const end = Math.min(
            this.pageNumber * this.pageSize,
            this.totalRecords
        );
        return `${start}–${end} of ${this.totalRecords} records  |  Page ${this.pageNumber} of ${this.totalPages}`;
    }

    get pageSizeOptions() {
        return [
            { label: '10', value: '10' },
            { label: '15', value: '15' },
            { label: '25', value: '25' },
            { label: '50', value: '50' }
        ];
    }

    get pageSizeStr() {
        return String(this.pageSize);
    }

    // ── Pagination handlers ──
    handleFirst() {
        this.pageNumber = 1;
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber -= 1;
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber += 1;
        }
    }

    handleLast() {
        this.pageNumber = this.totalPages;
    }

    handlePageSizeChange(event) {
        this.pageSize = Number(event.detail.value);
        this.pageNumber = 1;
    }

    // ── Wire adapters ──
    @wire(getObjectInfo, { objectApiName: OPPORTUNITY_OBJECT })
    oppObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$oppObjectInfo.data.defaultRecordTypeId',
        fieldApiName: STAGENAME_FIELD
    })
    wiredStagePicklist({ data, error }) {
        if (data) {
            this.pickListOptions = data.values.map((item) => ({
                label: item.label,
                value: item.value
            }));
            if (this._rawData) {
                this.allData = this.decorateWithPicklistOptions(this._rawData);
            }
        } else if (error) {
            this.showToast(
                'Error loading stage options',
                this.normalizeError(error),
                'error'
            );
        }
    }

    wiredResponse;
    @wire(getOpportunities, { limitSize: 200 })
    wiredOpps(value) {
        this.wiredResponse = value;
        const { data, error } = value;
        if (data) {
            this._rawData = data;
            this.allData = this.decorateWithPicklistOptions(data);
            this.lastSavedData = JSON.parse(JSON.stringify(this.allData));
            this.pageNumber = 1;
            this.isLoading = false;
            this.tableErrors = {};
        } else if (error) {
            this.allData = [];
            this.isLoading = false;
            this.showToast(
                'Error loading data',
                this.normalizeError(error),
                'error'
            );
        }
    }

    decorateWithPicklistOptions(records) {
        return (records || []).map((r) => ({
            ...r,
            pickListOptions: this.pickListOptions
        }));
    }

    updateDraftValues(updateItem) {
        let draftValueChanged = false;
        const copyDraftValues = [...this.draftValues];
        copyDraftValues.forEach((item) => {
            if (item.Id === updateItem.Id) {
                for (const field in updateItem) {
                    if (
                        Object.prototype.hasOwnProperty.call(updateItem, field)
                    ) {
                        item[field] = updateItem[field];
                    }
                }
                draftValueChanged = true;
            }
        });
        if (draftValueChanged) {
            this.draftValues = [...copyDraftValues];
        } else {
            this.draftValues = [...copyDraftValues, updateItem];
        }
    }

    handleCellChange(event) {
        const draftVals = event.detail.draftValues;
        draftVals.forEach((ele) => {
            this.updateDraftValues(ele);
        });
    }

    handleCancel() {
        this.allData = JSON.parse(JSON.stringify(this.lastSavedData));
        this.draftValues = [];
        this.tableErrors = {};
    }

    async handleSave() {
        const drafts = this.draftValues;
        if (!drafts.length) {
            this.showToast('No changes', 'There are no edits to save.', 'info');
            return;
        }

        const updates = drafts.map((d) => {
            const rec = { Id: d.Id };
            if (d.Name !== undefined) {
                rec.Name = d.Name;
            }
            if (d.StageName !== undefined) {
                rec.StageName = d.StageName;
            }
            if (d.CloseDate !== undefined) {
                rec.CloseDate = d.CloseDate;
            }
            if (d.Amount !== undefined) {
                const n = Number(d.Amount);
                rec.Amount = isNaN(n) ? d.Amount : n;
            }
            return rec;
        });

        this.isLoading = true;
        this.tableErrors = {};
        try {
            const result = await updateOpportunities({ opps: updates });
            const hadErrors = result?.errors && result.errors.length > 0;
            const hadSuccess =
                result?.successIds && result.successIds.length > 0;

            if (hadSuccess) {
                this.showToast(
                    'Save successful',
                    `${result.successIds.length} record(s) updated.`,
                    'success'
                );
            }
            if (hadErrors) {
                const rowErrors = {};
                result.errors.forEach((err) => {
                    const rowId = err.id;
                    if (!rowErrors[rowId]) {
                        rowErrors[rowId] = {
                            title: 'Error',
                            messages: [],
                            fieldNames: []
                        };
                    }
                    rowErrors[rowId].messages.push(err.message);
                    if (err.fields && err.fields.length) {
                        err.fields.forEach((f) => {
                            const short = f.includes('.')
                                ? f.split('.').pop()
                                : f;
                            rowErrors[rowId].fieldNames.push(short);
                        });
                    }
                });
                this.tableErrors = { rows: rowErrors };
                const errorIds = new Set(result.errors.map((e) => e.id));
                this.draftValues = drafts.filter((d) => errorIds.has(d.Id));

                this.showToast(
                    'Some updates failed',
                    `${result.errors.length} error(s) occurred.`,
                    'error'
                );
            } else {
                this.draftValues = [];
                this.tableErrors = {};
            }

            if (hadSuccess) {
                const recordIds = result.successIds.map((id) => ({
                    recordId: id
                }));
                await notifyRecordUpdateAvailable(recordIds);
            }
            if (this.wiredResponse) {
                await refreshApex(this.wiredResponse);
            }
        } catch (e) {
            this.showToast('Save failed', this.normalizeError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    normalizeError(e) {
        if (!e) {
            return 'Unknown error';
        }
        if (Array.isArray(e.body)) {
            return e.body.map((x) => x.message).join(', ');
        }
        if (e.body && typeof e.body.message === 'string') {
            return e.body.message;
        }
        return typeof e.message === 'string' ? e.message : JSON.stringify(e);
    }
}
