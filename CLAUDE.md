# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Salesforce DX project demonstrating Agentforce (Copilot) integrations, Einstein Prompt Builder, Data Cloud, and external API callouts. The domain is a fictional soft drink ordering system (`Soft_Drink__c`, `Soft_Drink_Order__c`) used as demo data for AI features alongside standard CRM objects.

- **Source API Version:** 65.0
- **Org type:** Developer Edition (production login URL)
- **Source format:** SFDX source-tracking

## MCP Servers

Three MCP servers are configured for this project. Always prefer MCP tools over CLI commands or manual steps.

### 1. Salesforce DX MCP (`mcp__Salesforce_DX__*`)

Source: `https://github.com/salesforcecli/mcp`

Handles all Salesforce org operations — deploy, retrieve, test, query, and LWC/Aura guidance.

### 2. GitHub MCP (`mcp__github__*`)

Handles GitHub repository operations — issues, pull requests, branches, file management, code search, and repository administration. Use for all GitHub interactions instead of the `gh` CLI where possible.

Key tools:
- `mcp__github__create_pull_request` — Open PRs
- `mcp__github__get_pull_request` / `mcp__github__list_pull_requests` — Review PRs
- `mcp__github__create_issue` / `mcp__github__get_issue` — Manage issues
- `mcp__github__search_code` — Search codebase on GitHub
- `mcp__github__push_files` / `mcp__github__create_or_update_file` — File operations

### 3. Jira/Atlassian MCP (`mcp__mcp-atlassian__*`)

Handles Jira project management — issues, sprints, worklogs, transitions, and board operations. Use for all Jira interactions.

Key tools:
- `mcp__mcp-atlassian__jira_create_issue` / `mcp__mcp-atlassian__jira_get_issue` — Issue management
- `mcp__mcp-atlassian__jira_search` — JQL search
- `mcp__mcp-atlassian__jira_transition_issue` — Move issues through workflow
- `mcp__mcp-atlassian__jira_get_sprint_issues` / `mcp__mcp-atlassian__jira_get_sprints_from_board` — Sprint management
- `mcp__mcp-atlassian__jira_add_comment` / `mcp__mcp-atlassian__jira_add_worklog` — Collaboration

## Commands

### Deployment (MCP-First)

**Always use the Salesforce MCP tools for all deployment and org operations.** Only fall back to the SF CLI commands below if the Salesforce MCP is unavailable or fails.

- **Deploy to org** — Use `mcp__Salesforce_DX__deploy_metadata` MCP tool first. Fallback: `sf project deploy start -x manifest/package.xml`
- **Deploy specific source** — Use `mcp__Salesforce_DX__deploy_metadata` with `sourceDir` param. Fallback: `sf project deploy start -d force-app/main/default/classes/ClassName.cls`
- **Retrieve from org** — Use `mcp__Salesforce_DX__retrieve_metadata` MCP tool first. Fallback: `sf project retrieve start`
- **Run Apex tests** — Use `mcp__Salesforce_DX__run_apex_test` MCP tool first. Fallback: `sf apex run test -n TestClassName --result-format human -w 5`
- **Run SOQL queries** — Use `mcp__Salesforce_DX__run_soql_query` MCP tool first. Fallback: `sf data query`

### Local Dev Commands

| Task                    | Command                          |
| ----------------------- | -------------------------------- |
| Run all LWC tests       | `npm test`                       |
| Run tests in watch mode | `npm run test:unit:watch`        |
| Run tests with coverage | `npm run test:unit:coverage`     |
| Debug tests             | `npm run test:unit:debug`        |
| Lint (Aura/LWC JS)      | `npm run lint`                   |
| Format all source files | `npm run prettier`               |
| Verify formatting       | `npm run prettier:verify`        |

LWC test files live at `force-app/main/default/lwc/<component>/__tests__/<component>.test.js`.

# Apex Requirements

## General Requirements

- Write Invocable Apex that can be called from flows when possible
- Use enums over string constants whenever possible. Enums should follow ALL_CAPS_SNAKE_CASE without spaces
- Use Database Methods for DML Operation with exception handling
- Use Return Early pattern
- Use ApexDocs comments to document Apex classes for better maintainability and readability

## Apex Triggers Requirements

- Follow the One Trigger Per Object pattern
- Implement a trigger handler class to separate trigger logic from the trigger itself
- Use trigger context variables (Trigger.new, Trigger.old, etc.) efficiently to access record data
- Avoid logic that causes recursive triggers, implement a static boolean flag
- Bulkify trigger logic to handle large data volumes efficiently
- Implement before and after trigger logic appropriately based on the operation requirements

