/**
 * Apex Class: FIR_IntegrationService
 * Main integration service class for Flex Integrator framework.
 *
 * - performCallout(): Execute HTTP callouts using metadata-driven configuration
 *
 * Features:
 *  - JWT token acquisition when Is_JWT_Required__c is enabled
 *  - Dynamic field mapping for metadata operations
 *  - Safe HTTP request building with JSON header parsing and placeholder expansion
 *  - Integration with LogService for callout logging
 *
 * Security:
 *  - All operations run in system context
 *  - Input validation for required fields
 *  - Safe JSON parsing with error handling
 *  - Named Credential support for secure endpoints
 *
 * Created By: Masthan
 * Last Updated: 
 */
global inherited sharing class FIR_IntegrationService {

    
 /**
 * Retrieves Flex_Integrator_Configuration__mdt records based on optional filters.
 *
 * Behavior:
 * - If developerName is null or blank, all configuration records are returned.
 * - If retrieveActiveOnly is true, only active configurations (Is_Active__c = true) are returned.
 * - If developerName is provided, only the matching DeveloperName record is returned.
 * - Filters can be combined (DeveloperName + Active only).
 *
 * Notes:
 * - Results are ordered by DeveloperName.
 **/
    global static List<Flex_Integrator_Configuration__mdt> getConfigsByName(String developerName,Boolean retrieveActiveOnly) {

        
        List<String> whereClauses = new List<String>();
        
        if (!String.isBlank(developerName)) {
            whereClauses.add(
                FIR_CONSTANTS.FIELD_DEVELOPER_NAME + ' = :developerName'
            );
        }
        
        if (retrieveActiveOnly == true) {
            whereClauses.add(
                FIR_CONSTANTS.FIELD_IS_ACTIVE + ' = true'
            );
        }
        
          String queryString = FIR_CONSTANTS.METADATA_QUERY;  
        
        if (!whereClauses.isEmpty()) {
            queryString += ' WHERE ' + String.join(whereClauses, ' AND ');
        }
        
        queryString += ' ORDER BY ' + FIR_CONSTANTS.FIELD_DEVELOPER_NAME;
        
        return (List<Flex_Integrator_Configuration__mdt>) Database.query(queryString);
    }

    
    @AuraEnabled
    global static FIR_ResponseHandler makeRequest(String method, String endpoint, String headers, String body) {        
          FIR_ResponseHandler returnResult = new FIR_ResponseHandler();
        Integration_Call_Log__c logEntry = prepareLogEntry(endpoint, method, body, FIR_CONSTANTS.OP_KEY_API_CALL);
        HttpResponse res;

        try {
          HttpRequest req = FIR_RequestBuilder.prepareHttpRequest(method, endpoint, headers, body);
            Http http = new Http();
            res = http.send(req);

            returnResult.statusCode = res.getStatusCode();
            returnResult.responseBody = res.getBody();
            returnResult.success = (returnResult.statusCode >= FIR_CONSTANTS.STATUS_OK_MIN && returnResult.statusCode < FIR_CONSTANTS.STATUS_OK_MAX);          

            logEntry.Response_Body__c = returnResult.responseBody;
            logEntry.HTTP_Status_Code__c = returnResult.statusCode;
            logEntry.Status__c = returnResult.success ? FIR_CONSTANTS.STRING_SUCCESS : FIR_CONSTANTS.STRING_ERROR ;

        } catch (Exception e) {
            returnResult.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            returnResult.errorMessage = e.getMessage();
            logEntry.Error_Message__c = returnResult.errorMessage;
            logEntry.Status__c = FIR_CONSTANTS.STRING_ERROR;
        } finally {
            try {
                insert logEntry;
            } catch (Exception ex) {
                // Log failed, avoid breaking main call
                System.debug('Failed to insert call log: ' + ex.getMessage());
            }
        }
        return returnResult;
    }

    global static FIR_ResponseHandler performCallout(FIR_IntegrationContext ctx) {

        FIR_ResponseHandler returnResult = new FIR_ResponseHandler();
        HttpRequest req;
        HttpResponse res;          
        Flex_Integrator_Configuration__mdt config = new Flex_Integrator_Configuration__mdt();

        try {
           
            List<Flex_Integrator_Configuration__mdt> opList = getConfigsByName( ctx.operationDeveloperName, false);     
            if(!opList.isEmpty()){
                config = opList[0];
            }            
            if (opList == null || opList.isEmpty() || !config.Is_Active__c) {
                returnResult.success = FIR_CONSTANTS.BOOLEAN_FALSE;
                returnResult.errorMessage = FIR_CONSTANTS.ERR_CONFIG_NOT_FOUND_INACTIVE + ctx.operationDeveloperName;
                return returnResult;
            }
            req = FIR_RequestBuilder.buildRequest(ctx, config);
            
            // If JWT is required, fetch access token using token path/body from metadata and attach to main request
            if ((String)config.get(FIR_CONSTANTS.FIELD_JWT_MODE) != FIR_CONSTANTS.JWT_MODE_NONE) {
              
                FIR_ResponseHandler accessTokenResponse = acquireJwtAccessToken(config);
                String accessToken =  extractAccessToken(accessTokenResponse.responseBody);
                if (String.isBlank(accessToken)) {
                    returnResult.success = FIR_CONSTANTS.BOOLEAN_FALSE;
                    returnResult.errorMessage = FIR_CONSTANTS.ERR_TOKEN_NOT_OBTAINED + ctx.operationDeveloperName;
                    return returnResult;                    
                }
                // Default: add as Bearer token unless specific header format is stored in metadata
                req.setHeader(FIR_CONSTANTS.HEADER_AUTHORIZATION,
                              FIR_CONSTANTS.AUTH_SCHEME_BEARER + accessToken);
            }
            
           
            Http http = new Http();
            res = http.send(req);
            returnResult.statusCode = res.getStatusCode();
            returnResult.responseBody = res.getBody();
            returnResult.success = (returnResult.statusCode >= FIR_CONSTANTS.STATUS_OK_MIN && returnResult.statusCode < FIR_CONSTANTS.STATUS_OK_MAX);

        } catch (Exception e) {
            returnResult.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            returnResult.errorMessage = e.getMessage();
        } finally {
                logCall(ctx, req, res, returnResult);
        }

        return returnResult;
    }


    /**
     * Perform HTTP callout using a Flex_Integrator_Configuration__mdt by DeveloperName.
     * Loads the CMD using getInstance and delegates to performCallout(Flex_Integrator_Configuration__mdt).
     *
     * @param developerName DeveloperName of the Flex_Integrator_Configuration__mdt record
     * @return FIR_ResponseHandler containing status, body, success flag, and log id
     */
    global static FIR_ResponseHandler performCallout(String developerName) {
        
        FIR_ResponseHandler returnResult = new FIR_ResponseHandler();
        if (String.isBlank(developerName)) {
            returnResult.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            returnResult.errorMessage = FIR_CONSTANTS.ERR_DEV_NAME_REQUIRED;
        }else{
            // Build a FIR_IntegrationContext 
            FIR_IntegrationContext ctx = new FIR_IntegrationContext();        
            ctx.operationDeveloperName = developerName;        
            returnResult = performCallout(ctx);  
        }
        
        return returnResult;
    }

    
    /**
     * Perform HTTP callout using parameters from a Flex_Integrator_Configuration__mdt record.
     * Builds HttpRequest using FIR_RequestBuilder and sends it synchronously.
     *
     * @param config Flex_Integrator_Configuration__mdt record with callout settings
     * @return FIR_ResponseHandler containing status, body, success flag, and log id
     */
    global static FIR_ResponseHandler performCallout(Flex_Integrator_Configuration__mdt config) {
        FIR_ResponseHandler returnResult = new FIR_ResponseHandler();
        
        if (config == null) {
            returnResult.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            returnResult.errorMessage = FIR_CONSTANTS.ERR_CONFIG_REQUIRED;            
        }else{            
            FIR_IntegrationContext ctx = new FIR_IntegrationContext();
            ctx.operationDeveloperName = config.DeveloperName;            
            returnResult = performCallout(ctx);  
        }
        return returnResult;
    }

    
    /**
     * Acquire JWT access token using token endpoint info stored in Flex_Integrator_Configuration__mdt.
     * Expected fields on metadata (configure these fields in the CMD type):
     *  - Token_Relative_Path__c (relative path for token endpoint, appended to base/NC host)
     *  - Token_Request_Body__c (body to send to token endpoint)
     *  - Token_Request_Content_Type__c (e.g., application/x-www-form-urlencoded or application/json)
     *  - Token_Response_Access_Token_JSON_Path__c (optional JSON path to extract token, defaults to 'access_token')
     *  - Optional: Named_Credential_API_Name__c used by FIR_RequestBuilder for host/authorization if needed
     */
    global static FIR_ResponseHandler acquireJwtAccessToken(Flex_Integrator_Configuration__mdt config) {
        // Return container for status and raw response
        FIR_ResponseHandler returnResult = new FIR_ResponseHandler();

        // Validation (Return Early)
        if (config == null) {
            returnResult.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            returnResult.errorMessage = FIR_CONSTANTS.ERR_INTEGRATION_CONFIG_MISSING;
            return returnResult;
        }
        if (String.isBlank(config.Token_Body__c)) {
            returnResult.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            returnResult.errorMessage = FIR_CONSTANTS.ERR_TOKEN_BODY_REQUIRED_WITH_NAME + config.DeveloperName;
            return returnResult;
        }
        // Select Named Credential based on JWT_Mode__c
        // - "Same Endpoint": use Named_Credential_API_Name__c
        // - "Different Endpoint": use Token_Named_Credential__c
        String jwtMode = (String) config.get(FIR_CONSTANTS.FIELD_JWT_MODE);
        String namedCred;
        if (jwtMode == FIR_CONSTANTS.JWT_MODE_SAME) {
            namedCred = config.Named_Credential_API_Name__c;
        } else if (jwtMode == FIR_CONSTANTS.JWT_MODE_DIFFERENT) {
            namedCred = (String) config.get(FIR_CONSTANTS.FIELD_TOKEN_NAMED_CREDENTIAL);
        } else {
            // Unsupported/disabled mode: return error per requirement
            returnResult.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            returnResult.errorMessage = FIR_CONSTANTS.ERR_UNSUPPORTED_JWT_MODE + config.DeveloperName;
            return returnResult;
        }

        // Delegate to the generalized token acquisition method
        return acquireJwtAccessTokenByParams(namedCred, config.Token_Path__c, config.Token_Body__c, FIR_CONSTANTS.OP_KEY_JWT_TOKEN);
    }

    /**
     * Generalized token acquisition that accepts explicit parameters.
     * Inputs:
     *  - namedCred: Named Credential API name (without 'callout:')
     *  - tokenPath: Relative or absolute token endpoint path
     *  - tokenBody: Raw token body (will be encoded to application/x-www-form-urlencoded)
     *  - operationKey: Optional log operation key (defaults to FIR_API_CALL if blank)
     */
    global static FIR_ResponseHandler acquireJwtAccessTokenByParams(String namedCred, String tokenPath, String tokenBody, String operationKey) {
        FIR_ResponseHandler result = new FIR_ResponseHandler();

        // Validate inputs
        if (String.isBlank(namedCred)) {
            result.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            result.errorMessage = FIR_CONSTANTS.ERR_NAMED_CREDENTIAL_REQUIRED;
            return result;
        }
        if (String.isBlank(tokenBody)) {
            result.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            result.errorMessage = FIR_CONSTANTS.ERR_TOKEN_BODY_REQUIRED;
            return result;
        }

        // Build request via RequestBuilder to enforce x-www-form-urlencoded
        HttpRequest req = FIR_RequestBuilder.buildTokenRequest(
            namedCred,
            tokenPath,
            tokenBody
        );

        Integration_Call_Log__c logEntry = prepareLogEntry(
            req.getEndpoint(),
            FIR_CONSTANTS.HTTP_METHOD_POST,
            req.getBody(),
            String.isBlank(operationKey) ? FIR_CONSTANTS.OP_KEY_API_CALL : operationKey
        );

        try {
            HttpResponse res = new Http().send(req);
            result.statusCode = res.getStatusCode();
            result.responseBody = res.getBody();
            result.success = (result.statusCode >= FIR_CONSTANTS.STATUS_OK_MIN && result.statusCode < FIR_CONSTANTS.STATUS_OK_MAX);

            logEntry.HTTP_Status_Code__c = result.statusCode;
            logEntry.Response_Body__c = result.responseBody;
            logEntry.Status__c = result.success ? FIR_CONSTANTS.STRING_SUCCESS : FIR_CONSTANTS.STRING_ERROR;
        } catch (Exception e) {
            result.success = FIR_CONSTANTS.BOOLEAN_FALSE;
            result.errorMessage = FIR_CONSTANTS.ERR_TOKEN_CALLOUT_FAILED + e.getMessage();
            logEntry.Status__c = FIR_CONSTANTS.STRING_ERROR;
            logEntry.Error_Message__c = result.errorMessage;
        } finally {
            try {
                insert logEntry;
            } catch (Exception ex) {
                System.debug('Token log insert failed: ' + ex.getMessage());
            }
        }

        return result;
    }
    

    
     private static String extractAccessToken(String responseBody) {

        if (String.isBlank(responseBody)) {
            throw new CalloutException(FIR_CONSTANTS.ERR_EMPTY_TOKEN_RESPONSE);
        }

        try {
            Map<String, Object> payload =
                (Map<String, Object>) JSON.deserializeUntyped(responseBody);

            String token = (String) payload.get(FIR_CONSTANTS.ACCESS_TOKEN_KEY);

            if (String.isBlank(token)) {
                throw new CalloutException(FIR_CONSTANTS.ERR_ACCESS_TOKEN_NOT_FOUND_GENERIC);
            }

            return token;

        } catch (Exception e) {
            throw new CalloutException(FIR_CONSTANTS.ERR_PARSE_TOKEN + e.getMessage());
        }
    }
    
    
    

    //Handle Logs
    global static Id logCall(
        FIR_IntegrationContext ctx,
        HttpRequest req,
        HttpResponse res,
        FIR_ResponseHandler result
    ) {
        Integration_Call_Log__c log = new Integration_Call_Log__c();
        if (ctx != null) {
            log.Operation_Key__c =  ctx.operationDeveloperName;
            log.Correlation_Id__c = ctx.correlationId;
            log.Triggered_By__c = FIR_CONSTANTS.TRIGGER_SOURCE_LWC;
        }
        if (res != null) {
            log.HTTP_Status_Code__c = res.getStatusCode();
            log.Response_Body__c = res.getBody();
        }

        log.Status__c = result.success ? FIR_CONSTANTS.STRING_SUCCESS : FIR_CONSTANTS.STRING_ERROR ;
        log.Error_Message__c = result.errorMessage;

        insert log;
        return log.Id;
    }
    
    
    global static Integration_Call_Log__c prepareLogEntry(String endpoint, String method, String body, String operationKey) {
        Integration_Call_Log__c logEntry = new Integration_Call_Log__c();
        
        logEntry.Request_URL__c = endpoint;
        logEntry.HTTP_Method__c = method;
        logEntry.Request_Body__c = body;
        
        logEntry.Operation_Key__c = String.isBlank(operationKey) ? FIR_CONSTANTS.OP_KEY_API_CALL : operationKey;
        logEntry.Triggered_By__c = UserInfo.getName(); // or UserInfo.getUserId() if you prefer
        logEntry.Correlation_Id__c = String.valueOf(Datetime.now().getTime()); // unique ID
        
        return logEntry;
    }
    
}