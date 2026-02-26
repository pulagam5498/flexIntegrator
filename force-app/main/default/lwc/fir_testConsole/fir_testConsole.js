import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getAllConfigs from '@salesforce/apex/FIR_IntegratorController.getAllConfigs';
import makeRequest from '@salesforce/apex/FIR_IntegratorController.makeRequest';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const TAB_NAV_BASE   = 'slds-tabs_default__item';
const TAB_NAV_ACTIVE = 'slds-tabs_default__item slds-is-active';
const TAB_BODY_SHOW  = 'slds-tabs_default__content slds-show';
const TAB_BODY_HIDE  = 'slds-tabs_default__content slds-hide';

export default class FirTestConsole extends LightningElement {

    connectedCallback() {
        console.log('[TC] ✅ Component connected to DOM');
    }

    @track relativePaths        = [];
    @track selectedRelativePath = '';
    @track selectedMetadata     = null;
    @track activeTab            = 'request';
    @track method               = 'GET';
    @track url                  = '';
    @track requestBody          = '';
    @track headers              = [{ id: '1', key: 'Content-Type', value: 'application/json' }];
    @track response             = null;
    @track error                = null;
    @track loading              = false;
    @track copied               = false;

    headerIdCounter = 2;
    metadataMap     = new Map();   // keyed by Relative_Path__c (matches combobox value)
    currentDevName  = '';
    metadataLoaded  = false;

    // ── Options ───────────────────────────────────────────────────────────────
    get methodOptions() {
        return [
            { label: 'GET',    value: 'GET'    },
            { label: 'POST',   value: 'POST'   },
            { label: 'PUT',    value: 'PUT'    },
            { label: 'PATCH',  value: 'PATCH'  },
            { label: 'DELETE', value: 'DELETE' }
        ];
    }

    // ── Computed getters ──────────────────────────────────────────────────────
    get showBody()            { return this.method !== 'GET' && this.method !== 'DELETE'; }
    get hasResponse()         { return this.response !== null; }
    get hasHeaders()          { return this.headers.length > 0; }
    get copyIcon()            { return this.copied ? 'utility:check' : 'utility:copy_to_clipboard'; }
    get hasHeadersPopulated() { return this.headers.length > 0; }
    get hasBodyPopulated()    { return !!(this.requestBody && this.requestBody.trim()); }
    get headerCount()         { return this.headers.length; }

    get methodBadgeClass() {
        var map = {
            GET:    'fi-badge fi-badge_get',
            POST:   'fi-badge fi-badge_post',
            PUT:    'fi-badge fi-badge_put',
            DELETE: 'fi-badge fi-badge_delete',
            PATCH:  'fi-badge fi-badge_patch'
        };
        return map[this.method] || 'fi-badge';
    }

    get formattedResponse() {
        if (!this.response) return '';
        var raw = this.response.data;
        if (raw === null || raw === undefined) return '(empty response)';
        if (typeof raw === 'string') {
            try   { return JSON.stringify(JSON.parse(raw), null, 2); }
            catch (e) { return raw; }
        }
        try   { return JSON.stringify(raw, null, 2); }
        catch (e) { return String(raw); }
    }

    get statusBadgeClass() {
        if (!this.response || !this.response.status) return 'fi-badge';
        var s = this.response.status;
        if (s >= 200 && s < 300) return 'fi-badge fi-badge_success';
        if (s >= 400 && s < 500) return 'fi-badge fi-badge_warn';
        if (s >= 500)            return 'fi-badge fi-badge_error';
        return 'fi-badge';
    }

    // ── Tab getters ───────────────────────────────────────────────────────────
    _tabNav(tab)     { return this.activeTab === tab ? TAB_NAV_ACTIVE : TAB_NAV_BASE; }
    _tabContent(tab) { return this.activeTab === tab ? TAB_BODY_SHOW  : TAB_BODY_HIDE; }
    _tabIndex(tab)   { return this.activeTab === tab ? '0' : '-1'; }

    get tabNavClassRequest()     { return this._tabNav('request'); }
    get tabNavClassHeaders()     { return this._tabNav('headers'); }
    get tabNavClassBody()        { return this._tabNav('body'); }
    get tabContentClassRequest() { return this._tabContent('request'); }
    get tabContentClassHeaders() { return this._tabContent('headers'); }
    get tabContentClassBody()    { return this._tabContent('body'); }
    get tabIndexRequest()        { return this._tabIndex('request'); }
    get tabIndexHeaders()        { return this._tabIndex('headers'); }
    get tabIndexBody()           { return this._tabIndex('body'); }
    get isTabRequest()           { return this.activeTab === 'request'; }
    get isTabHeaders()           { return this.activeTab === 'headers'; }
    get isTabBody()              { return this.activeTab === 'body'; }

