/**
 * @name FIR_CONSTANTSTest
 * @author Masthan Andela
 * @date 2026-02-18
 * @description Unit tests for FIR_CONSTANTS global constants. Verifies values and basic invariants.
 *              
 */
@IsTest
private class FIR_CONSTANTSTest {

    @IsTest
    static void testBooleanConstants() {
       Assert.areEqual(true, FIR_CONSTANTS.BOOLEAN_TRUE, 'BOOLEAN_TRUE should be true');
       Assert.areEqual(false, FIR_CONSTANTS.BOOLEAN_FALSE, 'BOOLEAN_FALSE should be false');
       Assert.areNotEqual(FIR_CONSTANTS.BOOLEAN_TRUE, FIR_CONSTANTS.BOOLEAN_FALSE, 'TRUE and FALSE must differ');
    }

    @IsTest
    static void testStatusAndStrings() {
       Assert.areEqual('Success', FIR_CONSTANTS.STRING_SUCCESS, 'STRING_SUCCESS mismatch');
       Assert.areEqual('Error', FIR_CONSTANTS.STRING_ERROR, 'STRING_ERROR mismatch');
       Assert.areEqual('LWC', FIR_CONSTANTS.TRIGGER_SOURCE_LWC, 'TRIGGER_SOURCE_LWC mismatch');
    }

    @IsTest
    static void testStatusCodeRange() {
       Assert.areEqual(200, FIR_CONSTANTS.STATUS_OK_MIN, 'STATUS_OK_MIN should be 200');
       Assert.areEqual(300, FIR_CONSTANTS.STATUS_OK_MAX, 'STATUS_OK_MAX should be 300');
       Assert.isTrue(FIR_CONSTANTS.STATUS_OK_MIN < FIR_CONSTANTS.STATUS_OK_MAX, 'Min should be less than Max');
    }

    @IsTest
    static void testHeadersAndContentTypes() {
       Assert.areEqual('Content-Type', FIR_CONSTANTS.HEADER_CONTENT_TYPE, 'Header name mismatch');
       Assert.areEqual('application/x-www-form-urlencoded', FIR_CONSTANTS.CT_FORM_URLENCODED, 'Content type mismatch');
       Assert.areEqual('Authorization', FIR_CONSTANTS.HEADER_AUTHORIZATION, 'AUTH header mismatch');
       Assert.areEqual('Bearer ', FIR_CONSTANTS.AUTH_SCHEME_BEARER, 'Bearer scheme mismatch');
    }

    @IsTest
    static void testCalloutAndMethods() {
       Assert.areEqual('callout:', FIR_CONSTANTS.CALLOUT_PREFIX, 'Callout prefix mismatch');
       Assert.areEqual('POST', FIR_CONSTANTS.HTTP_METHOD_POST, 'HTTP method POST mismatch');
       Assert.areEqual(20000, FIR_CONSTANTS.DEFAULT_TIMEOUT, 'Default timeout mismatch');
    }

    @IsTest
    static void testOperationKeysAndJwtModes() {
       Assert.areEqual('FIR_API_CALL', FIR_CONSTANTS.OP_KEY_API_CALL, 'OP_KEY_API_CALL mismatch');
       Assert.areEqual('FIR_JWT_TOKEN', FIR_CONSTANTS.OP_KEY_JWT_TOKEN, 'OP_KEY_JWT_TOKEN mismatch');

       Assert.areEqual('No JWT', FIR_CONSTANTS.JWT_MODE_NONE, 'JWT_MODE_NONE mismatch');
       Assert.areEqual('Same Endpoint', FIR_CONSTANTS.JWT_MODE_SAME, 'JWT_MODE_SAME mismatch');
       Assert.areEqual('Different Endpoint', FIR_CONSTANTS.JWT_MODE_DIFFERENT, 'JWT_MODE_DIFFERENT mismatch');
    }

    @IsTest
    static void testErrorAndMessageStrings() {
       Assert.areEqual('Integration config not found or inactive: ', FIR_CONSTANTS.ERR_CONFIG_NOT_FOUND_INACTIVE);
       Assert.areEqual('JWT access token could not be obtained for Service Name :', FIR_CONSTANTS.ERR_TOKEN_NOT_OBTAINED);
       Assert.areEqual('DeveloperName is required', FIR_CONSTANTS.ERR_DEV_NAME_REQUIRED);
       Assert.areEqual('Integration config is required', FIR_CONSTANTS.ERR_CONFIG_REQUIRED);
       Assert.areEqual('Token path (Token_Relative_Path__c) is required when JWT is enabled.', FIR_CONSTANTS.ERR_TOKEN_PATH_REQUIRED);
       Assert.areEqual('Token endpoint call failed: ', FIR_CONSTANTS.ERR_TOKEN_ENDPOINT_FAILED);
       Assert.areEqual('Token callout failed: ', FIR_CONSTANTS.ERR_TOKEN_CALLOUT_FAILED);
       Assert.areEqual('no response', FIR_CONSTANTS.NO_RESPONSE);
       Assert.areEqual('Unable to parse token response: ', FIR_CONSTANTS.ERR_PARSE_TOKEN);
       Assert.areEqual('Access token not found in token response using key: ', FIR_CONSTANTS.ERR_ACCESS_TOKEN_NOT_FOUND);
       Assert.areEqual('Token Path and Token Body are required.', FIR_CONSTANTS.ERR_TOKEN_PATH_BODY_REQUIRED);
       Assert.areEqual('Connection successful. Access token received.', FIR_CONSTANTS.MSG_CONN_SUCCESS_TOKEN);
       Assert.areEqual('Connection successful. Token not found.', FIR_CONSTANTS.MSG_CONN_SUCCESS_TOKEN_NOT_FOUND);
       Assert.areEqual('Connection successful. Response is not JSON.', FIR_CONSTANTS.MSG_CONN_SUCCESS_NOT_JSON);
       Assert.areEqual('Connection failed: ', FIR_CONSTANTS.MSG_CONN_FAILED);
       Assert.areEqual('Callout error: ', FIR_CONSTANTS.MSG_CALLOUT_ERROR);
       Assert.areEqual('No supported JWT mode enabled in metadata config: ', FIR_CONSTANTS.ERR_UNSUPPORTED_JWT_MODE);

        // Duplicated/general error literals section
       Assert.areEqual('DeveloperName is required', FIR_CONSTANTS.ERROR_DEVELOPERNAME);
       Assert.areEqual('Integration configuration is missing.', FIR_CONSTANTS.ERR_INTEGRATION_CONFIG_MISSING);
       Assert.areEqual('Token_Body__c is required.', FIR_CONSTANTS.ERR_TOKEN_BODY_REQUIRED_WITH_NAME);
       Assert.areEqual('Named Credential is required.', FIR_CONSTANTS.ERR_NAMED_CREDENTIAL_REQUIRED);
       Assert.areEqual('Token body is required.', FIR_CONSTANTS.ERR_TOKEN_BODY_REQUIRED);
       Assert.areEqual('Empty token response.', FIR_CONSTANTS.ERR_EMPTY_TOKEN_RESPONSE);
       Assert.areEqual('Access token not found in response.', FIR_CONSTANTS.ERR_ACCESS_TOKEN_NOT_FOUND_GENERIC);
    }

