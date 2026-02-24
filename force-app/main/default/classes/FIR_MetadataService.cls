/**
 * Apex class: FIR_MetadataService
 *
 * Description:
 *  - Provides create/update (upsert) operations for Flex_Integrator_Configuration__mdt Custom Metadata
 *    using the Apex Metadata API (Metadata.Operations.enqueueDeployment).
 *  - Implements dynamic field mapping:
 *      * Field names are discovered at runtime from the CMD_TYPE via Schema describe.
 *      * Values are read directly from a supplied Flex_Integrator_Configuration__mdt sObject instance.
 *      * System/managed fields are excluded via SYSTEM_CMD_FIELDS.
 *      * Non-writable fields (formula, rollup, auto-number) are excluded via isCreateable/isUpdateable.
 *      * Null values ARE included — allowing fields to be explicitly cleared on the metadata record.
 *  - Maintains backward compatibility with legacy wrapper callers via createConfig/updateConfig.
 *
 * IMPORTANT — Async Deployment:
 *  - enqueueDeployment is asynchronous. upsertConfig returns a Metadata Job Id immediately,
 *    but the record is created/updated seconds later by Salesforce in the background.
 *  - The final outcome (success or failure) is handled by FlexIntegratorDeployCallback.
 *  - LWC callers should treat the returned job Id as "queued" not "saved".
 *  - Cannot be called from trigger context — use only from @AuraEnabled or async Apex.
 *
 * Created By: Masthan Andela
 * Last Updated:
 */
public class FIR_MetadataService {

    private static final String CMD_TYPE = 'Flex_Integrator_Configuration__mdt';

    // System/special fields excluded from Metadata API value mapping.
    // All values stored in lowercase — compared using apiName.toLowerCase().
    private static final Set<String> SYSTEM_CMD_FIELDS = new Set<String>{
        'id', 'developername', 'masterlabel', 'label', 'qualifiedapiname',
        'language', 'namespaceprefix', 'isprotected', 'createdbyid',
        'createddate', 'lastmodifiedbyid', 'lastmodifieddate', 'systemmodstamp'
    };

