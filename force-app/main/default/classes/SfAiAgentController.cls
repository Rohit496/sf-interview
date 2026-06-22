public with sharing class SfAiAgentController {
    @AuraEnabled
    public static String askAgent(String prompt) {
        try {
            if (String.isBlank(prompt)) {
                throw new AuraHandledException('Prompt cannot be empty.');
            }

            // Check if user explicitly wants code/explanation (not live data)
            if (isCodeOrExplanationRequest(prompt)) {
                return callOpenAIChat(prompt);
            }

            // Try native org handlers
            String nativeResult = tryNativeOrgHandler(prompt);
            if (nativeResult != null)
                return nativeResult;

            // Try SOQL generation
            String soql = generateSoqlQuery(prompt);
            if (isValidSelectQuery(soql)) {
                return executeSoqlAndFormat(soql);
            }

            return callOpenAIChat(prompt);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug(
                'Exception: ' + e.getMessage() + '\n' + e.getStackTraceString()
            );
            throw new AuraHandledException(
                'Unexpected error: ' + e.getMessage()
            );
        }
    }

    // ── Intent detector — if user asks HOW or wants code, skip live data ─────────
    private static Boolean isCodeOrExplanationRequest(String prompt) {
        String lp = prompt.toLowerCase();
        // Explicit code/query requests
        if (
            lp.contains('soql query') ||
            lp.contains('write soql') ||
            lp.contains('soql to ') ||
            lp.contains('give me soql') ||
            lp.contains('show me soql') ||
            lp.contains('only soql') ||
            lp.contains('write apex') ||
            lp.contains('create apex') ||
            lp.contains('write a trigger') ||
            lp.contains('write trigger') ||
            lp.contains('create trigger') ||
            lp.contains('write lwc') ||
            lp.contains('create lwc') ||
            lp.contains('lwc component') ||
            lp.contains('how to') ||
            lp.contains('how do') ||
            lp.contains('explain') ||
            lp.contains('what is') ||
            lp.contains('difference between') ||
            lp.contains('best practice') ||
            lp.contains('example of') ||
            lp.contains('code for') ||
            lp.contains('syntax') ||
            lp.contains('sample')
        ) {
            return true;
        }
        return false;
    }

    // ── Native org handlers ───────────────────────────────────────────────────────
    private static String tryNativeOrgHandler(String prompt) {
        String lp = prompt.toLowerCase();

        // ── User info ──────────────────────────────────────────────────────────────
        if (
            lp.contains('my username') ||
            lp.contains('who am i') ||
            lp.contains('my email') ||
            lp.contains('my name') ||
            lp.contains('current user') ||
            lp.contains('my user info') ||
            lp.contains('my org')
        ) {
            return getCurrentUserInfo();
        }

        // ── Picklist VALUES for a specific field (needs Object.Field notation) ──────
        Boolean hasFieldNotation = lp.contains('.');
        Boolean asksForValues =
            lp.contains('value') ||
            lp.contains('lov') ||
            lp.contains('option');

        if (hasFieldNotation && asksForValues && containsObjectName(lp)) {
            return getPicklistValues(prompt);
        }

        // ── Picklist FIELDS on an object ──────────────────────────────────────────
        Boolean asksPicklistFields =
            lp.contains('picklist field') ||
            lp.contains('picklist on') ||
            lp.contains('picklist in') ||
            lp.contains('picklists on') ||
            lp.contains('picklists in') ||
            lp.contains('all picklist') ||
            lp.contains('available picklist') ||
            lp.contains('show picklist') ||
            lp.contains('list picklist');

        if (asksPicklistFields && containsObjectName(lp)) {
            return getPicklistFields(prompt);
        }

        // ── Fields only ───────────────────────────────────────────────────────────
        Boolean asksFieldsOnly =
            (lp.contains('field') || lp.contains('data type')) &&
            !lp.contains('child') &&
            !lp.contains('relationship') &&
            !lp.contains('describe') &&
            !lp.contains('picklist');

        if (asksFieldsOnly && containsObjectName(lp)) {
            return getObjectFields(extractObjectName(prompt));
        }

        // ── Children only ─────────────────────────────────────────────────────────
        Boolean asksChildrenOnly =
            lp.contains('child object') ||
            lp.contains('child relationship') ||
            lp.contains('children of') ||
            lp.contains('related object');

        if (asksChildrenOnly && containsObjectName(lp)) {
            return getObjectChildren(extractObjectName(prompt));
        }

        // ── Full describe ─────────────────────────────────────────────────────────
        Boolean asksFullDescribe =
            lp.contains('describe ') ||
            lp.contains('object info') ||
            lp.contains('schema of') ||
            lp.contains('full info');

        Boolean isPicklistRelated = lp.contains('picklist');

        if (!isPicklistRelated && asksFullDescribe && containsObjectName(lp)) {
            return describeObject(extractObjectName(prompt));
        }

        // ── OWD ───────────────────────────────────────────────────────────────────
        if (
            lp.contains('owd') ||
            lp.contains('org-wide') ||
            lp.contains('org wide') ||
            lp.contains('sharing default') ||
            lp.contains('default sharing') ||
            lp.contains('sharing setting')
        ) {
            return getOwdSettings();
        }

        // ── Permission Set — specific detail OR full list ─────────────────────────
        if (lp.contains('permission set') && !lp.contains('group')) {
            Boolean wantsSpecific =
                lp.contains('detail') ||
                lp.contains('info') ||
                lp.contains('named ') ||
                lp.contains('called ') ||
                lp.contains('equals') ||
                lp.contains(' = ') ||
                lp.contains('about ') ||
                lp.contains('specific') ||
                lp.contains('show me') ||
                lp.contains('full');

            Boolean hasQuotedName = lp.contains('"') || lp.contains('\'');

            if (wantsSpecific || hasQuotedName) {
                return getPermissionSetDetail(prompt);
            }

            if (
                lp.contains('list') ||
                lp.contains('all') ||
                lp.contains('show') ||
                lp.contains('fetch')
            ) {
                return getPermissionSets();
            }
        }

        // ── Permission Set Groups ─────────────────────────────────────────────────
        if (
            (lp.contains('permission set group') || lp.contains('psg')) &&
            (lp.contains('list') ||
            lp.contains('all') ||
            lp.contains('show'))
        ) {
            return getPermissionSetGroups();
        }

        // ── Profiles ──────────────────────────────────────────────────────────────
        if (
            lp.contains('profile') &&
            (lp.contains('list') ||
            lp.contains('all') ||
            lp.contains('show'))
        ) {
            return getProfiles();
        }

        // ── Roles ─────────────────────────────────────────────────────────────────
        if (
            (lp.contains('user role') || lp.contains('roles')) &&
            (lp.contains('list') ||
            lp.contains('all') ||
            lp.contains('show'))
        ) {
            return getUserRoles();
        }

        // ── Custom objects ────────────────────────────────────────────────────────
        if (
            (lp.contains('custom object') || lp.contains('all object')) &&
            (lp.contains('list') ||
            lp.contains('show') ||
            lp.contains('all'))
        ) {
            return listCustomObjects();
        }

        // ── Installed packages ────────────────────────────────────────────────────
        if (
            lp.contains('installed package') || lp.contains('managed package')
        ) {
            return getInstalledPackages();
        }

        // ── Flows ─────────────────────────────────────────────────────────────────
        if (
            lp.contains('flow') &&
            (lp.contains('list') ||
            lp.contains('all') ||
            lp.contains('active'))
        ) {
            return getFlows();
        }

        // ── Apex classes ──────────────────────────────────────────────────────────
        if (
            (lp.contains('apex class') || lp.contains('apex classes')) &&
            (lp.contains('list') ||
            lp.contains('all') ||
            lp.contains('show'))
        ) {
            return getApexClasses();
        }

        // ── Validation rules ──────────────────────────────────────────────────────
        if (
            lp.contains('validation rule') &&
            (lp.contains('list') ||
            lp.contains('show') ||
            lp.contains('all') ||
            containsObjectName(lp))
        ) {
            return getValidationRules(prompt);
        }

        // ── Record types ──────────────────────────────────────────────────────────
        if (
            lp.contains('record type') &&
            (lp.contains('list') ||
            lp.contains('show') ||
            lp.contains('all') ||
            containsObjectName(lp))
        ) {
            return getRecordTypes(prompt);
        }

        // ── Active users ──────────────────────────────────────────────────────────
        if (
            (lp.contains('all user') ||
            lp.contains('list user') ||
            lp.contains('show user') ||
            lp.contains('active user')) && !lp.contains('my')
        ) {
            return getActiveUsers();
        }

        return null;
    }

    // ── User info ─────────────────────────────────────────────────────────────────
    private static String getCurrentUserInfo() {
        User u = [
            SELECT
                Id,
                Name,
                Username,
                Email,
                Profile.Name,
                UserRole.Name,
                IsActive,
                LastLoginDate
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        return '## 👤 Your Salesforce User\n\n' +
            '| Field | Value |\n|---|---|\n' +
            '| **Name** | ' +
            u.Name +
            ' |\n' +
            '| **Username** | `' +
            u.Username +
            '` |\n' +
            '| **Email** | ' +
            u.Email +
            ' |\n' +
            '| **Profile** | ' +
            (u.Profile != null ? u.Profile.Name : '—') +
            ' |\n' +
            '| **Role** | ' +
            (u.UserRole != null ? u.UserRole.Name : '—') +
            ' |\n' +
            '| **Last Login** | ' +
            (u.LastLoginDate != null
                ? String.valueOf(u.LastLoginDate).substring(0, 10)
                : 'Never') +
            ' |\n' +
            '| **Org ID** | `' +
            UserInfo.getOrganizationId() +
            '` |\n' +
            '| **Org Name** | ' +
            UserInfo.getOrganizationName() +
            ' |';
    }

    // ── Fields only ───────────────────────────────────────────────────────────────
    private static String getObjectFields(String objectName) {
        if (String.isBlank(objectName))
            return '❌ Please specify an object. Example: "Show fields on Contact"';
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null)
                return '❌ Object `' + objectName + '` not found.';

            Schema.DescribeSObjectResult dsr = sot.getDescribe();
            Map<String, Schema.SObjectField> fields = dsr.fields.getMap();
            List<String> fieldNames = new List<String>(fields.keySet());
            fieldNames.sort();

            String result =
                '## 🗂 `' +
                dsr.getLabel() +
                '` — Fields (' +
                fields.size() +
                ')\n\n' +
                '| # | Label | API Name | Type | Required |\n|---|---|---|---|---|\n';

            Integer idx = 1;
            for (String fn : fieldNames) {
                Schema.DescribeFieldResult f = fields.get(fn).getDescribe();
                result +=
                    '| ' +
                    idx++ +
                    ' | ' +
                    f.getLabel() +
                    ' | `' +
                    f.getName() +
                    '`' +
                    ' | ' +
                    f.getType() +
                    ' | ' +
                    (f.isNillable() ? '' : '✅') +
                    ' |\n';
            }
            return result;
        } catch (Exception e) {
            return '❌ Error: ' + e.getMessage();
        }
    }

    // ── Child relationships only ───────────────────────────────────────────────────
    private static String getObjectChildren(String objectName) {
        if (String.isBlank(objectName))
            return '❌ Please specify an object. Example: "Show child objects of Account"';
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null)
                return '❌ Object `' + objectName + '` not found.';

            Schema.DescribeSObjectResult dsr = sot.getDescribe();
            List<Schema.ChildRelationship> children = dsr.getChildRelationships();

            String result =
                '## 🔗 `' +
                dsr.getLabel() +
                '` — Child Relationships (' +
                children.size() +
                ')\n\n' +
                '| # | Child Object | Relationship Name | Field |\n|---|---|---|---|\n';

            Integer idx = 1;
            for (Schema.ChildRelationship cr : children) {
                if (cr.getRelationshipName() == null)
                    continue;
                result +=
                    '| ' +
                    idx++ +
                    ' | `' +
                    cr.getChildSObject().getDescribe().getName() +
                    '`' +
                    ' | ' +
                    cr.getRelationshipName() +
                    ' | `' +
                    cr.getField().getDescribe().getName() +
                    '` |\n';
            }
            return result;
        } catch (Exception e) {
            return '❌ Error: ' + e.getMessage();
        }
    }

    // ── Full describe (fields + children) — only when explicitly asked ─────────────
    private static String describeObject(String objectName) {
        if (String.isBlank(objectName))
            return '❌ Could not detect an object name. Try: "describe Account"';
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null)
                return '❌ Object `' + objectName + '` not found.';

            Schema.DescribeSObjectResult dsr = sot.getDescribe();
            Map<String, Schema.SObjectField> fields = dsr.fields.getMap();
            List<Schema.ChildRelationship> children = dsr.getChildRelationships();

            String result =
                '## 🗂 `' +
                dsr.getLabel() +
                '` (`' +
                dsr.getName() +
                '`)\n\n' +
                '**Total Fields:** ' +
                fields.size() +
                '  ·  **Child Relationships:** ' +
                children.size() +
                '\n\n' +
                '### Fields\n\n' +
                '| # | Label | API Name | Type | Required |\n|---|---|---|---|---|\n';

            List<String> fieldNames = new List<String>(fields.keySet());
            fieldNames.sort();
            Integer idx = 1;
            for (String fn : fieldNames) {
                Schema.DescribeFieldResult f = fields.get(fn).getDescribe();
                result +=
                    '| ' +
                    idx++ +
                    ' | ' +
                    f.getLabel() +
                    ' | `' +
                    f.getName() +
                    '`' +
                    ' | ' +
                    f.getType() +
                    ' | ' +
                    (f.isNillable() ? '' : '✅') +
                    ' |\n';
            }

            result +=
                '\n### Child Relationships\n\n' +
                '| # | Child Object | Relationship Name | Field |\n|---|---|---|---|\n';
            Integer ci = 1;
            for (Schema.ChildRelationship cr : children) {
                if (cr.getRelationshipName() == null)
                    continue;
                result +=
                    '| ' +
                    ci++ +
                    ' | `' +
                    cr.getChildSObject().getDescribe().getName() +
                    '`' +
                    ' | ' +
                    cr.getRelationshipName() +
                    ' | `' +
                    cr.getField().getDescribe().getName() +
                    '` |\n';
            }
            return result;
        } catch (Exception e) {
            return '❌ Error describing object: ' + e.getMessage();
        }
    }

    // ── OWD ───────────────────────────────────────────────────────────────────────
    private static String getOwdSettings() {
        try {
            List<String> objectsToCheck = new List<String>{
                'Account',
                'Contact',
                'Opportunity',
                'Lead',
                'Case',
                'Campaign',
                'Contract',
                'Order',
                'Asset',
                'Quote',
                'Task',
                'Event',
                'Product2'
            };

            String result =
                '## 🔒 Object Sharing Info\n\n' +
                '| Object | Custom | Queryable | Createable | Has Share Object |\n' +
                '|---|---|---|---|---|\n';

            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

            for (String objName : objectsToCheck) {
                Schema.SObjectType sot = gd.get(objName);
                if (sot == null)
                    continue;
                Schema.DescribeSObjectResult dsr = sot.getDescribe();

                // Check if a Share object exists (e.g. AccountShare) — indicates OWD is not Public Read/Write
                Boolean hasShareObj = gd.containsKey(objName + 'Share');

                result +=
                    '| `' +
                    objName +
                    '`' +
                    ' | ' +
                    (dsr.isCustom() ? '✅' : '—') +
                    ' | ' +
                    (dsr.isQueryable() ? '✅' : '❌') +
                    ' | ' +
                    (dsr.isCreateable() ? '✅' : '❌') +
                    ' | ' +
                    (hasShareObj ? '✅ `' + objName + 'Share`' : '—') +
                    ' |\n';
            }

            result +=
                '\n> ℹ️ **Note:** Full OWD (Public Read Only / Private etc.) values require ' +
                'Tooling API. To check OWD go to: **Setup → Sharing Settings**.\n\n' +
                '**To query via Tooling API in Developer Console:**\n' +
                '```soql\nSELECT SobjectType, InternalSharingModel, ExternalSharingModel\n' +
                'FROM OrganizationWideDefault\nORDER BY SobjectType\n```\n' +
                '*(Enable "Use Tooling API" checkbox in Developer Console Query Editor)*';

            return result;
        } catch (Exception e) {
            return '❌ Error reading sharing info: ' + e.getMessage();
        }
    }

    // ── Permission Sets ───────────────────────────────────────────────────────────
    private static String getPermissionSets() {
        List<PermissionSet> ps = [
            SELECT Id, Label, Name, IsCustom, Description, CreatedDate
            FROM PermissionSet
            WHERE IsOwnedByProfile = FALSE
            ORDER BY Label
            LIMIT 50
        ];
        if (ps.isEmpty())
            return '📋 No custom permission sets found.';
        String result =
            '## 🛡 Permission Sets (' +
            ps.size() +
            ')\n\n| Label | API Name | Custom | Created |\n|---|---|---|---|\n';
        for (PermissionSet p : ps)
            result +=
                '| **' +
                p.Label +
                '** | `' +
                p.Name +
                '` | ' +
                (p.IsCustom ? '✅' : '') +
                ' | ' +
                String.valueOf(p.CreatedDate).substring(0, 10) +
                ' |\n';
        return result;
    }

    // ── Permission Set Groups ─────────────────────────────────────────────────────
    private static String getPermissionSetGroups() {
        List<PermissionSetGroup> psg = [
            SELECT Id, MasterLabel, DeveloperName, Status
            FROM PermissionSetGroup
            ORDER BY MasterLabel
            LIMIT 50
        ];
        if (psg.isEmpty())
            return '📋 No permission set groups found.';
        String result =
            '## 🗂 Permission Set Groups (' +
            psg.size() +
            ')\n\n| Label | API Name | Status |\n|---|---|---|\n';
        for (PermissionSetGroup g : psg)
            result +=
                '| **' +
                g.MasterLabel +
                '** | `' +
                g.DeveloperName +
                '` | ' +
                g.Status +
                ' |\n';
        return result;
    }

    // ── Single Permission Set detail by name ──────────────────────────────────────
    private static String getPermissionSetDetail(String prompt) {
        try {
            // Extract the name from the prompt
            // Handles: "name equals X", "named X", "called X", "name = X", "label X"
            String searchName = extractQuotedOrKeywordValue(prompt);

            if (String.isBlank(searchName)) {
                return '❌ Please specify a permission set name. Example:\n' +
                    '"Show details of permission set SF AI Agent User"';
            }

            // Search by Label (partial, case-insensitive) OR Name
            List<PermissionSet> results = [
                SELECT
                    Id,
                    Label,
                    Name,
                    IsCustom,
                    Description,
                    CreatedDate,
                    LastModifiedDate,
                    CreatedBy.Name,
                    LastModifiedBy.Name,
                    PermissionsApiEnabled,
                    PermissionsAuthorApex,
                    PermissionsCustomizeApplication,
                    PermissionsManageUsers,
                    PermissionsModifyAllData,
                    PermissionsViewAllData,
                    License.Name
                FROM PermissionSet
                WHERE
                    IsOwnedByProfile = FALSE
                    AND (Label LIKE :('%' + searchName + '%')
                    OR Name LIKE :('%' + searchName + '%'))
                ORDER BY Label
                LIMIT 5
            ];

            if (results.isEmpty()) {
                return '❌ No permission set found matching **"' +
                    searchName +
                    '"**.\n\n' +
                    'Try: "List all permission sets" to see what\'s available.';
            }

            // If multiple matches, show a picker table
            if (results.size() > 1) {
                String table =
                    '## 🛡 Multiple Matches for "' +
                    searchName +
                    '"\n\n' +
                    '| Label | API Name | Custom |\n|---|---|---|\n';
                for (PermissionSet p : results) {
                    table +=
                        '| **' +
                        p.Label +
                        '** | `' +
                        p.Name +
                        '` | ' +
                        (p.IsCustom ? '✅' : '—') +
                        ' |\n';
                }
                table +=
                    '\n> Be more specific, e.g. "Show details of permission set ' +
                    results[0].Label +
                    '"';
                return table;
            }

            // Single match — show full detail card
            PermissionSet ps = results[0];

            String result =
                '## 🛡 Permission Set Detail\n\n' +
                '| Field | Value |\n|---|---|\n' +
                '| **Label** | ' +
                ps.Label +
                ' |\n' +
                '| **API Name** | `' +
                ps.Name +
                '` |\n' +
                '| **Custom** | ' +
                (ps.IsCustom ? '✅ Yes' : '— No') +
                ' |\n' +
                '| **Description** | ' +
                (String.isNotBlank(ps.Description) ? ps.Description : '—') +
                ' |\n' +
                '| **License** | ' +
                (ps.License != null ? ps.License.Name : '—') +
                ' |\n' +
                '| **Created Date** | ' +
                String.valueOf(ps.CreatedDate).substring(0, 10) +
                ' |\n' +
                '| **Created By** | ' +
                (ps.CreatedBy != null ? ps.CreatedBy.Name : '—') +
                ' |\n' +
                '| **Last Modified** | ' +
                String.valueOf(ps.LastModifiedDate).substring(0, 10) +
                ' |\n' +
                '| **Last Modified By** | ' +
                (ps.LastModifiedBy != null ? ps.LastModifiedBy.Name : '—') +
                ' |\n' +
                '| **Record ID** | `' +
                ps.Id +
                '` |\n\n' +
                '### Key Permissions\n\n' +
                '| Permission | Enabled |\n|---|---|\n' +
                '| API Enabled | ' +
                (ps.PermissionsApiEnabled ? '✅' : '❌') +
                ' |\n' +
                '| Author Apex | ' +
                (ps.PermissionsAuthorApex ? '✅' : '❌') +
                ' |\n' +
                '| Customize Application | ' +
                (ps.PermissionsCustomizeApplication ? '✅' : '❌') +
                ' |\n' +
                '| Manage Users | ' +
                (ps.PermissionsManageUsers ? '✅' : '❌') +
                ' |\n' +
                '| Modify All Data | ' +
                (ps.PermissionsModifyAllData ? '✅' : '❌') +
                ' |\n' +
                '| View All Data | ' +
                (ps.PermissionsViewAllData ? '✅' : '❌') +
                ' |\n';

            return result;
        } catch (Exception e) {
            return '❌ Error fetching permission set: ' + e.getMessage();
        }
    }

    // ── Utility: extract value after keywords like "named", "called", "equals", "=" ──
    private static String extractQuotedOrKeywordValue(String prompt) {
        // Try quoted value first — "SF AI Agent User" or 'SF AI Agent User'
        Pattern quoted = Pattern.compile('["\']([^"\']+)["\']');
        Matcher qm = quoted.matcher(prompt);
        if (qm.find())
            return qm.group(1).trim();

        // Try keyword patterns: "equals X", "named X", "called X", "name = X", "label X"
        String lp = prompt.toLowerCase();
        List<String> keywords = new List<String>{
            'name equals ',
            'name = ',
            'named ',
            'called ',
            'label equals ',
            'label = ',
            'detail of ',
            'details of ',
            'detail for ',
            'details for ',
            'full detail of ',
            'full details of ',
            'info on ',
            'info about ',
            'about ',
            'for '
        };

        for (String kw : keywords) {
            Integer idx = lp.indexOf(kw);
            if (idx >= 0) {
                String remainder = prompt.substring(idx + kw.length()).trim();
                // Take up to end or next punctuation
                remainder = remainder.replaceAll('[?!.]$', '').trim();
                if (String.isNotBlank(remainder))
                    return remainder;
            }
        }

        return null;
    }

    // ── Profiles ──────────────────────────────────────────────────────────────────
    private static String getProfiles() {
        List<Profile> profiles = [
            SELECT Id, Name, UserType
            FROM Profile
            ORDER BY Name
            LIMIT 50
        ];
        String result =
            '## 👥 Profiles (' +
            profiles.size() +
            ')\n\n| Name | User Type |\n|---|---|\n';
        for (Profile p : profiles)
            result += '| **' + p.Name + '** | ' + p.UserType + ' |\n';
        return result;
    }

    // ── Roles ─────────────────────────────────────────────────────────────────────
    private static String getUserRoles() {
        List<UserRole> roles = [
            SELECT Id, Name, DeveloperName, ParentRoleId
            FROM UserRole
            ORDER BY Name
            LIMIT 50
        ];
        String result =
            '## 🏢 User Roles (' +
            roles.size() +
            ')\n\n| Name | API Name | Has Parent |\n|---|---|---|\n';
        for (UserRole r : roles)
            result +=
                '| **' +
                r.Name +
                '** | `' +
                r.DeveloperName +
                '` | ' +
                (r.ParentRoleId != null ? '✅' : '') +
                ' |\n';
        return result;
    }

    // ── Picklist VALUES for a specific field ──────────────────────────────────────
    private static String getPicklistValues(String prompt) {
        String objectName = extractObjectName(prompt);
        String fieldName = extractFieldName(prompt);

        if (String.isBlank(objectName) || String.isBlank(fieldName))
            return '❌ Please specify both object and field. Example:\n"Show picklist values for Account.Industry"\n"picklist values of Opportunity.StageName"';

        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null)
                return '❌ Object `' + objectName + '` not found.';

            Schema.SObjectField fld = sot.getDescribe()
                .fields.getMap()
                .get(fieldName);
            if (fld == null)
                return '❌ Field `' +
                    fieldName +
                    '` not found on `' +
                    objectName +
                    '`.';

            List<Schema.PicklistEntry> entries = fld.getDescribe()
                .getPicklistValues();
            if (entries.isEmpty())
                return '⚠️ `' +
                    fieldName +
                    '` has no picklist values or is not a picklist field.';

            String result =
                '## 🎨 Picklist: `' +
                objectName +
                '.' +
                fieldName +
                '`\n\n**Total:** ' +
                entries.size() +
                ' values\n\n' +
                '| Label | API Value | Active | Default |\n|---|---|---|---|\n';
            for (Schema.PicklistEntry e : entries)
                result +=
                    '| ' +
                    e.getLabel() +
                    ' | `' +
                    e.getValue() +
                    '` | ' +
                    (e.isActive() ? '✅' : '❌') +
                    ' | ' +
                    (e.isDefaultValue() ? '⭐' : '') +
                    ' |\n';
            return result;
        } catch (Exception e) {
            return '❌ Error: ' + e.getMessage();
        }
    }

    // ── Picklist FIELDS on an object ──────────────────────────────────────────────
    private static String getPicklistFields(String prompt) {
        String objectName = extractObjectName(prompt);
        if (String.isBlank(objectName))
            return '❌ Please specify an object. Example: "Show picklist fields on Account"';

        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null)
                return '❌ Object `' + objectName + '` not found.';

            Map<String, Schema.SObjectField> allFields = sot.getDescribe()
                .fields.getMap();
            List<String> picklistFields = new List<String>();
            Map<String, String> fieldLabels = new Map<String, String>();

            for (String fn : allFields.keySet()) {
                Schema.DescribeFieldResult dfr = allFields.get(fn)
                    .getDescribe();
                if (
                    dfr.getType() == Schema.DisplayType.PICKLIST ||
                    dfr.getType() == Schema.DisplayType.MULTIPICKLIST
                ) {
                    picklistFields.add(fn);
                    fieldLabels.put(fn, dfr.getLabel());
                }
            }

            if (picklistFields.isEmpty())
                return '📋 No picklist fields found on `' + objectName + '`.';

            picklistFields.sort();
            String result =
                '## 🎨 Picklist Fields — `' +
                objectName +
                '` (' +
                picklistFields.size() +
                ')\n\n' +
                '| Field Label | Field API Name | Type |\n|---|---|---|\n';
            for (String fn : picklistFields) {
                Schema.DescribeFieldResult dfr = allFields.get(fn)
                    .getDescribe();
                result +=
                    '| ' +
                    fieldLabels.get(fn) +
                    ' | `' +
                    fn +
                    '` | ' +
                    dfr.getType() +
                    ' |\n';
            }
            return result;
        } catch (Exception e) {
            return '❌ Error: ' + e.getMessage();
        }
    }

    // ── Custom objects ────────────────────────────────────────────────────────────
    private static String listCustomObjects() {
        List<EntityDefinition> objs = [
            SELECT QualifiedApiName, Label
            FROM EntityDefinition
            WHERE QualifiedApiName LIKE '%__c' AND IsDeprecatedAndHidden = FALSE
            ORDER BY QualifiedApiName
            LIMIT 100
        ];
        if (objs.isEmpty())
            return '📋 No custom objects found.';
        String result =
            '## 📦 Custom Objects (' +
            objs.size() +
            ')\n\n| Label | API Name |\n|---|---|\n';
        for (EntityDefinition o : objs)
            result += '| ' + o.Label + ' | `' + o.QualifiedApiName + '` |\n';
        return result;
    }

    // ── Installed packages ────────────────────────────────────────────────────────
    private static String getInstalledPackages() {
        List<PackageLicense> pkgs = [
            SELECT
                AllowedLicenses,
                UsedLicenses,
                ExpirationDate,
                NamespacePrefix
            FROM PackageLicense
            ORDER BY NamespacePrefix
        ];
        if (pkgs.isEmpty())
            return '📋 No installed managed packages found.';
        String result =
            '## 📦 Installed Packages (' +
            pkgs.size() +
            ')\n\n| Namespace | Used | Allowed | Expires |\n|---|---|---|---|\n';
        for (PackageLicense p : pkgs)
            result +=
                '| `' +
                p.NamespacePrefix +
                '` | ' +
                p.UsedLicenses +
                ' | ' +
                p.AllowedLicenses +
                ' | ' +
                (p.ExpirationDate != null
                    ? String.valueOf(p.ExpirationDate)
                    : 'Never') +
                ' |\n';
        return result;
    }

    // ── Flows ─────────────────────────────────────────────────────────────────────
    private static String getFlows() {
        List<FlowDefinitionView> flows = [
            SELECT ApiName, Label, ProcessType, IsActive
            FROM FlowDefinitionView
            ORDER BY Label
            LIMIT 100
        ];
        if (flows.isEmpty())
            return '📋 No flows found.';
        String result =
            '## ⚡ Flows (' +
            flows.size() +
            ')\n\n| Label | API Name | Type | Active |\n|---|---|---|---|\n';
        for (FlowDefinitionView f : flows)
            result +=
                '| **' +
                f.Label +
                '** | `' +
                f.ApiName +
                '` | ' +
                f.ProcessType +
                ' | ' +
                (f.IsActive ? '✅' : '❌') +
                ' |\n';
        return result;
    }

    // ── Apex classes ──────────────────────────────────────────────────────────────
    private static String getApexClasses() {
        List<ApexClass> classes = [
            SELECT Id, Name, Status, IsValid, LastModifiedDate
            FROM ApexClass
            ORDER BY Name
            LIMIT 100
        ];
        String result =
            '## ⚙️ Apex Classes (' +
            classes.size() +
            ')\n\n| Name | Status | Valid | Last Modified |\n|---|---|---|---|\n';
        for (ApexClass c : classes)
            result +=
                '| `' +
                c.Name +
                '` | ' +
                c.Status +
                ' | ' +
                (c.IsValid ? '✅' : '❌') +
                ' | ' +
                String.valueOf(c.LastModifiedDate).substring(0, 10) +
                ' |\n';
        return result;
    }

    // ── Validation rules ──────────────────────────────────────────────────────────
    private static String getValidationRules(String prompt) {
        try {
            String objectName = extractObjectName(prompt);

            // ValidationRule is a Tooling API object — not queryable in standard Apex SOQL.
            // We use a workaround: query via Database.query with the Tooling-compatible object
            // that IS accessible in some orgs. If not accessible, we return a helpful message.

            String soql =
                'SELECT Id, ValidationName, Active, ErrorMessage, ' +
                'EntityDefinitionId ' +
                'FROM ValidationRule';

            if (String.isNotBlank(objectName)) {
                // Get the entity definition ID for the object
                List<EntityDefinition> eds = [
                    SELECT Id, QualifiedApiName
                    FROM EntityDefinition
                    WHERE QualifiedApiName = :objectName
                    LIMIT 1
                ];
                if (!eds.isEmpty()) {
                    soql += ' WHERE EntityDefinitionId = \'' + eds[0].Id + '\'';
                }
            }
            soql += ' ORDER BY ValidationName LIMIT 50';

            List<SObject> rules = Database.query(soql);

            if (rules.isEmpty()) {
                return '📋 No validation rules found' +
                    (String.isNotBlank(objectName)
                        ? ' for `' + objectName + '`'
                        : '') +
                    '.';
            }

            String result =
                '## ✅ Validation Rules (' +
                rules.size() +
                ')' +
                (String.isNotBlank(objectName)
                    ? ' — `' + objectName + '`'
                    : '') +
                '\n\n' +
                '| Name | Active | Error Message |\n|---|---|---|\n';

            for (SObject r : rules) {
                String name = (String) r.get('ValidationName');
                Boolean active = (Boolean) r.get('Active');
                String msg = (String) r.get('ErrorMessage');
                if (msg != null && msg.length() > 60)
                    msg = msg.substring(0, 57) + '...';
                result +=
                    '| `' +
                    name +
                    '` | ' +
                    (active ? '✅' : '❌') +
                    ' | ' +
                    (msg != null ? msg : '') +
                    ' |\n';
            }
            return result;
        } catch (QueryException qe) {
            // ValidationRule not accessible in this context — provide setup instructions
            return '## ✅ Validation Rules\n\n' +
                '⚠️ **Validation rules require Tooling API access** which isn\'t available in standard Apex.\n\n' +
                '**To view validation rules, go to:**\n' +
                '- Setup → Object Manager → Select Object → Validation Rules\n\n' +
                '**Or use this SOQL in Tooling API (Developer Console → Query Editor → Use Tooling API checkbox):**\n\n' +
                '```soql\nSELECT Id, ValidationName, Active, ErrorMessage, EntityDefinition.QualifiedApiName\n' +
                'FROM ValidationRule\n' +
                (String.isNotBlank(extractObjectName(prompt))
                    ? 'WHERE EntityDefinition.QualifiedApiName = \'' +
                      extractObjectName(prompt) +
                      '\'\n'
                    : '') +
                'ORDER BY ValidationName\n```';
        } catch (Exception e) {
            return '❌ Error: ' + e.getMessage();
        }
    }

    // ── Record types ──────────────────────────────────────────────────────────────
    private static String getRecordTypes(String prompt) {
        String objectName = extractObjectName(prompt);
        String soql = 'SELECT Id, Name, DeveloperName, SobjectType, IsActive FROM RecordType';
        if (String.isNotBlank(objectName))
            soql +=
                ' WHERE SobjectType = \'' +
                String.escapeSingleQuotes(objectName) +
                '\'';
        soql += ' ORDER BY SobjectType, Name LIMIT 100';
        List<RecordType> rts = Database.query(soql);
        if (rts.isEmpty())
            return '📋 No record types found' +
                (String.isNotBlank(objectName)
                    ? ' for `' + objectName + '`'
                    : '') +
                '.';
        String result =
            '## 📋 Record Types (' +
            rts.size() +
            ')\n\n| Name | API Name | Object | Active |\n|---|---|---|---|\n';
        for (RecordType rt : rts)
            result +=
                '| **' +
                rt.Name +
                '** | `' +
                rt.DeveloperName +
                '` | ' +
                rt.SobjectType +
                ' | ' +
                (rt.IsActive ? '✅' : '❌') +
                ' |\n';
        return result;
    }

    // ── Active users ──────────────────────────────────────────────────────────────
    private static String getActiveUsers() {
        List<User> users = [
            SELECT Id, Name, Username, Profile.Name, LastLoginDate
            FROM User
            WHERE IsActive = TRUE
            ORDER BY Name
            LIMIT 50
        ];
        String result =
            '## 👥 Active Users (' +
            users.size() +
            ')\n\n| Name | Username | Profile | Last Login |\n|---|---|---|---|\n';
        for (User u : users)
            result +=
                '| **' +
                u.Name +
                '** | `' +
                u.Username +
                '` | ' +
                (u.Profile != null ? u.Profile.Name : '—') +
                ' | ' +
                (u.LastLoginDate != null
                    ? String.valueOf(u.LastLoginDate).substring(0, 10)
                    : 'Never') +
                ' |\n';
        return result;
    }

    // ── SOQL execution ────────────────────────────────────────────────────────────
    private static String executeSoqlAndFormat(String query) {
        try {
            String lower = query.trim().toLowerCase();

            // COUNT query
            if (lower.startsWith('select count(')) {
                Integer total = Database.countQuery(query);
                return '## 📊 Count Result\n\n```soql\n' +
                    query +
                    '\n```\n\n**Total Records:** ' +
                    total;
            }

            // ── Detect if query contains a subquery ──────────────────────────────
            Boolean hasSubquery =
                lower.contains('select id,') &&
                lower.contains('from ') &&
                query.indexOf('(') > 0 &&
                query.indexOf('(') < query.indexOf(')');

            if (hasSubquery) {
                return executeSubqueryAndFormat(query);
            }

            // ── Standard flat query ───────────────────────────────────────────────
            List<SObject> records = Database.query(query);
            if (records.isEmpty()) {
                return '## 🔍 No Records Found\n\n```soql\n' +
                    query +
                    '\n```\n\n*No records matched your criteria.*';
            }

            List<String> lines = new List<String>();
            lines.add('## 📋 Query Results\n\n```soql\n' + query + '\n```\n');

            Map<String, Object> firstFields = records[0]
                .getPopulatedFieldsAsMap();
            List<String> fieldNames = new List<String>(firstFields.keySet());

            Integer maxRows = Math.min(records.size(), 15);
            lines.add(
                '**Showing ' +
                    maxRows +
                    ' of ' +
                    records.size() +
                    ' records**\n'
            );

            String header = '| ';
            String sep = '|';
            for (String fn : fieldNames) {
                header += fn + ' | ';
                sep += '---|';
            }
            lines.add(header);
            lines.add(sep);

            for (Integer i = 0; i < maxRows; i++) {
                String row = '| ';
                for (String fn : fieldNames) {
                    row += formatFieldValue(records[i].get(fn)) + ' | ';
                }
                lines.add(row);
            }

            if (records.size() > maxRows)
                lines.add(
                    '\n*...and ' + (records.size() - maxRows) + ' more records*'
                );

            return String.join(lines, '\n');
        } catch (Exception e) {
            return '❌ **SOQL Error:** ' +
                e.getMessage() +
                '\n\n```soql\n' +
                query +
                '\n```';
        }
    }

    // ── Handles parent queries that contain child subqueries ──────────────────────
    private static String executeSubqueryAndFormat(String query) {
        try {
            List<SObject> parentRecords = Database.query(query);

            if (parentRecords.isEmpty()) {
                return '## 🔍 No Records Found\n\n```soql\n' +
                    query +
                    '\n```\n\n*No parent records matched.*';
            }

            List<String> lines = new List<String>();
            lines.add(
                '## 📋 Subquery Results\n\n```soql\n' + query + '\n```\n'
            );
            lines.add(
                '**' + parentRecords.size() + ' parent record(s) found**\n'
            );

            for (SObject parent : parentRecords) {
                // ── Parent fields ─────────────────────────────────────────────────
                // Use getSObjectType fields map to know what was queried
                String parentRow = '';
                Map<String, Object> parentFieldMap = parent.getPopulatedFieldsAsMap();

                for (String fn : parentFieldMap.keySet()) {
                    Object val = parentFieldMap.get(fn);
                    // Child subquery results are AggregateResult/List — skip
                    if (fn == 'attributes')
                        continue;
                    try {
                        if (val instanceof List<SObject>)
                            continue;
                        parentRow +=
                            '**' +
                            fn +
                            ':** `' +
                            formatFieldValue(val) +
                            '`   ';
                    } catch (Exception skip) {
                        continue;
                    }
                }
                lines.add('### 🔹 Parent — ' + parentRow.trim());

                // ── Child records ─────────────────────────────────────────────────
                for (String fn : parentFieldMap.keySet()) {
                    Object rawVal = parentFieldMap.get(fn);
                    if (!(rawVal instanceof List<SObject>))
                        continue;

                    List<SObject> children = (List<SObject>) rawVal;

                    lines.add(
                        '\n**↳ ' +
                            fn +
                            '** — ' +
                            children.size() +
                            ' child record(s)\n'
                    );

                    if (children.isEmpty()) {
                        lines.add('*No child records found.*\n');
                        continue;
                    }

                    // ── Extract child fields SAFELY ───────────────────────────────
                    // getPopulatedFieldsAsMap() on child records can throw if Apex
                    // tries to resolve fields not in the SELECT. We iterate keySet
                    // and catch per-field instead.
                    Set<String> childFieldSet = children[0]
                        .getPopulatedFieldsAsMap()
                        .keySet();
                    List<String> childFields = new List<String>();

                    for (String cf : childFieldSet) {
                        // Skip relationship/attributes meta keys
                        if (cf == 'attributes')
                            continue;
                        try {
                            // Probe the field on the first record — if it throws,
                            // this field wasn't actually selected, skip it
                            Object probe = children[0].get(cf);
                            childFields.add(cf);
                        } catch (SObjectException ex) {
                            // field not queried — skip silently
                        }
                    }

                    if (childFields.isEmpty()) {
                        lines.add('*Could not read child fields.*\n');
                        continue;
                    }

                    // Table header
                    String hdr = '| ';
                    String sep = '|';
                    for (String cf : childFields) {
                        hdr += cf + ' | ';
                        sep += '---|';
                    }
                    lines.add(hdr);
                    lines.add(sep);

                    // Table rows
                    Integer maxChild = Math.min(children.size(), 15);
                    for (Integer i = 0; i < maxChild; i++) {
                        String row = '| ';
                        for (String cf : childFields) {
                            String cellVal = '';
                            try {
                                cellVal = formatFieldValue(children[i].get(cf));
                            } catch (SObjectException ex) {
                                cellVal = '—';
                            }
                            row += cellVal + ' | ';
                        }
                        lines.add(row);
                    }

                    if (children.size() > maxChild)
                        lines.add(
                            '\n*...and ' +
                                (children.size() - maxChild) +
                                ' more*'
                        );

                    lines.add('');
                }

                lines.add('\n---\n');
            }

            return String.join(lines, '\n');
        } catch (Exception e) {
            return '❌ **Subquery Error:** ' +
                e.getMessage() +
                '\n\n```soql\n' +
                query +
                '\n```\n\n' +
                '💡 **Tip:** Try running this directly in Developer Console → Query Editor.';
        }
    }

    // ── OpenAI helpers ────────────────────────────────────────────────────────────
    private static String generateSoqlQuery(String prompt) {
        String sp =
            'You are a Salesforce SOQL generator. ' +
            'If the request asks for real Salesforce records/data, reply ONLY with a valid SOQL SELECT query. ' +
            'Otherwise reply with exactly: NO_QUERY';
        return stripCodeFences(callOpenAI(sp, prompt, 300, 0.0)).trim();
    }

    private static String callOpenAIChat(String prompt) {
        return callOpenAI(getSystemPrompt(), prompt, 1500, 0.2);
    }

    private static String callOpenAI(
        String systemPrompt,
        String userPrompt,
        Integer maxTokens,
        Decimal temperature
    ) {
        List<Map<String, String>> msgs = new List<Map<String, String>>();
        msgs.add(
            new Map<String, String>{
                'role' => 'system',
                'content' => systemPrompt
            }
        );
        msgs.add(
            new Map<String, String>{ 'role' => 'user', 'content' => userPrompt }
        );

        Map<String, Object> body = new Map<String, Object>();
        body.put('model', 'gpt-4o-mini');
        body.put('max_tokens', maxTokens);
        body.put('temperature', temperature);
        body.put('messages', msgs);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:LLM_API/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader(
            'Authorization',
            'Bearer {!$Credential.LLM_External.apiKey}'
        );
        req.setTimeout(120000);
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200)
            throw new AuraHandledException(
                'OpenAI error (' + res.getStatusCode() + '): ' + res.getBody()
            );

        Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(
            res.getBody()
        );
        List<Object> choices = (List<Object>) resp.get('choices');
        if (choices == null || choices.isEmpty())
            throw new AuraHandledException('No choices from OpenAI.');
        Map<String, Object> msg = (Map<String, Object>) ((Map<String, Object>) choices[0])
            .get('message');
        if (msg == null)
            throw new AuraHandledException('Null message from OpenAI.');
        return (String) msg.get('content');
    }

    // ── Utilities ─────────────────────────────────────────────────────────────────
    private static Boolean containsObjectName(String lp) {
        return lp.contains('account') ||
            lp.contains('contact') ||
            lp.contains('opportunity') ||
            lp.contains('lead') ||
            lp.contains('case') ||
            lp.contains('task') ||
            lp.contains('event') ||
            lp.contains('user') ||
            lp.contains('contract') ||
            lp.contains('order') ||
            lp.contains('product') ||
            lp.contains('asset') ||
            lp.contains('campaign') ||
            lp.contains('__c');
    }

    private static String extractObjectName(String prompt) {
        String lp = prompt.toLowerCase();
        List<String> stdObjects = new List<String>{
            'account',
            'contact',
            'opportunity',
            'lead',
            'case',
            'task',
            'event',
            'user',
            'contract',
            'order',
            'product2',
            'asset',
            'campaign',
            'quote',
            'pricebook2'
        };
        for (String o : stdObjects)
            if (lp.contains(o))
                return o.substring(0, 1).toUpperCase() + o.substring(1);
        Pattern p = Pattern.compile('\\b([A-Za-z][A-Za-z0-9_]*__c)\\b');
        Matcher m = p.matcher(prompt);
        if (m.find())
            return m.group(1);
        return null;
    }

    private static String extractFieldName(String prompt) {
        Pattern dotPat = Pattern.compile(
            '[A-Za-z][A-Za-z0-9_]*\\.([A-Za-z][A-Za-z0-9_]*(?:__c)?)'
        );
        Matcher dotM = dotPat.matcher(prompt);
        if (dotM.find())
            return dotM.group(1);
        String lp = prompt.toLowerCase();
        for (
            String kw : new List<String>{
                'for field ',
                'field ',
                'picklist ',
                'of field ',
                'values of ',
                'values for '
            }
        ) {
            Integer idx = lp.indexOf(kw);
            if (idx >= 0) {
                String rest = prompt.substring(idx + kw.length())
                        .trim()
                        .split(' ')[0]
                    .replaceAll('[^A-Za-z0-9_]', '');
                if (String.isNotBlank(rest))
                    return rest;
            }
        }
        return null;
    }

    private static Boolean isValidSelectQuery(String q) {
        if (String.isBlank(q) || q.equalsIgnoreCase('NO_QUERY'))
            return false;
        String lower = q.trim().toLowerCase();
        if (!lower.startsWith('select '))
            return false;
        for (
            String bad : new List<String>{
                ';',
                ' delete ',
                ' insert ',
                ' update ',
                ' upsert ',
                ' merge '
            }
        )
            if (lower.contains(bad))
                return false;
        return true;
    }

    private static String formatFieldValue(Object value) {
        if (value == null)
            return '';
        if (value instanceof DateTime)
            return ((DateTime) value).format('yyyy-MM-dd HH:mm');
        if (value instanceof Date)
            return ((Date) value).format();
        if (value instanceof Boolean)
            return ((Boolean) value) ? 'Yes' : 'No';
        String s = String.valueOf(value);
        return s.length() > 50 ? s.substring(0, 47) + '...' : s;
    }

    private static String stripCodeFences(String text) {
        if (text == null)
            return '';
        String r = text.trim();
        if (r.startsWith('```')) {
            Integer last = r.lastIndexOf('```');
            if (last > 0)
                r = r.substring(r.indexOf('\n') + 1, last).trim();
        }
        return r;
    }

    private static String getSystemPrompt() {
        return 'You are an expert Salesforce AI Agent. Answer precisely and only within Salesforce context.\n\n' +
            'You must always: \n' +
            '- Follow the user request exactly.\n' +
            '- Use Salesforce API names, object names, and field names when applicable.\n' +
            '- Format code in Markdown fenced code blocks with appropriate language hints.\n' +
            '- Use proper Markdown formatting for lists, tables, and emphasis.\n' +
            '- Structure responses clearly with headings, bullet points, and sections when appropriate.\n' +
            '- Keep responses concise but comprehensive.\n' +
            '- Do not add unrelated explanations or filler text.\n\n' +
            'Response formatting guidelines:\n' +
            '- Use **bold** for important terms and field names\n' +
            '- Use `backticks` for API names, code snippets, and values\n' +
            '- Use bullet points (-) for lists\n' +
            '- Use numbered lists for steps\n' +
            '- Use code blocks (```apex) for Apex code\n' +
            '- Use code blocks (```soql) for SOQL queries\n' +
            '- Use tables for structured data\n\n' +
            'You help Salesforce developers and admins with:\n\n' +
            '1. SOQL Queries — Generate precise SOQL to fetch records from any object. ' +
            'Always use proper filters, relevant fields, ORDER BY and LIMIT. Format in code blocks.\n\n' +
            '2. Object Metadata — Describe objects: fields with API names + data types, ' +
            'child relationships, parent lookups, record types.\n\n' +
            '3. Child Records — Write relationship SOQL using subqueries for parent-to-child ' +
            'and dot notation for child-to-parent queries.\n\n' +
            '4. Apex Code — Write production-quality Apex: triggers, classes, batch jobs, ' +
            'schedulers. Always bulkify, respect governor limits, include test class structure.\n\n' +
            '5. LWC — Write complete LWC: HTML, JS controller with @wire/NavigationMixin/toast, ' +
            'CSS, and meta XML.\n\n' +
            '6. Salesforce Concepts — Relationships, sharing rules, flows, permissions, deployment.\n\n' +
            'Answer in a concise, professional style suitable for Salesforce developers.';
    }
}
