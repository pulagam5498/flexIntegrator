import { LightningElement, track, wire } from 'lwc';
import getAllConfigs        from '@salesforce/apex/FIR_IntegratorController.getAllConfigs';
import saveConfig           from '@salesforce/apex/FIR_IntegratorController.saveConfig';
import testConnection        from '@salesforce/apex/FIR_IntegratorController.testConnection';
import deleteMdtRecord      from '@salesforce/apex/FIR_IntegratorController.deleteMdtRecord';
import getNamedCredentials  from '@salesforce/apex/FIR_NamedCredentialService.getNamedCredentials';
import getPicklistValues    from '@salesforce/apex/FIR_NamedCredentialService.getPicklistValues';
import { ShowToastEvent }   from 'lightning/platformShowToastEvent';
import { NavigationMixin }  from 'lightning/navigation';

// ─── Constants ────────────────────────────────────────────────────────────────
const HTTP_METHODS = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'];

const METHOD_BADGE_CLASS = {
    GET:    'fi-badge fi-badge_get',
    POST:   'fi-badge fi-badge_post',
    PUT:    'fi-badge fi-badge_put',
    DELETE: 'fi-badge fi-badge_delete',
    PATCH:  'fi-badge fi-badge_patch',
};

const ROW_BASE   = 'fi-config-row';
const ROW_ACTIVE = 'fi-config-row fi-config-row_selected';

const TAB_NAV_BASE   = 'slds-tabs_default__item';
const TAB_NAV_ACTIVE = 'slds-tabs_default__item slds-is-active';
const TAB_BODY_SHOW  = 'slds-tabs_default__content slds-show';
const TAB_BODY_HIDE  = 'slds-tabs_default__content slds-hide';

// JWT mode values
const JWT_NONE = 'none';
const JWT_SAME = 'same';
const JWT_DIFF = 'diff';

// Max Retries options
const MAX_RETRIES_OPTIONS = [
    { label: '1', value: '1' },
    { label: '2', value: '2' },
    { label: '3', value: '3' },
    { label: '4', value: '4' },
    { label: '5', value: '5' }
];

// ─── Component ────────────────────────────────────────────────────────────────
export default class Fir_IntegrationConfig extends NavigationMixin(LightningElement) {

    // ── Tracked state ─────────────────────────────────────────────────────────
    @track configList       = [];
    @track selectedConfig   = null;
    @track templateRows     = [];
    @track isLoading        = false;
    @track activeTab        = 'general';
    @track autosaveVisible  = false;
    @track jwtMode          = JWT_NONE;   // 'none' | 'same' | 'diff'

    // ── Non-reactive ──────────────────────────────────────────────────────────
    _data            = [];
    mode             = '';
    searchKey        = '';
    isTesting        = false;
    testResult       = null;
    ncOptions        = [];
    requestCTOptions = [];
    _searchDebounce;
    _autosaveHideTimer;

    // ── Wire: Named Credentials ───────────────────────────────────────────────
    @wire(getNamedCredentials)
    wiredNC({ data, error }) {
        if (data)  this.ncOptions = data.map(nc => ({ label: nc.label, value: nc.apiName }));
        if (error) this._handleError('Failed to load Named Credentials', error);
    }

    // ── Wire: Picklist values ─────────────────────────────────────────────────
    @wire(getPicklistValues, {
        objectApiName: 'Flex_Integrator_Configuration__mdt',
        fieldApiName:  'Request_Content_Type__c'
    })
    wiredRequestCT({ data, error }) {
        if (data)  this.requestCTOptions = data.map(v => ({ label: v.label, value: v.value }));
        if (error) this._handleError('Failed to load content type options', error);
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this.loadData();
    }

    // ── Data loading ──────────────────────────────────────────────────────────
    async loadData() {
        this.isLoading = true;
        try {
            const result    = await getAllConfigs();
            this._data      = result || [];
            this.configList = this._buildRows(this._data);
        } catch (error) {
            this._handleError('Failed to load configurations', error);
        } finally {
            this.isLoading = false;
        }
    }

    _cardClass(id) {
        return this.selectedConfig?.Id === id
            ? 'fi-config-card fi-config-card_selected'
            : 'fi-config-card';
    }

