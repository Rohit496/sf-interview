===============================================================================
                    DESIGN REQUIREMENTS
===============================================================================

TARGET: WHAT USER REQUESTED
-------------------------------------------------------------------------------

Enhance the EXISTING `myAccounts` LWC component and its backing Apex controller:

1. Replace the current card-based layout with a `lightning-datatable`
2. Datatable columns: Id (hidden), Name, Industry, Phone, AnnualRevenue, Rating
3. No special features (no inline editing, no row selection, no row actions,
   no pagination)
4. Modify the existing `AccountController.getAccounts` Apex method to return up
   to 50 records instead of the current 2-5 clamp range
5. Keep the existing `AccountController` class -- just modify the limit logic

-------------------------------------------------------------------------------
                    ADMIN WORK (salesforce-admin)
-------------------------------------------------------------------------------

No admin work required for this request.

-------------------------------------------------------------------------------
                    DEVELOPMENT WORK (salesforce-developer)
-------------------------------------------------------------------------------

Two areas of change across 5 existing files (no new files created):

CHANGE 1 -- Apex: AccountController.cls
  File: /home/user/sf-interview/force-app/main/default/classes/AccountController.cls

  Current behavior:
    - `clampDisplayCount()` clamps the `displayCount` parameter to range [2, 5]
    - Line 51: `if (value == null || value < 2) { return 2; }`
    - Line 54: `return value > 5 ? 5 : value;`

  Required change:
    - Change the clamp range so the method returns up to 50 records
    - Update `clampDisplayCount()` to use a max of 50 instead of 5
    - Keep the method signature `getAccounts(Integer displayCount)` unchanged
    - Keep `@AuraEnabled(cacheable=true)` unchanged
    - Keep `WITH USER_MODE` in the SOQL query unchanged
    - Keep the `AccountResult` wrapper class unchanged
    - The SOQL SELECT fields already include Id, Name, Industry, Phone,
      AnnualRevenue, Rating -- no changes needed to the query fields
    - Update the class-level JSDoc comment about the clamped range

CHANGE 2 -- LWC JavaScript: myAccounts.js
  File: /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js

  Current behavior:
    - Imports `getAccounts` via wire and maps results through `_enrichAccount()`
    - `_enrichAccount()` adds `avatarLetter`, `avatarStyle`, `formattedRevenue`,
      `ratingClass`, `isHot` -- all used by the card layout in the template
    - Has `@api displayCount = 5` property
    - Has computed properties: `hasAccounts`, `hasError`, `footerText`
    - Has helper constants: `AVATAR_COLORS`, `RATING_CLASS_MAP`

  Required changes:
    - Remove the `_enrichAccount()` method and the `AVATAR_COLORS` and
      `RATING_CLASS_MAP` constants (no longer needed for datatable)
    - Remove the `_formatCurrency()` method (datatable handles formatting via
      column type)
    - Remove the `hasAccounts` computed property (datatable handles empty state)
    - Keep the `hasError` computed property and `errorMessage` for error display
    - Keep the `footerText` computed property
    - Keep the `@api title` property
    - Update `@api displayCount` default to 50
    - Add a `columns` property (constant array) for lightning-datatable with
      these columns:
        - Name: label "Name", fieldName "Name", type "text"
        - Industry: label "Industry", fieldName "Industry", type "text"
        - Phone: label "Phone", fieldName "Phone", type "phone"
        - AnnualRevenue: label "Annual Revenue", fieldName "AnnualRevenue",
          type "currency"
        - Rating: label "Rating", fieldName "Rating", type "text"
      (Id is the key-field on the datatable but NOT a visible column)
    - In the wire handler, assign data.accounts directly to this.accounts
      (no mapping through _enrichAccount)
    - Keep: @api title, hasError, footerText, errorMessage, isLoading,
      totalCount, wire import, error handling

CHANGE 3 -- LWC Template: myAccounts.html
  File: /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.html

  Current behavior:
    - Renders a card layout with `for:each` iterating over accounts
    - Each card shows avatar, name, industry, phone, revenue, rating
    - Has a loading spinner, error state, and footer

  Required changes:
    - Remove the entire for:each card iteration block
    - Replace with a single lightning-datatable:
        key-field="Id"
        data={accounts}
        columns={columns}
        hide-checkbox-column
    - Keep the header section with {title}
    - Keep the loading spinner
    - Keep the error state display
    - Keep the footer with {footerText}

CHANGE 4 -- LWC CSS: myAccounts.css
  File: /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.css

  Required changes:
    - Remove .rating-hot, .rating-warm, .rating-cold, and .rating-default
      CSS rules (no longer used with datatable)
    - Keep .accounts-header styles (header is preserved)
    - Keep .footer-pill and .footer-text styles (footer is preserved)