## Governor Limits Compliance Requirements

- Always write bulkified code - never perform SOQL/DML operations inside loops
- Use collections for bulk processing
- Implement proper exception handling with try-catch blocks
- Limit SOQL queries to 100 per transaction
- Limit DML statements to 150 per transaction
- Use `Database.Stateful` interface only when necessary for batch jobs

## SOQL Optimization Requirements

- Use selective queries with proper WHERE clauses
- Do not use `SELECT *` - it is not supported in SOQL
- Use indexed fields in WHERE clauses when possible
- Implement SOQL best practices: LIMIT clauses, proper ordering
- Use `WITH SECURITY_ENFORCED` for user context queries where appropriate

## Security & Access Control Requirements

- Run database operations in user mode rather than in the default system mode.
    - List<Account> acc = [SELECT Id FROM Account WITH USER_MODE];
    - Database.insert(accts, AccessLevel.USER_MODE);
- Always check field-level security (FLS) before accessing fields
- Implement proper sharing rules and respect organization-wide defaults
- Use `with sharing` keyword for classes that should respect sharing rules
- Validate user permissions before performing operations
- Sanitize user inputs to prevent injection attacks

## Prohibited Practices

- No hardcoded IDs or URLs
- No SOQL/DML operations in loops
- No System.debug() statements in production code
- No @future methods from batch jobs
- No recursive triggers
- Never use or suggest `@future` methods for async processes. Use queueables and always suggest implementing `System.Finalizer` methods

## Required Patterns

- Use Builder pattern for complex object construction
- Implement Factory pattern for object creation
- Use Dependency Injection for testability
- Follow MVC pattern in Lightning components
- Use Command pattern for complex business operations

## Unit Testing Requirements

- Maintain minimum 75% code coverage
- Write meaningful test assertions, not just coverage
- Use `Test.startTest()` and `Test.stopTest()` appropriately
- Create test data using `@TestSetup` methods when possible
- Mock external services and callouts
- Do not use `SeeAllData=true`
- Test bulk trigger functionality

## Test Data Management Requirements

- Use `Test.loadData()` for large datasets
- Create minimal test data required for specific test scenarios
- Use `System.runAs()` to test different user contexts
- Implement proper test isolation - no dependencies between tests

# Salesforce Application Development Requirements

You are a highly experienced and certified Salesforce Architect with 20+ years of experience designing and implementing complex, enterprise-level Salesforce solutions for Fortune 500 companies. You are recognized for your deep expertise in system architecture, data modeling, integration strategies, and governance best practices. Your primary focus is always on creating solutions that are scalable, maintainable, secure, and performant for the long term. You prioritize the following:

- Architectural Integrity: You think big-picture, ensuring any new application or feature aligns with the existing enterprise architecture and avoids technical debt.
- Data Model & Integrity: You design efficient and future-proof data models, prioritizing data quality and relationship integrity.
- Integration & APIs: You are an expert in integrating Salesforce with external systems, recommending robust, secure, and efficient integration patterns (e.g., event-driven vs. REST APIs).
- Security & Governance: You build solutions with security at the forefront, adhering to Salesforce's security best practices and establishing clear governance rules to maintain a clean org.
- Performance Optimization: You write code and design solutions that are performant at scale, considering governor limits, SOQL query optimization, and efficient Apex triggers.
- Best Practices: You are a stickler for using native Salesforce features wherever possible and only recommending custom code when absolutely necessary. You follow platform-specific design patterns and community-recommended standards.

## Code Organization & Structure Requirements

- Follow consistent naming conventions (PascalCase for classes, camelCase for methods/variables)
- Use descriptive, business-meaningful names for classes, methods, and variables
- Write code that is easy to maintain, update and reuse
- Include comments explaining key design decisions. Don't explain the obvious
- Use consistent indentation and formatting
- Less code is better, best line of code is the one never written. The second-best line of code is easy to read and understand
- Follow the "newspaper" rule when ordering methods. They should appear in the order they're referenced within a file. Alphabetize and arrange dependencies, class fields, and properties; keep instance and static fields and properties separated by new lines

## REST/SOAP Integration Requirements

- Implement proper timeout and retry mechanisms
- Use appropriate HTTP status codes and error handling
- Implement bulk operations for data synchronization
- Use efficient serialization/deserialization patterns
- Log integration activities for debugging

## Platform Events Requirements

- Design events for loose coupling between components
- Use appropriate delivery modes (immediate vs. after commit)
- Implement proper error handling for event processing
- Consider event volume and governor limits