    _buildRows(list) {
        return (list || []).map((row, idx) => ({
            ...row,
            rowNumber:        idx + 1,
            methodBadgeClass: METHOD_BADGE_CLASS[row.Http_Method__c] || 'fi-badge',
            rowClass:         this.selectedConfig?.Id === row.Id ? ROW_ACTIVE : ROW_BASE,
            cardClass:        this._cardClass(row.Id),
            isActive:         this.selectedConfig?.Id === row.Id,
            isDirty:          false,
        }));
    }

    _refreshRowClasses() {
        this.configList = this.configList.map(r => ({
            ...r,
            rowClass:  this.selectedConfig?.Id === r.Id ? ROW_ACTIVE : ROW_BASE,
            cardClass: this._cardClass(r.Id),
            isActive:  this.selectedConfig?.Id === r.Id,
        }));
    }

    // ── Refresh ───────────────────────────────────────────────────────────────
    refresh = async () => {
        this.selectedConfig   = null;
        this.mode             = '';
        this.testMessage      = '';
        this.testResult       = null;
        this.isTesting        = false;
        this.activeTab        = 'general';
        this.jwtMode          = JWT_NONE;
        await this.loadData();
    };

    // ── Row click → open edit ─────────────────────────────────────────────────
    handleRowClick(event) {
        const id     = event.currentTarget.dataset.id;
        const record = this._data.find(r => r.Id === id);
        if (record) this._openRecord(record);
    }

    _openRecord(record) {
        this.selectedConfig   = JSON.parse(JSON.stringify(record));
        this.mode             = 'edit';
        this.testResult       = null;
        this.testMessage      = '';
        this.activeTab        = 'general';
        this._loadTemplateRows();
        this._deriveJwtMode();
        this.evaluateActiveState();
        this._refreshRowClasses();
    }

    closeDrawer() {
        this.selectedConfig = null;
        this.mode           = '';
        this.activeTab      = 'general';
        this.jwtMode        = JWT_NONE;
        this._refreshRowClasses();
    }

    // ── Derive JWT mode from existing record data ─────────────────────────────
    _deriveJwtMode() {
        if (!this.selectedConfig?.JWT_Required__c) {
            this.jwtMode = JWT_NONE;
        } else if (this.selectedConfig?.JWT_Named_Credential__c) {
            this.jwtMode = JWT_DIFF;
        } else {
            this.jwtMode = JWT_SAME;
        }
    }

    // ── JWT mode change ───────────────────────────────────────────────────────
    handleJwtModeChange(event) {
        const mode = event.currentTarget.dataset.mode;
        this.jwtMode = mode;

        // Sync JWT_Required__c flag based on mode
        const jwtRequired = mode !== JWT_NONE;
        this.selectedConfig = {
            ...this.selectedConfig,
            JWT_Required__c:       jwtRequired,
            // Clear the diff-only credential when switching away from diff
            JWT_Named_Credential__c: mode === JWT_DIFF
                ? this.selectedConfig.JWT_Named_Credential__c
                : null,
        };
        this._resetJwtState();
        this.evaluateActiveState();
    }

    // ── JWT mode getters ──────────────────────────────────────────────────────
    get isJwtNone() { return this.jwtMode === JWT_NONE; }
    get isJwtSame() { return this.jwtMode === JWT_SAME; }
    get isJwtDiff() { return this.jwtMode === JWT_DIFF; }

    // Button CSS classes for the segmented group
    _jwtBtnClass(mode) {
        const base = 'fi-jwt-btn';
        return this.jwtMode === mode ? `${base} fi-jwt-btn_active` : base;
    }

    get jwtBtnClassNone() { return this._jwtBtnClass(JWT_NONE); }
    get jwtBtnClassSame() { return this._jwtBtnClass(JWT_SAME); }
    get jwtBtnClassDiff() { return this._jwtBtnClass(JWT_DIFF); }

    // ── List action: Test ─────────────────────────────────────────────────────
    handleTest(event) {
        event.stopPropagation();
        const id     = event.currentTarget.dataset.id;
        const record = this._data.find(r => r.Id === id);
        if (record) {
            this._openRecord(record);
            this.activeTab = 'general';
        }
    }

    // ── Duplicate ─────────────────────────────────────────────────────────────
    handleDuplicate(event) {
        event.stopPropagation();
        const id     = event.currentTarget.dataset.id;
        const record = this._data.find(r => r.Id === id);
        if (record) this._doDuplicate(record);
    }

    handleDuplicateActive() {
        if (this.selectedConfig) this._doDuplicate(this.selectedConfig);
    }