    // ── Wire: Page reference ──────────────────────────────────────────────────
    @wire(CurrentPageReference)
    pageRefChange(pageRef) {
        if (pageRef && pageRef.state && pageRef.state.c__developerName &&
            pageRef.state.c__developerName !== this.currentDevName) {
            this.currentDevName = pageRef.state.c__developerName;
            if (this.metadataLoaded && this.metadataMap.has(this.currentDevName)) {
                this.loadMetadata(this.metadataMap.get(this.currentDevName));
            }
        }
    }

    // ── Wire: All configs ─────────────────────────────────────────────────────
    // Map keyed by Relative_Path__c so combobox value lookup works directly
    @wire(getAllConfigs)
    wiredMetadata({ data, error }) {
        if (data) {
            console.log('[TC] 🔵 wiredMetadata fired — records received:', data.length);
            var self = this;
            // Key map by DeveloperName (always unique)
            data.forEach(function(m) { self.metadataMap.set(m.DeveloperName, m); });

            // Combobox: label = MasterLabel, value = DeveloperName
            self.relativePaths = data.map(function(m) {
                return { label: m.MasterLabel, value: m.DeveloperName };
            });

            console.log('[TC] 🔵 relativePaths built:', self.relativePaths.length, 'options');
            console.log('[TC] 🔵 First option:', JSON.stringify(self.relativePaths[0]));

            self.metadataLoaded = true;

            // If navigated via page ref, load that record
            if (self.currentDevName && self.metadataMap.has(self.currentDevName)) {
                console.log('[TC] 🔵 Loading by page ref devName:', self.currentDevName);
                self.loadMetadata(self.metadataMap.get(self.currentDevName));
                return;
            }

            // Otherwise auto-select first record
            if (self.relativePaths.length > 0 && !self.selectedRelativePath) {
                var firstKey = self.relativePaths[0].value;
                console.log('[TC] 🔵 Auto-selecting first record:', firstKey);
                self.selectedRelativePath = firstKey;
                self.loadMetadata(self.metadataMap.get(firstKey));
            }
        } else if (error) {
            console.error('[TC] 🔴 wiredMetadata ERROR:', JSON.stringify(error));
        }
    }

    // ── Populate all fields from selected config ───────────────────────────────
    loadMetadata(cmdt) {
        if (!cmdt) { console.warn('[TC] 🟡 loadMetadata called with null/undefined'); return; }
        console.log('[TC] 🟢 loadMetadata — DeveloperName:', cmdt.DeveloperName, '| Method:', cmdt.Http_Method__c, '| Path:', cmdt.Relative_Path__c);
        this.selectedRelativePath = cmdt.DeveloperName;  // matches combobox value
        this.selectedMetadata     = cmdt;
        this.method               = cmdt.Http_Method__c || 'GET';
        this.url                  = 'callout:' + cmdt.Named_Credential_API_Name__c + cmdt.Relative_Path__c;
        this.requestBody          = cmdt.Request_Body_Template__c || '';
        this.response             = null;
        this.error                = null;
        this.activeTab            = 'request';
        this.headerIdCounter      = 2;

        var newHeaders = [];

        if (cmdt.Request_Content_Type__c) {
            newHeaders.push({ id: '1', key: 'Content-Type', value: cmdt.Request_Content_Type__c });
        }

        if (cmdt.Custom_Headers_JSON__c) {
            try {
                // Try single JSON object first: {"Key":"Value"}
                var parsed = JSON.parse(cmdt.Custom_Headers_JSON__c);
                var self = this;
                Object.entries(parsed).forEach(function(entry) {
                    if (entry[0].toLowerCase() !== 'content-type') {
                        newHeaders.push({ id: String(self.headerIdCounter++), key: entry[0], value: String(entry[1]) });
                    }
                });
            } catch (e) {
                // Fallback: line-by-line JSON objects
                var lines = cmdt.Custom_Headers_JSON__c.split('\n').map(function(l) { return l.trim(); }).filter(function(l) { return l.length; });
                var self2 = this;
                lines.forEach(function(line) {
                    try {
                        var obj = JSON.parse(line);
                        Object.keys(obj).forEach(function(key) {
                            if (key.toLowerCase() !== 'content-type') {
                                newHeaders.push({ id: String(self2.headerIdCounter++), key: key, value: String(obj[key]) });
                            }
                        });
                    } catch (e2) { /* skip invalid lines */ }
                });
            }
        }

        this.headers = newHeaders.length
            ? newHeaders
            : [{ id: '1', key: 'Content-Type', value: 'application/json' }];
    }

