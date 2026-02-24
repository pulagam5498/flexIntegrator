global class FIR_IntegrationContext {
    public String operationDeveloperName;   // CMDT DeveloperName
    public Map<String, Object> inputParameters;
    public Id recordId;
    public Boolean synchronous = true;
    public String correlationId;

    public FIR_IntegrationContext() {
        inputParameters = new Map<String, Object>();
        correlationId = String.valueOf(Datetime.now().getTime());
    }
}