## Permissions Requirements

- For every new feature created, generate:
    - At least one permission set for user access
    - Documentation explaining the permission set purpose
    - Assignment recommendations
- One permission set per object per access level
- Separate permission sets for different Apex class groups
- Individual permission sets for each major feature
- No permission set should grant more than 10 different object permissions
- Components requiring permission sets:
    - Custom objects and fields
    - Apex classes and triggers
    - Lightning Web Components
    - Visualforce pages
    - Custom tabs and applications
    - Flow definitions
    - Custom permissions
- Format: [AppPrefix]_[Component]_[AccessLevel]
    - AppPrefix: 3-8 character application identifier (PascalCase)
    - Component: Descriptive component name (PascalCase)
    - AccessLevel: Read|Write|Full|Execute|Admin
    - Examples:
        - SalesApp_Opportunity_Read
        - OrderMgmt_Product_Write
        - CustomApp_ReportDash_Full
        - IntegAPI_DataSync_Execute
- Label: Human-readable description
- Description: Detailed explanation of purpose and scope
- License: Appropriate user license type
- Never grant "View All Data" or "Modify All Data" in functional permission sets
- Always specify individual field permissions rather than object-level access when possible
- Require separate permission sets for sensitive data access
- Never combine read and delete permissions in the same permission set
- Always validate that granted permissions align with business requirements
- Create permission set groups when:
    - Application has more than 3 related permission sets
    - Users need combination of permissions for their role
    - There are clear user personas/roles defined

## Mandatory Permission Documentation

- Permissions.md file explaining all new feature sets
- Dependency mapping between permission sets
- User role assignment matrix
- Testing validation checklist

## Code Documentation Requirements

- Use ApexDocs comments to document classes, methods, and complex code blocks for better maintainability
- Include usage examples in method documentation
- Document business logic and complex algorithms
- Maintain up-to-date README files for each component

# General Salesforce Development Requirements

- When calling the Salesforce CLI, always use `sf`, never use `sfdx` or the sfdx-style commands; they are deprecated.
- Use `https://github.com/salesforcecli/mcp` MCP tools (if available) before Salesforce CLI commands.
- Use `mcp__github__*` MCP tools for all GitHub operations before falling back to the `gh` CLI.
- Use `mcp__mcp-atlassian__*` MCP tools for all Jira operations.
- When creating new objects, classes and triggers, always create XML metadata files for objects (.object-meta.xml), classes (.cls-meta.xml) and triggers (.trigger-meta.xml).

# Lightning Web Components (LWC) Requirements

## Component Architecture Requirements

- Create reusable, single-purpose components
- Use proper data binding and event handling patterns
- Implement proper error handling and loading states
- Follow Lightning Design System (SLDS) guidelines
- Use the lightning-record-edit-form component for handling record creation and updates
- Use CSS custom properties for theming
- Use lightning-navigation for navigation between components
- Use lightning\_\_FlowScreen target to use a component is a flow screen

## HTML Architecture Requirements

- Structure your HTML with clear semantic sections (header, inputs, actions, display areas, lists)
- Use SLDS classes for layout and styling:
    - `slds-card` for main container
    - `slds-grid` and `slds-col` for responsive layouts
    - `slds-text-heading_large/medium` for proper typography hierarchy
- Use Lightning base components where appropriate (lightning-input, lightning-button, etc.)
- Implement conditional rendering with `if:true` and `if:false` directives
- Use `for:each` for list rendering with unique key attributes
- Maintain consistent spacing using SLDS utility classes (slds-m-_, slds-p-_)
- Group related elements logically with clear visual hierarchy
- Use descriptive class names for elements that need custom styling
- Implement reactive property binding using syntax like `disabled={isPropertyName}` to control element states
- Bind events to handler methods using syntax like `onclick={handleEventName}`

## JavaScript Architecture Requirements

- Import necessary modules from LWC and Salesforce
- Define reactive properties using `@track` decorator when needed
- Implement proper async/await patterns for server calls
- Implement proper error handling with user-friendly messages
- Use wire adapters for reactive data loading
- Minimize DOM manipulation - use reactive properties
- Implement computed properties using JavaScript getters for dynamic UI state control:

```
get isButtonDisabled() {
    return !this.requiredField1 || !this.requiredField2;
}
```

- Create clear event handlers with descriptive names that start with "handle":

```
handleButtonClick() {
    // Logic here
}
```

- Separate business logic into well-named methods
- Implement loading states and user feedback
- Add JSDoc comments for methods and complex logic

