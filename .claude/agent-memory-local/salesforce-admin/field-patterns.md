# Field & Metadata Patterns — Confirmed in This Project

## Custom Field Naming
- API names follow `PascalCase__c` (e.g., `Health_Rating__c`, `Last_Contacted_Date__c`)
- Label matches the field name with spaces (no abbreviations)
- `required` is `false` by default unless business logic demands it
- `trackFeedHistory` is `false` unless explicitly requested

## Field Types Used
| Type     | Example Field              | Notes                                              |
|----------|----------------------------|----------------------------------------------------|
| Picklist | `Health_Rating__c`         | Use inline `valueSetDefinition`, not global value sets unless shared |
| DateTime | `Health_Evaluated_Date__c` | Use for system-stamped timestamps                  |
| Date     | `Last_Contacted_Date__c`   | Use for business-logic dates (not system stamps)   |
| Checkbox | `Is_Overdue__c`, `Primary__c` | Default `false`                                 |
| Number   | `Days_Since_Last_Contact__c` | Formula or plain Number                          |
| Text     | `ProductInterest__c`       | Specify length                                     |

## Permission Set Pattern
- One permission set per feature/object grouping (e.g., `AccountHealth_Fields`, `LeadMgmt_Lead_FollowUp_Fields`)
- Always includes both `readable` and `editable` on every custom field in the set
- Deploy alongside the fields — never as a separate later step
- Naming: `ObjectFeature_Fields` format

## Metadata File Structure (API 65.0)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>FieldName__c</fullName>
    <label>Field Label</label>
    <required>false</required>
    <trackFeedHistory>false</trackFeedHistory>
    <type>TypeHere</type>
</CustomField>
```

## Picklist Field Structure
```xml
<type>Picklist</type>
<valueSet>
    <valueSetDefinition>
        <sorted>false</sorted>
        <value>
            <fullName>PicklistValue</fullName>
            <default>false</default>
            <label>Picklist Value</label>
        </value>
    </valueSetDefinition>
</valueSet>
```

## Deployment Checklist for New Fields
1. Create field XML in `force-app/main/default/objects/{Object}/fields/`
2. Create/update permission set XML in `force-app/main/default/permissionsets/`
3. Confirm both are passed to the devops agent together
4. Remind devops agent to **assign** the permission set to the running user post-deploy

## Objects Modified
| Object  | Fields Added                                                                  | Permission Set                  |
|---------|-------------------------------------------------------------------------------|---------------------------------|
| Account | `Health_Rating__c`, `Health_Evaluated_Date__c`                                | `AccountHealth_Fields`          |
| Lead    | `Last_Contacted_Date__c`, `Days_Since_Last_Contact__c`, `Is_Overdue__c`, `Primary__c`, `ProductInterest__c` | `LeadMgmt_Lead_FollowUp_Fields` |
