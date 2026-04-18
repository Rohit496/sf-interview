---
name: salesforce-developer
description: Write production-quality Apex classes, triggers, trigger handlers, test classes, and Lightning Web Components following this project's established conventions and Salesforce platform best practices.
---

# salesforce-developer

This skill governs all programmatic Salesforce development in this project. It applies to every `.cls`, `.trigger`, `.js`, `.html`, and `.css` file created or modified under `force-app/main/default/`.

---

## Usage

Invoke this skill whenever the task involves:

- Writing or modifying **Apex classes** (service, handler, utility, controller, batch, queueable, schedulable)
- Writing or modifying **Apex triggers**
- Writing or modifying **Lightning Web Components** (LWC)
- Writing **`@InvocableMethod`** classes for Flow / Agentforce integration
- Writing **test classes** (though the `salesforce-unit-testing` agent runs separately after)

Do **not** invoke this skill for declarative work (Custom Objects, Fields, Flows, Permission Sets) — that belongs to the `salesforce-admin` skill.

---

## Steps

### 1. Understand the Requirements

- Read the design requirements from `agent-output/design-requirements.md` before writing any code.
- Identify every Apex class, trigger, and LWC component needed.
- Check existing classes under `force-app/main/default/classes/` to avoid duplication and to match naming conventions.

### 2. Apply Project Code Standards

Follow **all** rules below without exception.

#### Apex — General

| Rule                      | Detail                                                                                                                                                                                  |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| **Sharing model**         | All service and handler classes use `with sharing`. Use `without sharing` only when explicitly justified.                                                                               |
| **DML style**             | Always use `Database.insert()`, `Database.update()`, `Database.delete()` with `allOrNone` flag. Never naked `insert`/`update`/`delete`.                                                 |
| **SOQL access**           | Use `WITH USER_MODE` on every SOQL query (API 65.0+).                                                                                                                                   |
| **Error handling in LWC** | Throw `AuraHandledException` for errors surfaced to LWC components.                                                                                                                     |
| **No magic strings**      | Extract all literal separators, status values, and string constants into `private static final String` or `private enum` constants with descriptive names (e.g., `KEY_SEPARATOR` not `' | '`). |
| **API version**           | All new metadata files use API version **65.0**.                                                                                                                                        |
| **Null safety**           | Null-check every SObject field access in a chain (e.g., `record.Lookup__r?.Name`).                                                                                                      |
| **SOQL bulkification**    | Collect all needed IDs/values into a `Set`, execute a single `WHERE field IN :set` query outside any loop, then map results by key. Never run SOQL inside a `for` loop.                 |

#### Apex Triggers

| Rule                       | Detail                                                                                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **One trigger per object** | Each SObject has exactly one trigger file. All logic lives in a dedicated handler class.                                              |
| **Trigger file**           | Only contains context routing: call `handler.beforeInsert(Trigger.new)` etc. No business logic.                                       |
| **Handler method names**   | Use `beforeInsert`, `afterInsert`, `beforeUpdate`, `afterUpdate`, `beforeDelete`, `afterDelete`, `afterUndelete`. **No `on` prefix.** |
| **Recursion guard**        | Add a `@TestVisible private static Boolean hasRun = false;` guard when needed; reset in tests.                                        |
| **`@TestVisible`**         | Apply to: recursion guard, named constants, and private key methods used in test assertions.                                          |

Example trigger skeleton:

```apex
trigger CaseTrigger on Case(
    before insert,
    before update,
    after insert,
    after update
) {
    CaseTriggerHandler handler = new CaseTriggerHandler();
    if (Trigger.isBefore) {
        if (Trigger.isInsert)
            handler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate)
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        if (Trigger.isInsert)
            handler.afterInsert(Trigger.new, Trigger.newMap);
        if (Trigger.isUpdate)
            handler.afterUpdate(Trigger.new, Trigger.newMap, Trigger.oldMap);
    }
}
```

#### Apex — Duplicate / Composite-Key Detection

- Always narrow the SOQL `WHERE` clause to the incoming batch's field values (e.g., `WHERE Name IN :names AND ...`) — never query all records and filter in memory.
- Use `OR` between field groups when some fields may be null (safer than `AND`).
- Perform a **within-batch duplicate check** (across records in the same trigger invocation) as a separate pass before the database query pass.

#### `@InvocableMethod` (Agentforce / Flow)

- Method signature: `global static List<OutputType> methodName(List<InputType> inputs)`
- Collect all input values into a `Set`, execute one SOQL query, then map results — never SOQL in a loop.
- Use `WITH USER_MODE` in SOQL (not `WITH SECURITY_ENFORCED` — it blocks relationship fields like `Owner.Name` for test users).
- Return `null` list entries (not thrown exceptions) for "not found" cases; let the calling agent/flow handle empty results gracefully.

#### LWC

| Rule                  | Detail                                                                                                         |
| --------------------- | -------------------------------------------------------------------------------------------------------------- |
| **Apex errors**       | Catch errors from `@wire` or `callApex` and display them via `lightning-card` / toast; never swallow silently. |
| **Accessibility**     | All interactive elements have `aria-label` or associated `<label>`.                                            |
| **No hard-coded IDs** | Never hard-code record IDs or org-specific values. Use `@api` properties or custom labels.                     |
| **Security**          | No `innerHTML` with user-controlled data (XSS risk). Use `template` directives and LWC data binding.           |

### 3. File Structure

Every new Apex class needs two files:

```
force-app/main/default/classes/
├── MyClass.cls
└── MyClass.cls-meta.xml
```

Every new trigger needs two files:

```
force-app/main/default/triggers/
├── MyTrigger.trigger
└── MyTrigger.trigger-meta.xml
```

Meta XML template (API 65.0):

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>65.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

### 4. Naming Conventions

| Artifact   | Convention               | Example                  |
| ---------- | ------------------------ | ------------------------ |
| Trigger    | `<Object>Trigger`        | `CaseTrigger`            |
| Handler    | `<Object>TriggerHandler` | `CaseTriggerHandler`     |
| Service    | `<Domain>Service`        | `AccountService`         |
| Invocable  | `<Feature>Action`        | `CaseLookupAction`       |
| Batch      | `<Feature>Batch`         | `OpenLeadFollowUpBatch`  |
| Test class | `<ClassName>Test`        | `CaseTriggerHandlerTest` |
| Constants  | `ALL_CAPS_SNAKE_CASE`    | `KEY_SEPARATOR`          |

### 5. Self-Review Checklist

Before finalising any file, verify:

- [ ] No naked DML — all DML uses `Database.*` methods
- [ ] All SOQL uses `WITH USER_MODE`
- [ ] No SOQL inside a loop
- [ ] No magic string literals — all are named constants
- [ ] Trigger handler methods named without `on` prefix
- [ ] `with sharing` on every service/handler class
- [ ] `@TestVisible` on recursion guard and constants used in tests
- [ ] Meta XML file present for every `.cls` and `.trigger`
- [ ] API version is **65.0** on all new meta XML files
- [ ] No hard-coded record IDs in LWC

### 6. Output

After writing all files, produce a summary listing:

- Every file created (path + purpose)
- Any assumptions made
- Any edge cases not covered that the unit-testing agent should focus on

---

## Reference: Project Org Details

- **Target Org:** `rohitdotnet75.bb85a2297fcd@agentforce.com`
- **Org ID:** `00Dg500000583h1EAA`
- **Package Directory:** `force-app/main/default`
- **API Version:** 65.0
