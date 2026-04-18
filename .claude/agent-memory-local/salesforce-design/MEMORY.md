# Salesforce Design Agent Memory

## Project Conventions (Confirmed)

- API version: 65.0 (from sfdx-project.json)
- Package directory: force-app/main/default
- Trigger pattern: One trigger per object, handler class with recursion guard (static Boolean hasRun)
- Reference implementation: AccountTrigger + AccountTriggerHandler
- No existing LeadTrigger - first Lead trigger will be new
- Handler methods: beforeInsert(List), beforeUpdate(List, Map<Id,SObject>), afterInsert(List, Map), afterUpdate(List, Map, Map)
- Apex: with sharing, Database methods, WITH USER_MODE, AuraHandledException for LWC
- Existing Lead custom fields: Primary**c, CurrentGenerators**c, SICCode**c, NumberofLocations**c, ProductInterest\_\_c

## Agentforce Agent Bundle Conventions (Confirmed)

- Agent bundles go under: force-app/main/default/aiAuthoringBundles/{AgentName}/
- Two files per bundle: {AgentName}.agent + {AgentName}.bundle-meta.xml
- Meta XML uses <AiAuthoringBundle> with <bundleType>AGENT</bundleType> and <target>{AgentName}.v6</target>
- Agent script syntax: system/config/variables/knowledge/start_agent/topic blocks
- Actions defined inside topic blocks with target/inputs/outputs/label
- Reference: Soft_Drink_Agent_Test agent in aiAuthoringBundles/
- Apex actions referenced as apex://ClassName, Flow actions as flow://FlowApiName

## Classification Notes

- Agentforce Agent Bundles (.agent + .bundle-meta.xml) = DEVELOPMENT work (not admin)
- Registering Agent Actions in Setup UI = ADMIN work (but only if explicitly requested)
- See [classification-notes.md](classification-notes.md) for more edge cases
