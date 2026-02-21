# Design Requirements: Account Health Indicator

## What User Requested
Account Health Indicator -- two custom fields on Account, a trigger to auto-evaluate health rating when AnnualRevenue or NumberOfEmployees changes (with Task creation on "At Risk"), and an LWC card for the Account record page.

---

## Admin Work (salesforce-admin)

- **Health_Rating__c** field on Account:
  - Type: Picklist
  - Values: Good, Average, At Risk

- **Health_Evaluated_Date__c** field on Account:
  - Type: DateTime

---

## Development Work (salesforce-developer)

- **Modify existing AccountTriggerHandler** to add health rating evaluation logic:
  - Trigger contexts: before insert, before update
  - When AnnualRevenue or NumberOfEmployees changes (or on insert), evaluate:
    - Good: AnnualRevenue > 10,000,000 AND NumberOfEmployees > 500
    - Average: AnnualRevenue between 1,000,000-10,000,000 OR NumberOfEmployees between 100-500
    - At Risk: AnnualRevenue < 1,000,000 AND NumberOfEmployees < 100
  - Set Health_Evaluated_Date__c to Datetime.now()
  - After update: if Health_Rating__c changed to "At Risk", create a Task assigned to OwnerId with due date = today + 3 days

- **LWC component (accountHealthIndicator)**:
  - Displays Health_Rating__c and Health_Evaluated_Date__c
  - Simple card layout on Account Record Page
  - Exposed to Lightning App Builder for record pages

---

## Execution Order

1. **Admin**: Create Health_Rating__c and Health_Evaluated_Date__c fields -- must exist before Apex references them
2. **Developer**: Update AccountTriggerHandler with health evaluation logic and Task creation
3. **Developer**: Create accountHealthIndicator LWC

---

## Prompts for Specialist Agents

### Prompt for salesforce-admin

```
Create the following custom fields on the Account object.
API version: 65.0. Package directory: force-app/main/default.
Do not deploy -- just create metadata files.

1. Health_Rating__c
   - Type: Picklist
   - Picklist values: Good, Average, At Risk
   - Label: Health Rating

2. Health_Evaluated_Date__c
   - Type: DateTime
   - Label: Health Evaluated Date
```

### Prompt for salesforce-developer

```
Modify the existing AccountTriggerHandler
(force-app/main/default/classes/AccountTriggerHandler.cls) and
AccountTrigger (force-app/main/default/triggers/AccountTrigger.trigger)
to add account health rating evaluation. Follow the existing handler
pattern with recursion guard. API version: 65.0.

Requirements:

1. Before Insert & Before Update -- Health Rating Evaluation:
   - Trigger when AnnualRevenue or NumberOfEmployees changes (on update)
     or on every insert.
   - Set Health_Rating__c based on:
     - "Good": AnnualRevenue > 10,000,000 AND NumberOfEmployees > 500
     - "Average": AnnualRevenue between 1,000,000 and 10,000,000 (inclusive)
       OR NumberOfEmployees between 100 and 500 (inclusive)
     - "At Risk": AnnualRevenue < 1,000,000 AND NumberOfEmployees < 100
   - Set Health_Evaluated_Date__c = Datetime.now()

2. After Update -- Task Creation:
   - If Health_Rating__c changed to "At Risk" (compare old vs new),
     create a Task:
     - Subject: "Review At Risk Account: " + Account.Name
     - WhatId: Account.Id
     - OwnerId: Account.OwnerId
     - ActivityDate: Date.today().addDays(3)
   - Use Database.insert with partial success, AccessLevel.USER_MODE.

3. Create an LWC named accountHealthIndicator:
   - A card component for the Account Record Page
   - Displays Health_Rating__c value and Health_Evaluated_Date__c
   - Use @wire with getRecord to fetch the two fields
   - Expose to Lightning App Builder for Account record pages
   - Use lightning-card with a title like "Account Health"

Do not deploy -- just create the files.
```