    @IsTest
    static void testMetadataNamesAndQuery() {
       Assert.areEqual('Flex_Integrator_Configuration__mdt', FIR_CONSTANTS.FIR_METADATA, 'Metadata object API mismatch');

        // Basic invariants on the SOQL text so refactors get caught
       Assert.isTrue(FIR_CONSTANTS.METADATA_QUERY.startsWith('SELECT '), 'Query should start with SELECT');
       Assert.isTrue(FIR_CONSTANTS.METADATA_QUERY.contains(' FROM Flex_Integrator_Configuration__mdt'), 'Query should target the metadata object');
        // Ensure a few key fields are present
       Assert.isTrue(FIR_CONSTANTS.METADATA_QUERY.contains('DeveloperName'), 'DeveloperName should be selected');
       Assert.isTrue(FIR_CONSTANTS.METADATA_QUERY.contains('MasterLabel'), 'MasterLabel should be selected');
       Assert.isTrue(FIR_CONSTANTS.METADATA_QUERY.contains('Is_Active__c'), 'Is_Active__c should be selected');
    }

    @IsTest
    static void testFieldApiNames() {
       Assert.areEqual('DeveloperName', FIR_CONSTANTS.FIELD_DEVELOPER_NAME);
       Assert.areEqual('Is_Active__c', FIR_CONSTANTS.FIELD_IS_ACTIVE);
       Assert.areEqual('Named_Credential_API_Name__c', FIR_CONSTANTS.FIELD_NAMED_CREDENTIAL);
       Assert.areEqual('Relative_Path__c', FIR_CONSTANTS.FIELD_RELATIVE_PATH);
       Assert.areEqual('Request_Body_Template__c', FIR_CONSTANTS.FIELD_REQUEST_BODY);
       Assert.areEqual('Request_Content_Type__c', FIR_CONSTANTS.FIELD_REQUEST_CONTENT_TYPE);
       Assert.areEqual('Custom_Headers_JSON__c', FIR_CONSTANTS.FIELD_CUSTOM_HEADERS_JSON);
       Assert.areEqual('Http_Method__c', FIR_CONSTANTS.FIELD_HTTP_METHOD);
       Assert.areEqual('Default_Timeout_ms__c', FIR_CONSTANTS.FIELD_DEFAULT_TIMEOUT);
       Assert.areEqual('JWT_Required__c', FIR_CONSTANTS.FIELD_JWT_REQUIRED);
       Assert.areEqual('JWT_Mode__c', FIR_CONSTANTS.FIELD_JWT_MODE);
       Assert.areEqual('Token_Path__c', FIR_CONSTANTS.FIELD_TOKEN_PATH);
       Assert.areEqual('Token_Body__c', FIR_CONSTANTS.FIELD_TOKEN_BODY);
       Assert.areEqual('Token_Named_Credential__c', FIR_CONSTANTS.FIELD_TOKEN_NAMED_CREDENTIAL);
       Assert.areEqual('MasterLabel', FIR_CONSTANTS.FIELD_MASTER_LABEL);
       Assert.areEqual('Is_Async__c', FIR_CONSTANTS.FIELD_IS_ASYNC);
       Assert.areEqual('Is_Log_Required__c', FIR_CONSTANTS.FIELD_IS_LOG_REQUIRED);
       Assert.areEqual('Max_Retries__c', FIR_CONSTANTS.FIELD_MAX_RETRIES);
       Assert.areEqual('Response_Handling_Mode__c', FIR_CONSTANTS.FIELD_RESPONSE_HANDLING_MODE);
       Assert.areEqual('Response_Mapping__c', FIR_CONSTANTS.FIELD_RESPONSE_MAPPING);
       Assert.areEqual('Service_Name__c', FIR_CONSTANTS.FIELD_SERVICE_NAME);
    }

    @IsTest
    static void testAccessTokenKey() {
       Assert.areEqual('access_token', FIR_CONSTANTS.ACCESS_TOKEN_KEY, 'ACCESS_TOKEN_KEY mismatch');
    }
}