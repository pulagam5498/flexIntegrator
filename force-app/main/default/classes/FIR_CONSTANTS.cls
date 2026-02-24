/*
*   @Name : FIR_CONSTANTS
*   @Author : KP
*   @Created Date : 01/18/2026
*   @Description : This class used to Store all the Constant Values
--------------------------------------------------------------------------------*/


global class FIR_CONSTANTS {
    
    
    //Boolean Values
    global static final boolean BOOLEAN_TRUE = TRUE;
    global static final boolean BOOLEAN_FALSE = FALSE;
    
    //Status Values    
    global static final string STRING_SUCCESS = 'Success';
    global static final string STRING_ERROR = 'Error';
    global static final String TRIGGER_SOURCE_LWC = 'LWC';
    
    // HTTP status code ranges
    global static final Integer STATUS_OK_MIN = 200;
    global static final Integer STATUS_OK_MAX = 300;
    
    // Common headers and content types
    global static final String HEADER_CONTENT_TYPE = 'Content-Type';
    global static final String CT_FORM_URLENCODED = 'application/x-www-form-urlencoded';
    
    // Callout
    global static final String CALLOUT_PREFIX = 'callout:';
    global static final String HTTP_METHOD_POST = 'POST';
    
    // Operation keys
    global static final String OP_KEY_API_CALL = 'FIR_API_CALL';
    global static final String OP_KEY_JWT_TOKEN = 'FIR_JWT_TOKEN';
    
    // JWT modes
    global static final String JWT_MODE_NONE = 'No JWT';
    global static final String JWT_MODE_SAME = 'Same Endpoint';
    global static final String JWT_MODE_DIFFERENT = 'Different Endpoint';
    
    // Error and message strings
    global static final String ERR_CONFIG_NOT_FOUND_INACTIVE = 'Integration config not found or inactive: ';
    global static final String ERR_TOKEN_NOT_OBTAINED = 'JWT access token could not be obtained for Service Name :';
    global static final String ERR_DEV_NAME_REQUIRED = 'DeveloperName is required';
    global static final String ERR_CONFIG_REQUIRED = 'Integration config is required';
    global static final String ERR_TOKEN_PATH_REQUIRED = 'Token path (Token_Relative_Path__c) is required when JWT is enabled.';
    global static final String ERR_TOKEN_ENDPOINT_FAILED = 'Token endpoint call failed: ';
    global static final String ERR_TOKEN_CALLOUT_FAILED = 'Token callout failed: ';
    global static final String NO_RESPONSE = 'no response';
    global static final String ERR_PARSE_TOKEN = 'Unable to parse token response: ';
    global static final String ERR_ACCESS_TOKEN_NOT_FOUND = 'Access token not found in token response using key: ';
    global static final String ERR_TOKEN_PATH_BODY_REQUIRED = 'Token Path and Token Body are required.';
    global static final String MSG_CONN_SUCCESS_TOKEN = 'Connection successful. Access token received.';
    global static final String MSG_CONN_SUCCESS_TOKEN_NOT_FOUND = 'Connection successful. Token not found.';
    global static final String MSG_CONN_SUCCESS_NOT_JSON = 'Connection successful. Response is not JSON.';
    global static final String MSG_CONN_FAILED = 'Connection failed: ';
    global static final String MSG_CALLOUT_ERROR = 'Callout error: ';
    global static final String ERR_UNSUPPORTED_JWT_MODE = 'No supported JWT mode enabled in metadata config: ';
    
    //Object Names    
    global static final string FIR_METADATA = 'Flex_Integrator_Configuration__mdt';
    
     global static final String METADATA_QUERY =
            'SELECT Id, DeveloperName, MasterLabel, Is_Active__c, ' +
            'Custom_Headers_JSON__c, Default_Timeout_ms__c, Http_Method__c, ' +
            'Is_Async__c, Is_Log_Required__c, Max_Retries__c, ' +
            'Named_Credential_API_Name__c, Relative_Path__c, ' +
            'Request_Body_Template__c, Request_Content_Type__c, ' +
            'Response_Handling_Mode__c, Response_Mapping__c, Service_Name__c, ' +
            'JWT_Required__c, Token_Path__c, Token_Body__c, JWT_Mode__c, Token_Named_Credential__c  FROM Flex_Integrator_Configuration__mdt';
    
    //Field/API names (metadata fields and headers)
    global static final String FIELD_DEVELOPER_NAME = 'DeveloperName';
    global static final String FIELD_IS_ACTIVE = 'Is_Active__c';
    global static final String FIELD_NAMED_CREDENTIAL = 'Named_Credential_API_Name__c';
    global static final String FIELD_RELATIVE_PATH = 'Relative_Path__c';
    global static final String FIELD_REQUEST_BODY = 'Request_Body_Template__c';
    global static final String FIELD_REQUEST_CONTENT_TYPE = 'Request_Content_Type__c';
    global static final String FIELD_CUSTOM_HEADERS_JSON = 'Custom_Headers_JSON__c';
    global static final String FIELD_HTTP_METHOD = 'Http_Method__c';
    global static final String FIELD_DEFAULT_TIMEOUT = 'Default_Timeout_ms__c';
    global static final String FIELD_JWT_REQUIRED = 'JWT_Required__c';
    global static final String FIELD_JWT_MODE = 'JWT_Mode__c';
    global static final String FIELD_TOKEN_PATH = 'Token_Path__c';
    global static final String FIELD_TOKEN_BODY = 'Token_Body__c';
    global static final String FIELD_TOKEN_NAMED_CREDENTIAL = 'Token_Named_Credential__c';
    global static final String FIELD_MASTER_LABEL = 'MasterLabel';
    global static final String FIELD_IS_ASYNC = 'Is_Async__c';
    global static final String FIELD_IS_LOG_REQUIRED = 'Is_Log_Required__c';
    global static final String FIELD_MAX_RETRIES = 'Max_Retries__c';
    global static final String FIELD_RESPONSE_HANDLING_MODE = 'Response_Handling_Mode__c';
    global static final String FIELD_RESPONSE_MAPPING = 'Response_Mapping__c';
    global static final String FIELD_SERVICE_NAME = 'Service_Name__c';

    // Common literal keys
    global static final String HEADER_AUTHORIZATION = 'Authorization';
    global static final String AUTH_SCHEME_BEARER = 'Bearer ';
    
    
    //WHERE Conditions
    
    //Error Messages
    global static final string ERROR_DEVELOPERNAME = 'DeveloperName is required';
    global static final String ERR_INTEGRATION_CONFIG_MISSING = 'Integration configuration is missing.';
    global static final String ERR_TOKEN_BODY_REQUIRED_WITH_NAME = 'Token_Body__c is required.';
    global static final String ERR_NAMED_CREDENTIAL_REQUIRED = 'Named Credential is required.';
    global static final String ERR_TOKEN_BODY_REQUIRED = 'Token body is required.';
    global static final String ERR_EMPTY_TOKEN_RESPONSE = 'Empty token response.';
    global static final String ERR_ACCESS_TOKEN_NOT_FOUND_GENERIC = 'Access token not found in response.';
    
	//Callout Related
    global static final Integer DEFAULT_TIMEOUT = 20000;
    global static final String ACCESS_TOKEN_KEY = 'access_token';
}