===============================================================================
                    DESIGN REQUIREMENTS
===============================================================================

TARGET: WHAT USER REQUESTED
-------------------------------------------------------------------------------

Enhance the EXISTING `myAccounts` LWC component and its backing Apex controller:

1. Replace the current card-based layout with a `lightning-datatable`
2. Datatable columns: Id (hidden), Name, Industry, Phone, AnnualRevenue, Rating
3. No special datatable features (no inline editing, no row selection, no row
   actions, no pagination)
4. Update the existing `AccountController.getAccounts` Apex method to return
   up to 50 records instead of the current 2-5 clamp range
5. Keep the existing `AccountController` class -- just modify the limit

-------------------------------------------------------------------------------
                    ADMIN WORK (salesforce-admin)
-------------------------------------------------------------------------------

No admin work required for this request.

-------------------------------------------------------------------------------
                    DEVELOPMENT WORK (salesforce-developer)
-------------------------------------------------------------------------------

Five existing files to MODIFY (no new files created):

-- CHANGE 1: APEX -- AccountController.cls --

File: /home/user/sf-interview/force-app/main/default/classes/AccountController.cls

Current behavior:
  - `clampDisplayCount()` clamps the `displayCount` parameter to range [2, 5]
  - Line 51: `if (value == null || value < 2) { return 2; }`
  - Line 54: `return value > 5 ? 5 : value;`

Required change:
  - Modify `clampDisplayCount()` to clamp to range [1, 50] instead of [2, 5]
  - When value is null or below 1, default to 50 (to match new displayCount default)
  - When value exceeds 50, cap at 50
  - Keep the method signature `getAccounts(Integer displayCount)` unchanged
  - Keep `@AuraEnabled(cacheable=true)` unchanged
  - Keep `WITH USER_MODE` in the SOQL query unchanged
  - Keep the `AccountResult` wrapper class unchanged
  - The SOQL SELECT already includes Id, Name, Industry, Phone, AnnualRevenue,
    Rating -- no changes needed to the query fields
  - Update Javadoc comments to reflect the new range

-- CHANGE 2: LWC JAVASCRIPT -- myAccounts.js --

File: /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js

Current behavior:
  - Uses AVATAR_COLORS and RATING_CLASS_MAP constants for card rendering
  - Maps results through `_enrichAccount()` which adds avatarLetter, avatarStyle,
    formattedRevenue, ratingClass, isHot
  - Has `_formatCurrency()` helper
  - Has `@api displayCount = 5`

Required changes:
  - Remove the `AVATAR_COLORS` constant (not needed for datatable)
  - Remove the `RATING_CLASS_MAP` constant (not needed for datatable)
  - Remove the `_enrichAccount()` method
  - Remove the `_formatCurrency()` method
  - Change `@api displayCount` default from 5 to 50
  - Add a `columns` property (constant array) for lightning-datatable:
      { label: 'Account Name', fieldName: 'Name', type: 'text' }
      { label: 'Industry', fieldName: 'Industry', type: 'text' }
      { label: 'Phone', fieldName: 'Phone', type: 'phone' }
      { label: 'Annual Revenue', fieldName: 'AnnualRevenue', type: 'currency' }
      { label: 'Rating', fieldName: 'Rating', type: 'text' }
    Id is NOT a visible column -- used only as key-field on the datatable
  - Simplify the wire handler: assign `data.accounts` directly to `this.accounts`
    (remove the `.map((acc) => this._enrichAccount(acc))` call)
  - Keep: @api title, hasAccounts, hasError, footerText, errorMessage, isLoading,
    totalCount, wire import, error handling

-- CHANGE 3: LWC TEMPLATE -- myAccounts.html --

File: /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.html

Current behavior:
  - Renders cards with for:each iteration (lines 28-83)
  - Each card has avatar, name, industry, phone, revenue, rating

Required changes:
  - Remove the entire for:each card iteration block (lines 28-83)
  - Replace with a lightning-datatable:
      <lightning-datatable
          key-field="Id"
          data={accounts}
          columns={columns}
          hide-checkbox-column
      ></lightning-datatable>
  - Keep: header section with {title}
  - Keep: loading spinner
  - Keep: error state display
  - Keep: footer with {footerText}

-- CHANGE 4: LWC CSS -- myAccounts.css --

File: /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.css

Required changes:
  - Remove .rating-hot, .rating-warm, .rating-cold, .rating-default CSS rules
  - Keep: .accounts-header (still used by header)
  - Keep: .footer-pill, .footer-text (still used by footer)

-- CHANGE 5: LWC META XML -- myAccounts.js-meta.xml --