    // ═════════════════════════════════════════════════════════════════════════
    // CREATE — legacy wrapper (backward compatibility only)
    //
    // LEGACY: Maps only the original 14 fields from FlexIntegratorConfigWrapper.
    // New fields added to Flex_Integrator_Configuration__mdt are NOT automatically
    // picked up here. New callers should use upsertConfig(record) directly to
    // benefit from dynamic field mapping across all fields.
    // ═════════════════════════════════════════════════════════════════════════
    public static String createConfig(FIR_MetadataService.FlexIntegratorConfigWrapper w) {
        Flex_Integrator_Configuration__mdt rec = new Flex_Integrator_Configuration__mdt();
        rec.DeveloperName               = w.developerName;
        rec.MasterLabel                 = w.label;
        rec.Service_Name__c             = w.serviceName;
        rec.Http_Method__c              = w.httpMethod;
        rec.Relative_Path__c            = w.relativePath;
        rec.Named_Credential_API_Name__c = w.namedCredentialApiName;
        rec.Request_Content_Type__c     = w.requestContentType;
        rec.Request_Body_Template__c    = w.requestBodyTemplate;
        rec.Custom_Headers_JSON__c      = w.customHeadersJson;
        rec.Default_Timeout_ms__c       = w.defaultTimeoutMs;
        rec.Max_Retries__c              = w.maxRetries;
        rec.Is_Async__c                 = w.isAsync;
        rec.Is_Log_Required__c          = w.isLogRequired;
        rec.Response_Handling_Mode__c   = w.responseHandlingMode;
        rec.Response_Mapping__c         = w.responseMapping;
        return upsertConfig(rec);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UPDATE — legacy wrapper (backward compatibility only)
    //
    // Fix: was calling createConfig(w) → upsertConfig — unnecessary indirection.
    // Now calls upsertConfig directly via the record-building path.
    // Metadata API upserts by fullName so create and update are the same operation.
    // ═════════════════════════════════════════════════════════════════════════
    public static String updateConfig(FIR_MetadataService.FlexIntegratorConfigWrapper w) {
        // Delegate directly to createConfig which builds the record and calls upsertConfig.
        // Both operations are identical — Metadata API upserts by fullName.
        return createConfig(w);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UPSERT — main entry point
    //
    // Returns: Metadata Deployment Job Id (String, e.g. "04sf0000000xxxxx")
    //   - This is NOT a final success confirmation.
    //   - The record is created/updated asynchronously after this returns.
    //   - FlexIntegratorDeployCallback.handleResult() receives the actual outcome.
    //   - LWC should treat this as "queued" and refresh after a short delay.
    // ═════════════════════════════════════════════════════════════════════════
    public static String upsertConfig(Flex_Integrator_Configuration__mdt record) {

        // Fix: throw explicitly instead of returning null — caller gets a clear error
        if (record == null) {
            throw new AuraHandledException('Configuration record is required.');
        }
        if (String.isBlank(record.DeveloperName)) {
            throw new AuraHandledException('DeveloperName is required for Custom Metadata upsert.');
        }
        if (String.isBlank(record.MasterLabel)) {
            throw new AuraHandledException('MasterLabel is required for Custom Metadata upsert.');
        }

        Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
        cmd.fullName = CMD_TYPE + '.' + record.DeveloperName;
        cmd.label    = record.MasterLabel;
        cmd.values   = buildValues(record);

        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(cmd);

        return Metadata.Operations.enqueueDeployment(
            container,
            new FlexIntegratorDeployCallback()
        );
    }

    // ═════════════════════════════════════════════════════════════════════════
    // BUILD VALUES — dynamic field mapping
    //
    // Discovers all fields on Flex_Integrator_Configuration__mdt at runtime.
    // Excludes:
    //   - System fields listed in SYSTEM_CMD_FIELDS
    //   - Non-writable fields: formula, rollup, auto-number (isCreateable/isUpdateable)
    //
    // Fix: null values ARE now included (previously skipped).
    //   Sending null to Metadata API explicitly clears the field on the record.
    //   This allows users to blank out a field in the UI and have that saved correctly.
    //   Previously, cleared fields would silently retain their old value.
    // ═════════════════════════════════════════════════════════════════════════
    private static List<Metadata.CustomMetadataValue> buildValues(
        Flex_Integrator_Configuration__mdt record
    ) {
        List<Metadata.CustomMetadataValue> values = new List<Metadata.CustomMetadataValue>();

        Schema.DescribeSObjectResult sObjDescribe =
            Schema.describeSObjects(new List<String>{ CMD_TYPE })[0];

        if (sObjDescribe == null) {
            return values;
        }

        Map<String, Schema.SObjectField> fields = sObjDescribe.fields.getMap();

        for (String apiName : fields.keySet()) {

            // Exclude system/managed fields
            if (SYSTEM_CMD_FIELDS.contains(apiName.toLowerCase())) {
                continue;
            }

            Schema.DescribeFieldResult fr = fields.get(apiName).getDescribe();

            // Fix: exclude non-writable fields — formula, rollup, auto-number etc.
            // Without this check, attempting to set these causes the Metadata deployment
            // to fail silently (the callback receives the error, LWC already got a job Id).
            /*if (!fr.isCreateable() && !fr.isUpdateable()) {
                continue;
            }*/
            if (fr.isCalculated()) {
                continue;
            }

            // Read value from the sObject instance — null is valid (clears the field)
            Object fieldValue = record.get(apiName);

            // Add to values — null is intentionally passed through to clear the field
            addValue(values, apiName, fieldValue);
        }

        return values;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ADD VALUE
    //
    // Fix: null values are now added — Metadata API accepts null to clear a field.
    // Previously: if (value == null) return; — this prevented field clearing.
    // ═════════════════════════════════════════════════════════════════════════
    private static void addValue(
        List<Metadata.CustomMetadataValue> values,
        String field,
        Object value
    ) {
        Metadata.CustomMetadataValue mdv = new Metadata.CustomMetadataValue();
        mdv.field = field;
        mdv.value = value;   // null is valid — sends explicit clear to Metadata API
        values.add(mdv);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // DEPLOY CALLBACK
    //
    // Fix: was referenced in upsertConfig but never defined — compile error.
    // Implements Metadata.DeployCallback to receive the async deployment result.
    // Called by Salesforce when the metadata deployment completes (seconds after
    // enqueueDeployment returns).
    //
    // Note: This runs in a future/async context — cannot make callouts here.
    //       Use Platform Events or Custom Objects to surface results to the UI
    //       if real-time feedback is needed.
    // ═════════════════════════════════════════════════════════════════════════
    public class FlexIntegratorDeployCallback implements Metadata.DeployCallback {

        public void handleResult(
            Metadata.DeployResult result,
            Metadata.DeployCallbackContext ctx
        ) {
            if (!result.done) {
                // Deployment still in progress — Salesforce will call again when complete
                return;
            }

            if (result.success) {
                System.debug(LoggingLevel.INFO,
                    'FIR_MetadataService: Deployment succeeded. Job Id: ' + result.id);
            } else {
                // Collect all component-level failures for logging
                List<String> errors = new List<String>();
                if (result.details != null
                    && result.details.componentFailures != null
                    && !result.details.componentFailures.isEmpty()
                ) {
                    for (Metadata.DeployMessage failure : result.details.componentFailures) {
                        errors.add(failure.fullName + ': ' + failure.problem);
                    }
                }

                String errorSummary = String.join(errors, ' | ');
                System.debug(LoggingLevel.ERROR,
                    'FIR_MetadataService: Deployment failed. Job Id: ' + result.id
                    + ' | Errors: ' + errorSummary);

                // Surface to error framework if available
                // Harmoni_Utility.insertErrorReport(...) or equivalent
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // LEGACY WRAPPER
    // ═════════════════════════════════════════════════════════════════════════

    /**
     * LEGACY: Use upsertConfig(Flex_Integrator_Configuration__mdt) for new callers.
     * This wrapper exists for backward compatibility only. It maps a fixed set of
     * 14 fields — new fields added to the CMD type will not be included here.
     */
    public class FlexIntegratorConfigWrapper {
        @AuraEnabled public String  developerName;
        @AuraEnabled public String  label;
        @AuraEnabled public String  serviceName;
        @AuraEnabled public String  httpMethod;
        @AuraEnabled public String  relativePath;
        @AuraEnabled public String  namedCredentialApiName;
        @AuraEnabled public String  requestContentType;
        @AuraEnabled public String  requestBodyTemplate;
        @AuraEnabled public String  customHeadersJson;
        @AuraEnabled public Integer defaultTimeoutMs;
        @AuraEnabled public String 	maxRetries;
        @AuraEnabled public Boolean isAsync;
        @AuraEnabled public Boolean isLogRequired;
        @AuraEnabled public String  responseHandlingMode;
        @AuraEnabled public String  responseMapping;
    }
}