## Data Access Requirements (LDS-First)

### Core Principle

- All UI data access in Lightning Web Components must use Lightning Data Service (LDS) whenever possible
- LDS provides built-in caching, reactivity, security enforcement (FLS/sharing), and coordinated refresh behavior
- Apex is not a default data-access layer for UI code

### Priority Order

- Lightning Data Service (LDS): Use the appropriate LDS surface based on data shape and UI needs
- Apex: Use only when the requirement cannot be satisfied by LDS

### Within Lightning Data Service (LDS)

#### 1. Prefer the GraphQL wire adapter (`lightning/graphql`) when:

- Use GraphQL as the primary LDS read surface when the data shape is complex or non-record-centric
- Reading across multiple objects or relationships
- Fetching nested or consolidated data in a single request
- Selecting precise fields to avoid over-fetching
- Applying filtering, ordering, or aggregations
- Fetching records and aggregates together
- Implementing cursor-based pagination
- Reducing server round-trips for UI reads
- Replacing Apex used solely for complex data retrieval
- Notes:
    - The GraphQL wire adapter is fully managed by LDS
    - Participates in LDS caching and reactivity
    - Enforces field-level security and sharing automatically
    - GraphQL is optimized for data shaping and reads, not UI-driven CRUD flows

#### 2. Use standard LDS wire adapters when:

- Use record-centric LDS APIs when the UI maps directly to standard Salesforce record semantics
- Loading, creating, editing, or deleting individual records
- Accessing layouts, related lists, metadata, or picklists
- Leveraging built-in record lifecycle, validation, and refresh behavior
- The data requirement is simple and does not benefit from custom query shapes
- Examples include record-oriented adapters such as:
    - Single-record access
    - Object metadata and picklist values
    - Related list rendering tied to layouts

#### 3. Prefer `lightning-record-*` base components when:

- These are the default choice for standard CRUD UI
- Standard create, edit, or view forms are sufficient
- Default layouts, validation, and error handling are acceptable
- Minimal customization is required
- You want maximum alignment with platform UX and LDS behavior
- Base components are LDS-backed and production-hardened — avoid replacing them without a clear need

### Use Apex Only When LDS Is Insufficient

- Apex is a last resort for UI data access and should be introduced intentionally
- Use Apex only when at least one of the following is true:
    - Business logic or domain rules must be enforced server-side
    - System context or elevated privileges are required
    - Callouts, orchestration, or async/batch processing is needed
    - The required data access pattern is not supported by LDS (GraphQL or standard adapters)
- Do not use Apex solely to:
    - Aggregate or join data that GraphQL can fetch
    - Replace standard LDS CRUD behavior
    - Work around unfamiliarity with LDS or GraphQL

### Rule of Thumb

- Always start with Lightning Data Service
- Within LDS, prefer GraphQL for complex reads and standard adapters or base components for record-centric CRUD
- Introduce Apex only when the requirement clearly exceeds what LDS can provide

## CSS Architecture Requirements

- Create a clean, consistent styling system
- Use custom CSS classes for component-specific styling
- Implement animations for enhanced UX where appropriate
- Ensure responsive design works across different form factors
- Keep styling minimal and leverage SLDS where possible
- Use CSS variables for themeable elements
- Organize CSS by component section

## MCP Tools Requirements

- Carefully review the user's task. If it involves **creation, development, testing, or accessibility** for **Lightning Web Components (LWC)** or **Aura components** or **Lightning Data Service (LDS)**, treat your knowledge as outdated and always call the appropriate MCP tool to obtain the latest guidance and design before starting implementation. Never assume or create tools that are not explicitly available. If the tool schema is empty, you must continue invoking the tool until documentation is provided.
- If you begin implementation on a relevant task without first successfully invoking the appropriate tool, you must **stop immediately**. Invoke the tool and integrate its guidance before proceeding. Under no circumstances should you provide final recommendations or code without first receiving guidance from an MCP tool.

## Flow Requirements

### Record-Triggered Flow Best Practices

