import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getAllConfigs from '@salesforce/apex/FIR_IntegratorController.getAllConfigs';
import makeRequest from '@salesforce/apex/FIR_IntegratorController.makeRequest';

export default class FirTestConsole extends LightningElement {

    // ---------------- TRACKED PROPERTIES ----------------
    @track relativePaths = [];
    @track selectedRelativePath = '';
    @track selectedMetadata = null;
    @track currentDevName = '';

    @track method = 'GET';
    @track url = '';
    @track requestBody = '';

    @track headers = [{ id: '1', key: 'Content-Type', value: 'application/json' }];

    @track response = null;
    @track error = null;
    @track loading = false;
    @track copied = false;

    // ---------------- INTERNAL ----------------
    headerIdCounter = 2;
    metadataMap = new Map();
    metadataLoaded = false;

    // ---------------- OPTIONS ----------------
    get methodOptions() {
        return [
            { label: 'GET', value: 'GET' },
            { label: 'POST', value: 'POST' },
            { label: 'PUT', value: 'PUT' },
            { label: 'PATCH', value: 'PATCH' },
            { label: 'DELETE', value: 'DELETE' }
        ];
    }

    get showBody() {
        return this.method !== 'GET' && this.method !== 'DELETE';
    }

    get hasResponse() {
        return this.response !== null;
    }

    get formattedResponse() {
        if (!this.response) return '';
        try {
            return JSON.stringify(this.response.data, null, 2);
        } catch {
            return String(this.response.data);
        }
    }

    // ---------------- PAGE PARAMS ----------------
    @wire(CurrentPageReference)
    pageRefChange(pageRef) {
        const devName = pageRef?.state?.c__developerName;
        if (devName && devName !== this.currentDevName) {
            this.currentDevName = devName;
            this.loadMetadataFromDevName();
        }
    }

    // ---------------- CMDT WIRE ----------------
    @wire(getAllConfigs)
    wiredMetadata({ data, error }) {
        if (data) {
            data.forEach(m => this.metadataMap.set(m.DeveloperName, m));
            this.relativePaths = data.map(m => ({ label: m.MasterLabel, value: m.Relative_Path__c }));
            this.metadataLoaded = true;
            this.loadMetadataFromDevName();
        } else if (error) {
            console.error(error);
        }
    }

    // ---------------- LOAD METADATA ----------------
    loadMetadataFromDevName() {
        if (!this.currentDevName || !this.metadataLoaded) return;

        const record = this.metadataMap.get(this.currentDevName);
        if (record) {
            this.loadMetadata(record);
        }
    }

    loadMetadata(cmdt) {
        // Reset properties for fresh load
        this.selectedRelativePath = '';
        this.selectedMetadata = null;
        this.method = 'GET';
        this.url = '';
        this.requestBody = '';
        this.headers = [{ id: '1', key: 'Content-Type', value: 'application/json' }];
        this.headerIdCounter = 2;

        // Load CMDT values
        this.selectedRelativePath = cmdt.Relative_Path__c;
        this.selectedMetadata = cmdt;
        this.method = cmdt.Http_Method__c || 'GET';
        this.url = `callout:${cmdt.Named_Credential_API_Name__c}${cmdt.Relative_Path__c}`;
        this.requestBody = cmdt.Request_Body__c || '';

        const newHeaders = [];

        // Content-Type first
        if (cmdt.Request_Content_Type__c) {
            newHeaders.push({ id: '1', key: 'Content-Type', value: cmdt.Request_Content_Type__c });
        }

        // Custom headers
        if (cmdt.Custom_Headers_JSON__c) {
            const parsed = this.parseHeadersFromLongText(cmdt.Custom_Headers_JSON__c);
            parsed.forEach(h => {
                if (h.key.toLowerCase() !== 'content-type') {
                    newHeaders.push({ id: String(this.headerIdCounter++), key: h.key, value: h.value });
                }
            });
        }

        this.headers = newHeaders;
    }