    _doDuplicate(record) {
        this.selectedConfig = {
            ...JSON.parse(JSON.stringify(record)),
            Id:            undefined,
            DeveloperName: record.DeveloperName + '_Copy',
            MasterLabel:   (record.MasterLabel || record.DeveloperName) + ' Copy',
        };
        this.mode             = 'new';
        this.testResult       = null;
        this.testMessage      = '';
        this.activeTab        = 'general';
        this._loadTemplateRows();
        this._deriveJwtMode();
        this._refreshRowClasses();
        this._showToast('Duplicated', `Editing copy of "${record.DeveloperName}"`, 'info');
    }

    // ── Delete ────────────────────────────────────────────────────────────────
    handleDelete(event) {
        event.stopPropagation();
        const name = event.currentTarget.dataset.name;
        const id  = event.currentTarget.dataset.id;
        const record = this._data.find(r => r.Id === id);
        console.log('name- ',name);
        deleteMdtRecord({ developerName: name })
            .then(() => {
                if (this.selectedConfig?.Id === id) this.closeDrawer();
                this._showToast('Deleted', `"${record?.DeveloperName || id}" removed`, 'info');
                setTimeout(() => this.loadData(), 1500);
            })
            .catch(error => {
                console.error(error);
            });
        /*const id     = event.currentTarget.dataset.id;
        const record = this._data.find(r => r.Id === id);
        this._data      = this._data.filter(r => r.Id !== id);
        this.configList = this._buildRows(this._data);
        if (this.selectedConfig?.Id === id) this.closeDrawer();
        this._showToast('Deleted', `"${record?.DeveloperName || id}" removed`, 'info');*/
    }

    stopPropagation(event) { event.stopPropagation(); }