    // ── Event handlers ────────────────────────────────────────────────────────
    handleRelativePathChange(event) {
        var devName = event.detail.value;
        this.selectedRelativePath = devName;
        var cmdt = this.metadataMap.get(devName);  // map keyed by DeveloperName
        if (cmdt) this.loadMetadata(cmdt);
    }

    handleMethodChange(event) {
        this.method = event.detail.value;
        if (!this.showBody) this.requestBody = '';
    }

    handleUrlChange(event) {
        this.url = event.detail.value;
    }

    handleBodyChange(event) {
        this.requestBody = event.detail.value;
    }

    // Unified handler — called from HTML via data-field="key" or data-field="value"
    handleHeaderFieldChange(event) {
        var id    = event.target.dataset.id;
        var field = event.target.dataset.field;
        var val   = event.target.value;
        this.headers = this.headers.map(function(h) {
            return h.id === id ? Object.assign({}, h, { [field]: val }) : h;
        });
    }

    addHeader() {
        this.headers = this.headers.concat([
            { id: String(this.headerIdCounter++), key: '', value: '' }
        ]);
    }

    removeHeader(event) {
        var id = event.target.dataset.id;
        this.headers = this.headers.filter(function(h) { return h.id !== id; });
    }

    switchTab(event) {
        event.preventDefault();
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') this.sendRequest();
    }

    resetConsole() {
        this.selectedRelativePath = '';
        this.selectedMetadata     = null;
        this.method               = 'GET';
        this.url                  = '';
        this.requestBody          = '';
        this.headers              = [{ id: '1', key: 'Content-Type', value: 'application/json' }];
        this.headerIdCounter      = 2;
        this.response             = null;
        this.error                = null;
        this.activeTab            = 'request';
    }

    // ── Send request ──────────────────────────────────────────────────────────
    sendRequest() {
        if (!this.url || this.url.trim() === '') {
            this.error = 'Please select a configuration or enter a valid endpoint URL.';
            return;
        }
        if (!this.method) {
            this.error = 'HTTP Method is required.';
            return;
        }

        this.loading  = true;
        this.error    = null;
        this.response = null;

        var self      = this;
        var startTime = Date.now();
        var headerMap = {};
        this.headers.forEach(function(h) {
            if (h.key && h.value) headerMap[h.key] = h.value;
        });

        makeRequest({
            method:   this.method,
            endpoint: this.url,
            headers:  JSON.stringify(headerMap),
            body:     this.showBody ? (this.requestBody || '') : null
        })
        .then(function(result) {
            // FIR_ResponseHandler: statusCode, responseBody, errorMessage
            var code = result && result.statusCode;
            self.response = {
                status:     code,
                statusText: (result && result.errorMessage) || self._statusText(code),
                data:       result && result.responseBody,
                time:       Date.now() - startTime
            };
        })
        .catch(function(e) {
            self.error = (e && e.body && e.body.message) || (e && e.message) || 'Request failed';
            self.dispatchEvent(new ShowToastEvent({ title: 'Request Failed', message: self.error, variant: 'error' }));
        })
        .finally(function() {
            self.loading = false;
        });
    }

    // ── Copy response ─────────────────────────────────────────────────────────
    copyResponse() {
        if (!this.response) return;
        var self = this;
        var text = typeof this.response.data === 'string'
            ? this.response.data
            : JSON.stringify(this.response.data, null, 2);
        navigator.clipboard.writeText(text)
            .then(function() {
                self.copied = true;
                self.dispatchEvent(new ShowToastEvent({ title: 'Copied', message: 'Response copied to clipboard.', variant: 'success' }));
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(function() { self.copied = false; }, 2000);
            })
            .catch(function(e) { console.error('Copy failed', e); });
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _statusText(code) {
        var map = {
            200: 'OK', 201: 'Created', 204: 'No Content',
            400: 'Bad Request', 401: 'Unauthorized', 403: 'Forbidden',
            404: 'Not Found', 500: 'Internal Server Error'
        };
        return map[code] || '';
    }
}
