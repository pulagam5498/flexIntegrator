/**
* @File Name : FIR_IntegratorController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 13, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 13, 2025 |   | Initial Version
**/

public class FIR_IntegratorController {
    private static final String CMD_TYPE = 'Flex_Integrator_Configuration';
    /**
     * Returns all configurations regardless of active status.
     * Admin UI needs to see inactive records to edit/reactivate them.
     */
    @AuraEnabled(cacheable=false)
    public static List<Flex_Integrator_Configuration__mdt> getAllConfigs() {
        try {
            return FIR_IntegrationService.getConfigsByName(null, false);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to load configurations: ' + e.getMessage()
            );
        }
    }
    
    
    
    /**
     * Tests a raw HTTP callout without any metadata config.
     * Used by the "Test Connection" panel when user manually enters an endpoint.
     */
    @AuraEnabled
    public static FIR_ResponseHandler makeRequest(
        String method,
        String endpoint,
        String headers,
        String body
    ) {
        if (String.isBlank(method))   throw new AuraHandledException('HTTP method is required.');
        if (String.isBlank(endpoint)) throw new AuraHandledException('Endpoint is required.');

        try {
            FIR_ResponseHandler response =
                FIR_IntegrationService.makeRequest(method, endpoint, headers, body);
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Request failed: ' + e.getMessage()
            );
        }
    }
    
  


        
   /**
     * Saves or updates a configuration via Metadata API.
     */
    @AuraEnabled
    public static String saveConfig(Flex_Integrator_Configuration__mdt config) {
        if (config == null) {
            throw new AuraHandledException('Configuration is required.');
        }
        try {
            String result = FIR_MetadataService.upsertConfig(config);
            // Surface failure from metadata service instead of masking it
            if (String.isBlank(result) || result.containsIgnoreCase('error')) {
                throw new AuraHandledException(
                    'Metadata save failed: ' + result
                );
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to save configuration: ' + e.getMessage()
            );
        }
    }

 /**
     * Tests only the JWT token acquisition step, independently of the main callout.
     * Used by the "Test Token" button before saving a config.
     *
     * @param configdevName   DeveloperName of the Flex_Integrator_Configuration__mdt
     *                   record (used only to look up the Named Credential and JWT mode)
     * @param tokenPath  Token endpoint path — uses caller value, not stored value
     * @param tokenBody  Token request body — uses caller value, not stored value
     */
    @AuraEnabled(cacheable=false)
    public static FIR_ResponseHandler testJwtConnection(
        String configdevName,
        String tokenPath,
        String tokenBody
    ) {
        // ── Input validation ──────────────────────────────────────────────────
        if (String.isBlank(configdevName)) {
            throw new AuraHandledException('Configuration DeveloperName is required.');
        }
        if (String.isBlank(tokenPath)) {
            throw new AuraHandledException('Token Path is required.');
        }
        if (String.isBlank(tokenBody)) {
            throw new AuraHandledException('Token Body is required.');
        }

        try {
            List<Flex_Integrator_Configuration__mdt> configs =
                FIR_IntegrationService.getConfigsByName(configdevName, false);

            if (configs.isEmpty()) {
                throw new AuraHandledException(
                    'No configuration found with developer name: ' + configdevName
                );
            }

            Flex_Integrator_Configuration__mdt config = configs[0];
            String jwtMode = (String) config.get(FIR_CONSTANTS.FIELD_JWT_MODE);

            String namedCred;
            if (jwtMode == FIR_CONSTANTS.JWT_MODE_SAME) {
                // Token endpoint is on the same host as the main API
                namedCred = config.Named_Credential_API_Name__c;
            } else if (jwtMode == FIR_CONSTANTS.JWT_MODE_DIFFERENT) {
                // Token endpoint is on a different host — use the dedicated token NC
                namedCred = (String) config.get(FIR_CONSTANTS.FIELD_TOKEN_NAMED_CREDENTIAL);
            } else {
                throw new AuraHandledException(
                    'JWT mode on this configuration is "' + jwtMode
                    + '". Must be "Same Endpoint" or "Different Endpoint" to test a token.'
                );
            }

            if (String.isBlank(namedCred)) {
                throw new AuraHandledException(
                    'Named Credential is not set on this configuration for JWT mode "'
                    + jwtMode + '".'
                );
            }

            FIR_ResponseHandler response =
                FIR_IntegrationService.acquireJwtAccessTokenByParams(
                    namedCred,
                    tokenPath,    
                    tokenBody,    
                    FIR_CONSTANTS.OP_KEY_JWT_TOKEN
                );
            
            return response;

        } catch (Exception e) {
            throw new AuraHandledException('JWT test failed: ' + e.getMessage());
        }
    }

    
    /**
     * Tests a full connection using a saved configuration record.
     *
     */
    @AuraEnabled(cacheable=false)
    public static FIR_ResponseHandler testConnection(Flex_Integrator_Configuration__mdt config) {
        if (config == null) {
            throw new AuraHandledException('Configuration is required.');
        }

        try {
            String jwtMode = (String) config.get(FIR_CONSTANTS.FIELD_JWT_MODE);
            Boolean requiresJwt = String.isNotBlank(jwtMode)
                && jwtMode != FIR_CONSTANTS.JWT_MODE_NONE;

            FIR_ResponseHandler response;

            if (requiresJwt) {
                FIR_ResponseHandler tokenResponse =
                    FIR_IntegrationService.acquireJwtAccessToken(config);

                if (!tokenResponse.success) {
                    return tokenResponse;
                }

                response = FIR_IntegrationService.performCallout(config);
            } else {
                // No JWT — direct callout
                response = FIR_IntegrationService.performCallout(config);
            }

            return response;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Connection test failed: ' + e.getMessage()
            );
        }
    } 
    @AuraEnabled
    public static String deleteMdtRecord(String developerName) {
        // 1. Get the 'Full' Session ID from the VF page
		String fullSessionId = getSessionIdFromVF();
        system.debug('fullSessionId '+fullSessionId);
		//String endpoint = 'callout:ToolingAPI/services/Soap/m/60.0';
		String endpoint = URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/60.0';
        
        String soapBody = 
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:met="http://soap.sforce.com/2006/04/metadata">' +
                '<soapenv:Header>' +
                    '<met:SessionHeader><met:sessionId>' + fullSessionId + '</met:sessionId></met:SessionHeader>' +
                '</soapenv:Header>' +
                '<soapenv:Body>' +
                    '<met:deleteMetadata>' +
                        '<met:type>CustomMetadata</met:type>' +
                        '<met:fullNames>'+ CMD_TYPE + '.' + developerName + '</met:fullNames>' +
                    '</met:deleteMetadata>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml');
        req.setHeader('SOAPAction', '""'); 
        req.setBody(soapBody);

        Http http = new Http();
        HttpResponse res = http.send(req);

        // Metadata API returns 200 even for some errors; we must check the XML body
        if (res.getStatusCode() == 200 && res.getBody().contains('<success>true</success>')) {
            return 'Success';
        } else {
            // Parse error or throw the body for debugging
            throw new AuraHandledException('Metadata API Error: ' + res.getBody());
        }
    }

    private static String getSessionIdFromVF() {
        if (Test.isRunningTest()) return 'test_session_id';
        
        // This grabs the content of the VF page we created in Step 1
        PageReference pf = Page.SessionIdPage;
        String content;
        try {
            content = pf.getContent().toString();
        } catch (Exception e) {
            throw new AuraHandledException('Failed to get Session ID: ' + e.getMessage());
        }
        return content.trim();
    }
}