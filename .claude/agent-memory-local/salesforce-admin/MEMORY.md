# Salesforce Admin Agent Memory

## Files
- See [field-patterns.md](field-patterns.md) for field types, metadata structure, picklist XML, and deployment checklist.

## Key Project Conventions
- API version: 65.0 for all metadata files
- Package directory: `force-app/main/default`
- Custom field suffix: `__c`

## Account Object — Custom Fields Created
| Field API Name              | Type     | Notes                              |
|-----------------------------|----------|------------------------------------|
| `Health_Rating__c`          | Picklist | Values: Good, Average, At Risk     |
| `Health_Evaluated_Date__c`  | DateTime | Stamped by AccountTriggerHandler   |

## Permission Sets
- `AccountHealth_Fields` — grants FLS read/write on `Health_Rating__c` and `Health_Evaluated_Date__c`

## CRITICAL: FLS + Permission Sets
- Whenever you create custom fields, ALWAYS create an accompanying permission set that grants FLS (read + edit) on those fields.
- The permission set must be deployed alongside the fields — not as an afterthought.
- Reason: Test classes using `WITH USER_MODE` SOQL enforce FLS. If the running user lacks field access, queries fail with "No such column" even though the field exists in the org.
- The devops agent must also **assign** the permission set to the running user after deployment.

## Lead Object — Custom Fields Created
| Field API Name              | Type     | Notes                               |
|-----------------------------|----------|-------------------------------------|
| `Last_Contacted_Date__c`    | Date     | Set by LeadTriggerHandler           |
| `Days_Since_Last_Contact__c`| Formula  | Calculates days from last contact   |
| `Is_Overdue__c`             | Checkbox | True if overdue follow-up needed    |
| `Primary__c`                | Checkbox | Marks primary lead                  |
| `ProductInterest__c`        | Text     | Product interest field              |

## Permission Sets
- `LeadMgmt_Lead_FollowUp_Fields` — grants FLS on Lead follow-up custom fields