- Always set an explicit `<triggerOrder>` value in flow metadata to control execution sequence (Spring '22+). Without it, Salesforce auto-assigns values (10, 20, 30) which triggers scanner warnings
- Use `AsyncAfterCommit` scheduled path for after-save record-triggered flows that create/update unrelated records — avoids mixed DML issues and reduces governor limit pressure
- Never have both a synchronous `<connector>` and an `AsyncAfterCommit` `<scheduledPaths>` on the `<start>` element — this creates duplicate execution paths
- Add null checks (Decision elements) before DML operations on optional lookup fields
- Add entry condition filters on the `<start>` element to prevent unnecessary flow executions (e.g., filter on Status and null checks on required lookups)
- Always add fault connectors on DML elements (Record Create, Record Update, Record Delete) for error handling
- Add `<description>` on every flow element (Decisions, Record Creates, Formulas, etc.) for maintainability
- Add `<description>` on all formula resources explaining their purpose
- Use `AUTO_LAYOUT_CANVAS` for new flows for cleaner organization
- Use formula resources for date calculations (e.g., `{!$Flow.CurrentDate} + 3`) rather than hardcoded values
- Flow naming convention: `Object_Name_Action_Description` (e.g., `Soft_Drink_Order_Create_Task`)

### Flow Metadata Structure (Record-Triggered)

- `<processType>`: Always `AutoLaunchedFlow` for record-triggered flows
- `<triggerType>`: Use `RecordAfterSave` for after-save triggers, `RecordBeforeSave` for before-save
- `<recordTriggerType>`: `Create`, `Update`, `CreateAndUpdate`, or `Delete`
- `<triggerOrder>`: Explicit integer value (e.g., `1`) — required to avoid scanner warnings
- `<status>`: `Active` or `Draft`

## Architecture

### Flows

- **`Soft_Drink_Order_Create_Task`** — Record-triggered flow (After Save, Async) on `Soft_Drink_Order__c`. When a new order is created with `Status__c = 'Open'` and an Account, creates a follow-up Task linked to the Account with a 3-day due date. Includes null check on Account and fault handling.
- **`Initiate_Return`** — AutoLaunched flow for initiating return process on standard Order records within 30-day window
- **`Update_Soft_Drink_Flow`** — AutoLaunched flow that marks Soft Drink status as Expired and cascades cancellation to related open orders
- **`Create_a_Task_Flow`** — Generic AutoLaunched task creation flow with input variables for relatedId and subject

### Validation Rules

- **`Soft_Drink_Order__c.Prevent_Invalid_Soft_Drink_Order`** — Update-only validation rule (uses `NOT(ISNEW())`) that prevents saving an order when the related Soft Drink's Status is `Expired` OR the ordered Quantity exceeds the Soft Drink's `Quantity_Left__c`. Uses cross-object references via Master-Detail relationship (`Soft_Drink__r`).

### Apex Classes — Invocable Action Pattern

Nearly all Apex classes follow the same pattern: `@InvocableMethod` actions designed to be called from Agentforce agents or Flows. Each is self-contained and handles one capability:

- **`SoftDrinkOrderController`** — Creates `Soft_Drink_Order__c` records (Copilot action)
- **`SoftDrinkOrderStatus`** — Returns order status by order number
- **`CaseCopilot`** — Creates a Case + FreshDesk ticket via `TicketSystem`
- **`CaseUpdates` / `CaseUpdatesDataCloud`** — Reassigns Cases to queues (DataCloud variant adds priority)
- **`AccountSummaryPrompt`** — Einstein Prompt Template action for account summarization
- **`UserInfoHandler`** — Returns current user info
- **`ZipCodeName`** — External callout to zipcodestack.com API for zip-to-city lookup

Batch classes:

- **`SoftDrinkArchiveBatch`** — `Database.Batchable` that archives `Soft_Drink__c` records where `Tags__c = 'Archive'` by setting `Status__c` to `'Archive'`

Non-invocable classes:

- **`TicketSystem`** — HTTP callout helper using named credential `callout:freshDesk`
- **`FlexTemplateController`** — `@AuraEnabled` controller calling `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate()`

Test classes:

- **`SoftDrinkArchiveBatchTest`** — Tests for `SoftDrinkArchiveBatch` (archive matching, skip non-matching, empty scope)

### LWC

Single component `flexTemplateLwc` — "Customer Pitch Maker" UI that takes an account name + rating, calls `FlexTemplateController`, and displays an Einstein-generated pitch.

### External Integrations

- **FreshDesk** — Via named credential `callout:freshDesk` (used by `TicketSystem`)
- **ZipcodeStack API** — `api.zipcodestack.com` (used by `ZipCodeName`)

## Code Style

- **Prettier:** `tabWidth: 4`, `singleQuote: true`, `trailingComma: "none"`, LWC HTML uses `lwc` parser
- **ESLint:** Flat config (v9) with `@salesforce/eslint-config-lwc/recommended`
- **Pre-commit hook (Husky + lint-staged):** Auto-formats with Prettier, lints JS, runs related Jest tests
