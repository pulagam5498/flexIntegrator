global inherited sharing class FIR_ResponseHandler {
    @AuraEnabled public Boolean success;
    @AuraEnabled public Integer statusCode;
    @AuraEnabled public String responseBody;
    @AuraEnabled public String accessToken;
    @AuraEnabled public String errorMessage;
    @AuraEnabled public Id logRecordId;

    global static FIR_ResponseHandler handle(
        FIR_IntegrationContext ctx,
        Flex_Integrator_Configuration__mdt cfg,
        HttpResponse res
    ) {
        FIR_ResponseHandler result = new FIR_ResponseHandler();
        result.statusCode = res.getStatusCode();
        result.responseBody = res.getBody();
        result.success =
            res.getStatusCode() >= 200 &&
            res.getStatusCode() < 300;
        if (result.success) {
                try {
                    Map<String, Object> payload =
                        (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    result.accessToken = (String) payload.get('access_token');
                    result.errorMessage = result.accessToken != null
                        ? 'Connection successful. Access token received.'
                        : 'Connection successful. Token not found.';
                } catch (Exception e) {
                    result.errorMessage = 'Connection successful. Response is not JSON.';
                }
            } else {
                result.errorMessage =
                    'Connection failed: ' + res.getStatus() +
                    ' (' + result.statusCode + ')';
            }
        return result;
    }
}