    parseHeadersFromLongText(text) {
        if (!text) return [];
        const lines = text.split('\n').map(l => l.trim()).filter(l => l.length);
        const parsed = [];
        lines.forEach((line, index) => {
            try {
                const obj = JSON.parse(line);
                Object.keys(obj).forEach(key => parsed.push({ key, value: obj[key] }));
            } catch {
                console.warn(`Invalid header JSON on line ${index + 1}:`, line);
            }
        });
        return parsed;
    }

    handleRelativePathChange(event) {
        this.selectedRelativePath = event.detail.value;
        const cmdt = Array.from(this.metadataMap.values()).find(m => m.Relative_Path__c === this.selectedRelativePath);
        if (cmdt) this.loadMetadata(cmdt);
    }

    handleMethodChange(e) {
        this.method = e.detail.value;
        if (!this.showBody) this.requestBody = '';
    }

    handleUrlChange(e) {
        this.url = e.target.value;
    }

    handleBodyChange(e) {
        this.requestBody = e.target.value;
    }

    handleHeaderKeyChange(e) {
        const id = e.target.dataset.id;
        this.headers = this.headers.map(h => h.id === id ? { ...h, key: e.target.value } : h);
    }

    handleHeaderValueChange(e) {
        const id = e.target.dataset.id;
        this.headers = this.headers.map(h => h.id === id ? { ...h, value: e.target.value } : h);
    }

    addHeader() {
        this.headers = [...this.headers, { id: String(this.headerIdCounter++), key: '', value: '' }];
    }

    removeHeader(e) {
        const id = e.target.dataset.id;
        this.headers = this.headers.filter(h => h.id !== id);
    }

    // ---------------- SEND REQUEST ----------------
    async sendRequest() {
        this.error = null;
        this.response = null;

        // Validations
        if (!this.url?.trim()) { this.error = 'Please select a Request or enter a valid endpoint URL.'; return; }
        if (!this.method) { this.error = 'HTTP Method is required.'; return; }
        if (this.showBody && !this.requestBody?.trim()) { this.error = 'Request body is required for this method.'; return; }

        this.loading = true;
        try {
            const headerMap = {};
            this.headers.forEach(h => { if (h.key && h.value) headerMap[h.key] = h.value; });

            const result = await makeRequest({
                method: this.method,
                endpoint: this.url,
                headers: JSON.stringify(headerMap),
                body: this.showBody ? this.requestBody : null
            });

            this.response = {
                status: result?.status,
                statusText: result?.statusText,
                data: result?.body
            };

        } catch (e) {
            this.error = e?.body?.message || e?.message || 'Request failed';
        } finally {
            this.loading = false;
        }
    }

    // ---------------- TAB HANDLING ----------------
    activeTab = 'request';

    switchTab(event) {
        const tab = event.currentTarget.dataset.tab;
        this.activeTab = tab;
        
        // Update tab visibility
        const tabs = this.template.querySelectorAll('.slds-tabs_default__content');
        tabs.forEach(tabEl => {
            if (tabEl.id === `tab-${tab}`) {
                tabEl.classList.remove('slds-hide');
                tabEl.classList.add('slds-show');
            } else {
                tabEl.classList.remove('slds-show');
                tabEl.classList.add('slds-hide');
            }
        });
        
        // Update tab links
        const tabLinks = this.template.querySelectorAll('.slds-tabs_default__link');
        tabLinks.forEach(link => {
            const linkTab = link.dataset.tab;
            if (linkTab === tab) {
                link.setAttribute('tabindex', '0');
                link.setAttribute('aria-selected', 'true');
            } else {
                link.setAttribute('tabindex', '-1');
                link.setAttribute('aria-selected', 'false');
            }
        });
    }

    // ---------------- COPY RESPONSE ----------------
    async copyResponse() {
        if (!this.response) return;
        await navigator.clipboard.writeText(JSON.stringify(this.response.data, null, 2));
        this.copied = true;
        setTimeout(() => this.copied = false, 2000);
    }
}