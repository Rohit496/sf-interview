# Salesforce Design Agent Memory

## Project Conventions (Confirmed)
- API version: 65.0 (from sfdx-project.json)
- Package directory: force-app/main/default
- Trigger pattern: One trigger per object, handler class with recursion guard (static Boolean hasRun)
- Reference implementation: AccountTrigger + AccountTriggerHandler
- No existing LeadTrigger - first Lead trigger will be new
- Handler methods: beforeInsert(List), beforeUpdate(List, Map<Id,SObject>), afterInsert(List, Map), afterUpdate(List, Map, Map)
- Apex: with sharing, Database methods, WITH USER_MODE, AuraHandledException for LWC
- Existing Lead custom fields: Primary__c, CurrentGenerators__c, SICCode__c, NumberofLocations__c, ProductInterest__c

## Classification Notes
- See [classification-notes.md](classification-notes.md) for edge cases
