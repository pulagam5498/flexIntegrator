/**
* @File Name : NamedCredentialService.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 17, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 17, 2025 |   | Initial Version
**/


// NamedCredentialService.cls

public with sharing class FIR_NamedCredentialService {
    public class NamedCredentialDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String label;    // MasterLabel
        @AuraEnabled public String apiName;  // DeveloperName
        public NamedCredentialDTO(String id, String label, String apiName) {
            this.id = id; this.label = label; this.apiName = apiName;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<NamedCredentialDTO> getNamedCredentials() {
        // If your org supports direct SOQL on NamedCredential:
        List<NamedCredentialDTO> result = new List<NamedCredentialDTO>();
        for (NamedCredential nc : [
            SELECT Id, DeveloperName, MasterLabel
            FROM NamedCredential
            ORDER BY MasterLabel
        ]) {
            result.add(new NamedCredentialDTO(nc.Id, nc.MasterLabel, nc.DeveloperName));
               }
        return result;
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Option> getPicklistValues(String objectApiName,String fieldApiName) {
        Schema.DescribeFieldResult schemaDescribeFieldResult =Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().get(fieldApiName).getDescribe();

        List<Option> lOptions = new List<Option>();
        for (Schema.PicklistEntry schemaPicklistEntry : schemaDescribeFieldResult.getPicklistValues()) {
            if (schemaPicklistEntry.isActive()) {
                lOptions.add(new Option(schemaPicklistEntry.getLabel(), schemaPicklistEntry.getValue()));
            }
        }
        return lOptions;
    }
}