File: /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js-meta.xml

Required changes:
  - Update displayCount property default from "5" to "50"
  - Update description from "2-5" to "1-50"

-------------------------------------------------------------------------------
                    FILES SUMMARY
-------------------------------------------------------------------------------

FILES TO MODIFY (5 files -- no new files created):

  1. /home/user/sf-interview/force-app/main/default/classes/AccountController.cls
     -> Change clamp range from [2, 5] to [1, 50]

  2. /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js
     -> Replace card enrichment logic with datatable columns, simplify wire handler

  3. /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.html
     -> Replace card iteration with lightning-datatable

  4. /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.css
     -> Remove unused rating styles

  5. /home/user/sf-interview/force-app/main/default/lwc/myAccounts/myAccounts.js-meta.xml
     -> Update displayCount default and description

FILES TO CREATE:
  (none)

EXISTING TEST FILES THAT WILL BREAK (noted for awareness -- user did not
request test changes, so these are NOT in scope):

  - /home/user/sf-interview/force-app/main/default/classes/AccountControllerTest.cls
    -> Tests assert clamp values of 2 and 5 which will change

  - /home/user/sf-interview/force-app/main/default/lwc/myAccounts/__tests__/myAccounts.test.js
    -> Tests reference .account-card, .rating-hot, .rating-warm CSS selectors
       that will no longer exist after switching to datatable

-------------------------------------------------------------------------------
                    EXECUTION ORDER
-------------------------------------------------------------------------------

1. Apex change (AccountController.cls) -- the LWC depends on the Apex method
   returning the correct number of records
2. LWC changes (JS, HTML, CSS, meta XML) -- all LWC files changed together as
   a single component bundle

Both can technically proceed in parallel since the Apex method signature and
return type are unchanged. The wire call in LWC stays the same.

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
Do NOT create any new files. Do NOT create any new components. Do NOT deploy.

1. APEX -- AccountController.cls
   Path: force-app/main/default/classes/AccountController.cls
   - Change the `clampDisplayCount` private method to clamp to range [1, 50]
     instead of [2, 5].
   - When value is null or below 1, return 50 (the new default).
   - When value exceeds 50, cap at 50.
   - Keep everything else: method signature, @AuraEnabled(cacheable=true),
     WITH USER_MODE, AccountResult wrapper, query fields, ORDER BY.
   - Update Javadoc comments to reflect the new range.

2. LWC JavaScript -- myAccounts.js
   Path: force-app/main/default/lwc/myAccounts/myAccounts.js
   - Remove the AVATAR_COLORS constant, RATING_CLASS_MAP constant,
     _enrichAccount() method, and _formatCurrency() method.
   - Change @api displayCount default from 5 to 50.
   - Add a columns property (constant array) for lightning-datatable:
       { label: 'Account Name', fieldName: 'Name', type: 'text' }
       { label: 'Industry', fieldName: 'Industry', type: 'text' }
       { label: 'Phone', fieldName: 'Phone', type: 'phone' }
       { label: 'Annual Revenue', fieldName: 'AnnualRevenue', type: 'currency' }
       { label: 'Rating', fieldName: 'Rating', type: 'text' }
     Id is the key-field but NOT a visible column.
   - In the wire handler, assign data.accounts directly to this.accounts
     (no mapping through _enrichAccount).
   - Keep: @api title, hasAccounts, hasError, footerText, errorMessage,
     isLoading, totalCount, wire import, error handling.

3. LWC Template -- myAccounts.html
   Path: force-app/main/default/lwc/myAccounts/myAccounts.html
   - Remove the entire for:each card iteration block.
   - Replace with:
       <lightning-datatable
           key-field="Id"
           data={accounts}
           columns={columns}
           hide-checkbox-column
       ></lightning-datatable>
   - Keep: the header with {title}, the loading spinner, the error state,
     and the footer with {footerText}.

4. LWC CSS -- myAccounts.css
   Path: force-app/main/default/lwc/myAccounts/myAccounts.css
   - Remove .rating-hot, .rating-warm, .rating-cold, .rating-default rules.
   - Keep: .accounts-header, .footer-pill, .footer-text rules.

5. LWC Meta XML -- myAccounts.js-meta.xml
   Path: force-app/main/default/lwc/myAccounts/myAccounts.js-meta.xml
   - Change displayCount default from "5" to "50".
   - Update description to say "1-50" instead of "2-5".

Do NOT add inline editing, row selection, row actions, pagination, sorting,
or search. Do NOT modify any test files. Do NOT create new files. Do NOT deploy.
"""

===============================================================================
