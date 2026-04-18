import { LightningElement, api } from 'lwc';

export default class IFrameComponent extends LightningElement {
    @api iframeUrl;
    @api width = '100%';
    @api height = '600px';
    @api showBorder = false;

    get hasValidUrl() {
        return (
            typeof this.iframeUrl === 'string' &&
            this.iframeUrl.trim().startsWith('https://')
        );
    }

    get containerStyle() {
        return `width:${this.normalizeSize(this.width, '100%')};height:${this.normalizeSize(this.height, '600px')};`;
    }

    get iframeStyle() {
        const border = this.showBorder ? '1px solid #d8dde6' : '0';
        return `border:${border};width:100%;height:100%;display:block;`;
    }

    normalizeSize(value, defaultValue) {
        if (!value || typeof value !== 'string') {
            return defaultValue;
        }

        const trimmed = value.trim();

        if (/^\d+$/.test(trimmed)) {
            return `${trimmed}px`;
        }

        if (
            trimmed.endsWith('px') ||
            trimmed.endsWith('%') ||
            trimmed.endsWith('vh') ||
            trimmed.endsWith('vw') ||
            trimmed.endsWith('rem')
        ) {
            return trimmed;
        }

        return defaultValue;
    }
}
