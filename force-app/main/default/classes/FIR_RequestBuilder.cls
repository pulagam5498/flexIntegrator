global inherited sharing class FIR_RequestBuilder {

    global static HttpRequest buildRequest(FIR_IntegrationContext ctx, Flex_Integrator_Configuration__mdt op) {
        HttpRequest req = new HttpRequest();
        String endpoint = 'callout:' +
            op.Named_Credential_API_Name__c +
            op.Relative_Path__c;
        req.setEndpoint(endpoint);
        req.setMethod(op.Http_Method__c);      
        if (String.isNotBlank(op.Request_Content_Type__c)) {
            req.setHeader('Content-Type', op.Request_Content_Type__c);
        }      
        if (String.isNotBlank(op.Custom_Headers_JSON__c)) {
            Map<String, Object> headers =
                (Map<String, Object>) JSON.deserializeUntyped(
                    op.Custom_Headers_JSON__c
                );
            for (String key : headers.keySet()) {
                req.setHeader(key, String.valueOf(headers.get(key)));
            }
        }      
        if (String.isNotBlank(op.Request_Body_Template__c)
            && op.Http_Method__c != 'GET') {

            req.setBody(op.Request_Body_Template__c);
        }      
        if (op.Default_Timeout_ms__c != null) {
            req.setTimeout(Integer.valueOf(op.Default_Timeout_ms__c));
        }

        return req;
    }
    
    
    
    /**
 * Helper method to prepare an HttpRequest
 * @param method HTTP method (GET, POST, PUT, PATCH, DELETE)
 * @param endpoint Full endpoint URL
 * @param headers JSON string representing headers
 * @param body Request body (optional)
 * @return HttpRequest ready to send
 */
public static HttpRequest prepareHttpRequest(String method, String endpoint, String headers, String body) {
    // Validate HTTP method
    Set<String> allowedMethods = new Set<String>{'GET','POST','PUT','PATCH','DELETE'};
    if (!allowedMethods.contains(method)) {
        throw new AuraHandledException('Unsupported HTTP method: ' + method);
    }

    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod(method);
    req.setTimeout(60000); // 60 seconds

    System.debug('ENDPOINT => ' + endpoint);
    System.debug('METHOD   => ' + method);

    // Set headers if provided
    if (!String.isBlank(headers)) {
        Map<String, String> headerMap = (Map<String, String>) JSON.deserialize(headers, Map<String,String>.class);
        for (String key : headerMap.keySet()) {
            String value = headerMap.get(key);
            req.setHeader(key, value);
            if (key.equalsIgnoreCase('Authorization')) {
                System.debug('HEADER => Authorization: [MASKED]');
            } else {
                System.debug('HEADER => ' + key + ': ' + value);
            }
        }
    }

    // Set body only for methods that support it
    if (!String.isBlank(body) && (method == 'POST' || method == 'PUT' || method == 'PATCH')) {
        req.setBody(body);
        System.debug('BODY => ' + body);
    }

    return req;
}
    
      public static HttpRequest buildTokenRequest(String namedCred, String tokenPath, String tokenBody) {

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setTimeout(FIR_CONSTANTS.DEFAULT_TIMEOUT);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');


        if (!String.isBlank(namedCred)) {
            req.setEndpoint('callout:' + namedCred + tokenPath);
        } else {
            req.setEndpoint(tokenPath);
        }

        req.setBody(buildFormBody(tokenBody));
        return req;
    }
       /**
     * Converts a user-provided string into a proper x-www-form-urlencoded body.
     * Supports either:
     *  - Multiline: key=value per line
     *  - Already &-joined form
     */
    public static String buildFormBody(String raw) {
        String s = raw == null ? '' : raw.trim();
        if (String.isBlank(s)) return '';

        if (s.contains('&') && s.contains('=')) {
            return s;
        }

        List<String> lines = s.split('\\r?\\n');
        List<String> pairs = new List<String>();

        for (String line : lines) {
            if (String.isBlank(line)) continue;
            List<String> kv = line.split('=', 2);
            if (kv.size() == 2) {
                pairs.add(
                    EncodingUtil.urlEncode(kv[0], 'UTF-8') + '=' +
                    EncodingUtil.urlEncode(kv[1], 'UTF-8')
                );
            }
        }
        return String.join(pairs, '&');
    }
 
}