CHANGE 5 -- LWC Meta XML: myAccounts.js-meta.xml
  File: /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js-meta.xml

  Required change:
    - Update the displayCount property: change default from "5" to "50"
    - Update the description to reflect new range (up to 50 instead of 2-5)

-------------------------------------------------------------------------------
                    FILES SUMMARY
-------------------------------------------------------------------------------

FILES TO MODIFY (5 files -- no new files created):

  1. /home/user/sf-interview/force-app/main/default/classes/AccountController.cls
     -> Change clamp max from 5 to 50

  2. /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js
     -> Replace card logic with datatable columns, remove enrichment helpers

  3. /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.html
     -> Replace card iteration with lightning-datatable

  4. /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.css
     -> Remove rating styles no longer used

  5. /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js-meta.xml
     -> Update displayCount default and description

FILES THAT WILL NEED UPDATING (existing tests -- noted for awareness, NOT
included in this scope since user did not request test changes):

  - /home/user/sf-interview/force-app/main/default/classes/AccountControllerTest.cls
    -> Tests reference clamp values of 2 and 5 which will change

  - /home/user/sf-interview/force-app/main/default/lwc/myAccounts/__tests__/myAccounts.test.js
    -> Tests reference .account-card and .rating-hot CSS selectors that will
       no longer exist after switching to datatable

-------------------------------------------------------------------------------
                    EXECUTION ORDER
-------------------------------------------------------------------------------

1. Apex changes FIRST (AccountController.cls) -- the LWC depends on the Apex
   method returning the correct number of records
2. LWC changes SECOND (myAccounts.js, myAccounts.html, myAccounts.css,
   myAccounts.js-meta.xml) -- all LWC files can be changed together since
   they are part of the same component bundle

-------------------------------------------------------------------------------
                    PROMPTS FOR SPECIALIST AGENTS
-------------------------------------------------------------------------------

PROMPT FOR salesforce-admin:
"""
No admin work required for this request.
"""

PROMPT FOR salesforce-developer:
"""
Modify the following EXISTING files in the project at /home/user/sf-interview.
API version is 65.0. Package directory: force-app/main/default.
Do NOT create any new files. Do NOT deploy.

1. APEX -- AccountController.cls
   Path: force-app/main/default/classes/AccountController.cls
   - Change the `clampDisplayCount` private method to allow up to 50 records
     instead of 5. Update the max clamp from 5 to 50.
   - Keep everything else the same: method signature, @AuraEnabled(cacheable=true),
     WITH USER_MODE, AccountResult wrapper, query fields, ORDER BY.
   - Update JSDoc comments to reflect the new range.

2. LWC JavaScript -- myAccounts.js
   Path: force-app/main/default/lwc/myAccounts/myAccounts.js
   - Remove the AVATAR_COLORS constant, RATING_CLASS_MAP constant,
     _enrichAccount() method, _formatCurrency() method, and hasAccounts
     computed property.
   - Change @api displayCount default from 5 to 50.
   - Add a columns property (constant array) for lightning-datatable with
     these columns:
       { label: 'Name', fieldName: 'Name', type: 'text' }
       { label: 'Industry', fieldName: 'Industry', type: 'text' }
       { label: 'Phone', fieldName: 'Phone', type: 'phone' }
       { label: 'Annual Revenue', fieldName: 'AnnualRevenue', type: 'currency' }
       { label: 'Rating', fieldName: 'Rating', type: 'text' }
     (Id is the key-field but NOT a visible column)
   - In the wire handler, assign data.accounts directly to this.accounts
     (no mapping through _enrichAccount).
   - Keep: @api title, hasError, footerText, errorMessage, isLoading,
     totalCount, wire import, error handling.

3. LWC Template -- myAccounts.html
   Path: force-app/main/default/lwc/myAccounts/myAccounts.html
   - Remove the entire for:each card iteration block.
   - Replace with a lightning-datatable:
       key-field="Id"
       data={accounts}
       columns={columns}
       hide-checkbox-column
   - Keep: the header with {title}, the loading spinner, the error state,
     and the footer with {footerText}.

4. LWC CSS -- myAccounts.css
   Path: force-app/main/default/lwc/myAccounts/myAccounts.css
   - Remove the .rating-hot, .rating-warm, .rating-cold, and .rating-default
     CSS rules.
   - Keep: .accounts-header, .footer-pill, .footer-text rules.

5. LWC Meta XML -- myAccounts.js-meta.xml
   Path: force-app/main/default/lwc/myAccounts/myAccounts.js-meta.xml
   - Change displayCount default from "5" to "50".
   - Update the description to say "up to 50" instead of "2-5".

Do NOT modify any test files. Do NOT create new files. Do NOT deploy.
"""

===============================================================================