    // ── Search ────────────────────────────────────────────────────────────────
    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase().trim();
        clearTimeout(this._searchDebounce);
        this.isLoading = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchDebounce = setTimeout(() => {
            const q = this.searchKey;
            this.configList = this._buildRows(
                q ? this._data.filter(row =>
                    Object.values(row).some(v => String(v ?? '').toLowerCase().includes(q))
                ) : this._data
            );
            this.isLoading = false;
        }, 300);
    }

    // ── Tab switching ─────────────────────────────────────────────────────────
    switchTab(event) {
        event.preventDefault();
        this.activeTab = event.currentTarget.dataset.tab;
    }

    get isTabGeneral() { return this.activeTab === 'general'; }
    get isTabAuth()    { return this.activeTab === 'auth'; }
    get isTabHeaders() { return this.activeTab === 'headers'; }
    get isTabBody()    { return this.activeTab === 'body'; }

    _tabNav(tab)     { return this.activeTab === tab ? TAB_NAV_ACTIVE : TAB_NAV_BASE; }
    _tabContent(tab) { return this.activeTab === tab ? TAB_BODY_SHOW  : TAB_BODY_HIDE; }
    _tabIndex(tab)   { return this.activeTab === tab ? '0' : '-1'; }

    get tabNavClassGeneral()     { return this._tabNav('general'); }
    get tabNavClassAuth()        { return this._tabNav('auth'); }
    get tabNavClassHeaders()     { return this._tabNav('headers'); }
    get tabNavClassBody()        { return this._tabNav('body'); }
    get tabContentClassGeneral() { return this._tabContent('general'); }
    get tabContentClassAuth()    { return this._tabContent('auth'); }
    get tabContentClassHeaders() { return this._tabContent('headers'); }
    get tabContentClassBody()    { return this._tabContent('body'); }
    get tabIndexGeneral()        { return this._tabIndex('general'); }
    get tabIndexAuth()           { return this._tabIndex('auth'); }
    get tabIndexHeaders()        { return this._tabIndex('headers'); }
    get tabIndexBody()           { return this._tabIndex('body'); }

    // ── Flag toggles ──────────────────────────────────────────────────────────
    handleFlagToggle(event) {
        const field = event.currentTarget.dataset.field;
        if (!this.selectedConfig || !field) return;
        const newVal = !this.selectedConfig[field];
        this.selectedConfig = { ...this.selectedConfig, [field]: newVal };
        if (field === 'Is_Active__c') this.evaluateActiveState();
    }

    handleFlagKeyDown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleFlagToggle(event);
        }
    }

    _flagClass(field) { return this.selectedConfig?.[field] ? 'fi-flag-card fi-flag-card_on' : 'fi-flag-card'; }
    _pillClass(field) { return this.selectedConfig?.[field] ? 'fi-pill fi-pill_on' : 'fi-pill'; }

    get flagClassLog()    { return this._flagClass('Is_Log_Required__c'); }
    get flagClassActive() { return this._flagClass('Is_Active__c'); }
    get flagClassAsync()  { return this._flagClass('Is_Async__c'); }
    get pillClassLog()    { return this._pillClass('Is_Log_Required__c'); }
    get pillClassActive() { return this._pillClass('Is_Active__c'); }
    get pillClassAsync()  { return this._pillClass('Is_Async__c'); }

    // ── Field change ──────────────────────────────────────────────────────────
    handleChange(event) {
        if (!this.selectedConfig) return;
        const field = event.target.name;
        let value   = event.detail?.value ?? event.target.value;
        if (event.target.type === 'number') value = value === '' ? null : Number(value);
        this.selectedConfig = { ...this.selectedConfig, [field]: value };
        if (['Token_Path__c', 'Token_Body__c', 'JWT_Named_Credential__c'].includes(field)) {
            this._resetJwtState();
        }
        if (field === 'Is_Active__c') this.evaluateActiveState();
    }

    // ── New configuration ─────────────────────────────────────────────────────
    handleNew() {
        this.selectedConfig   = { DeveloperName: '', MasterLabel: '', Max_Retries__c: '1' , Default_Timeout_ms__c: '10,000'};
        this.mode             = 'new';
        this.testResult       = null;
        this.testMessage      = '';
        this.isTesting        = false;
        this.templateRows     = [];
        this.activeTab        = 'general';
        this.jwtMode          = JWT_NONE;
        this._refreshRowClasses();
    }

    handleMasterLabelBlur(event) {
        if (!this.selectedConfig || this.mode !== 'new') return;
        const label = event.target.value;
        if (!this.selectedConfig.DeveloperName && label) {
            this.selectedConfig = {
                ...this.selectedConfig,
                DeveloperName: this._generateDeveloperName(label),
            };
        }
    }

    _generateDeveloperName(label) {
        return (label || '')
            .trim()
            .replace(/\s+/g, '_')
            .replace(/[^a-zA-Z0-9_]/g, '')
            .replace(/^(\d)/, '_$1');
    }

    // ── Template headers ──────────────────────────────────────────────────────
    _loadTemplateRows() {
        const rows = [];
        const raw  = this.selectedConfig?.Custom_Headers_JSON__c;
        if (raw) {
            try {
                Object.entries(JSON.parse(raw)).forEach(([k, v]) => {
                    rows.push({ id: `${Date.now()}_${Math.random()}`, key: k, value: v });
                });
            } catch (e) { console.error('Invalid Custom_Headers_JSON__c', e); }
        }
        this.templateRows = rows;
    }

    get editableTemplateRows() { return this.templateRows; }
    get hasHeaderRows()        { return this.templateRows.length > 0; }

    addTemplateRow() {
        this.templateRows = [
            ...this.templateRows,
            { id: `${Date.now()}_${Math.random()}`, key: '', value: '' },
        ];
    }

    handleTemplateChange(event) {
        const { id, field } = event.target.dataset;
        this.templateRows = this.templateRows.map(r =>
            r.id === id ? { ...r, [field]: event.target.value } : r
        );
        this._syncHeadersToJSON();
    }

    removeTemplateRow(event) {
        const id = event.target.dataset.id;
        this.templateRows = this.templateRows.filter(r => r.id !== id);
        this._syncHeadersToJSON();
    }

    _syncHeadersToJSON() {
        if (!this.selectedConfig) return;
        const obj = {};
        this.templateRows
            .filter(r => r.key?.trim())
            .forEach(r => (obj[r.key.trim()] = r.value ?? ''));
        this.selectedConfig = {
            ...this.selectedConfig,
            Custom_Headers_JSON__c: JSON.stringify(obj),
        };
    }

    // ── Validation ────────────────────────────────────────────────────────────
    _validateFields() {
        const inputs = this.template.querySelectorAll(
            'lightning-input, lightning-textarea, lightning-combobox'
        );
        let isValid = true;
        inputs.forEach(input => {
            if (input.setCustomValidity) input.setCustomValidity('');
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }

    // ── Save ──────────────────────────────────────────────────────────────────
    handleSave() {
        if (!this.selectedConfig || this.isLoading) return;
        this._syncHeadersToJSON();
        if (!this._validateFields()) return;

        this.isLoading = true;
        saveConfig({ config: this.selectedConfig })
            .then(() => {
                this._showToast('Success', `"${this.selectedConfig.MasterLabel}" saved successfully.`, 'success');
                this._showAutosave();
                this.selectedConfig   = null;
                this.mode             = '';
                this.jwtMode          = JWT_NONE;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this.loadData(), 1500);
            })
            .catch(err => {
                const msg = err?.body?.message || err?.message || 'Save failed.';
                this._showToast('Error', msg, 'error');
                this.isLoading = false;
            });
    }

    // ── JWT connection test ───────────────────────────────────────────────────
    handleTestConnection = async () => {
        if (!this.selectedConfig) return;
        const path = this.selectedConfig?.Token_Path__c?.trim();
        const body = this.selectedConfig?.Token_Body__c?.trim();

        if (this.jwtMode !== JWT_NONE && (!path || !body)) {
            //this.testResult  = 'failure';
            //this.testMessage = 'Provide both Token Path and Token Body before testing.';
            this.showNotification('error', 'Provide both Token Path and Token Body before testing.', 'error');
            return;
        }

        this.isTesting   = true;
        this.isLoading   = true;
        this.testResult  = null;
       let testMessage = '';
        try {
            const res    = await testConnection({
                config:  this.selectedConfig
            });
            const ok         = !!res?.success;
            this.testResult  = ok ? 'success' : 'error';
            const status     = res?.statusCode != null ? ` (Status ${res.statusCode})` : '';
            
            testMessage = `${res?.message || (ok ? 'Connection successful.' : 'Connection failed.')}${status}`;
            
        } catch (err) {
            this.testResult  = 'error';
            testMessage = `Connection failed: ${err?.body?.message || err?.message || JSON.stringify(err)}`;
            
        } finally {
            this.isTesting = false;
            this.isLoading = false;
            this.showNotification(this.testResult, testMessage , this.testResult);
            this.evaluateActiveState();
        }
    };

    // ── Active / JWT gating ───────────────────────────────────────────────────
    evaluateActiveState() {
        const isActive    = !!this.selectedConfig?.Is_Active__c;
        const jwtRequired = this.jwtMode !== JWT_NONE;
    }

    _resetJwtState() {
        this.testResult  = null;
        this.testMessage = '';
        this.isTesting   = false;
        this.evaluateActiveState();
    }


    // ── Navigation ────────────────────────────────────────────────────────────
    _navigateToTestConsole(developerName) {
        this[NavigationMixin.Navigate]({
            type:       'standard__navItemPage',
            attributes: { apiName: 'fir_test_console' },
            state:      { c__developerName: developerName, c__mode: 'test', c__ts: Date.now() },
        });
    }

    // ── Autosave badge ────────────────────────────────────────────────────────
    _showAutosave() {
        this.autosaveVisible = true;
        clearTimeout(this._autosaveHideTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._autosaveHideTimer = setTimeout(() => { this.autosaveVisible = false; }, 3000);
    }

    // ── Toast / error helpers ─────────────────────────────────────────────────
    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _handleError(title, error) {
        const message = error?.body?.message || error?.message || 'An unexpected error occurred.';
        console.error(title, error);
        this._showToast(title, message, 'error');
    }

    // ── Computed getters ──────────────────────────────────────────────────────
    get hasConfigs()          { return this.configList.length > 0; }
    get configCount()         { return this.configList.length; }

    get cardTitle() {
        if (this.mode === 'new')  return 'Create New Configuration';
        if (this.mode === 'edit') return `Edit: ${this.selectedConfig?.DeveloperName || ''}`;
        return 'Configuration';
    }

    get cardIcon() {
        return this.mode === 'new' ? 'action:approval' : 'action:new_note';
    }

 get isSaveDisabled() {
    const isActive = !!this.selectedConfig?.Is_Active__c;
    const isTestSuccess = this.testResult === 'success';

    return isActive && !isTestSuccess;
}

get warningMessage (){
  return  this.isSaveDisabled ? 'A successful connection test is required before activating this configuration.' : '';
}
get disabledDevName(){
    return this.selectedConfig?.Id != null;
}
 get httpMethodOptions() {
        return HTTP_METHODS.map(m => ({ label: m, value: m }));
    }

    get maxRetriesOptions() {
        return MAX_RETRIES_OPTIONS;
    }


showNotification(titleText, messageText, variant) {
    const evt = new ShowToastEvent({
      title: titleText,
      message: messageText,
      variant: variant,
    });
    this.dispatchEvent(evt);
  }
}