public with sharing class OpportunityDatatableController {
    public class UpdateResult {
        @AuraEnabled
        public List<String> successIds;
        @AuraEnabled
        public List<ErrorItem> errors;

        public UpdateResult() {
            successIds = new List<String>();
            errors = new List<ErrorItem>();
        }
    }

    public class ErrorItem {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public List<String> fields;

        public ErrorItem(String id, String message, List<String> fields) {
            this.id = id;
            this.message = message;
            this.fields = fields;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities(Integer limitSize) {
        Integer fetch = (limitSize == null ||
            limitSize <= 0)
            ? 200
            : Math.min(limitSize, 2000);
        // Query only required fields; apply FLS for read
        List<Opportunity> raw = [
            SELECT Id, Name, StageName, CloseDate, Amount, LastModifiedDate
            FROM Opportunity
            ORDER BY LastModifiedDate DESC
            LIMIT :fetch
        ];

        // Enforce FLS on read
        SObjectAccessDecision access = Security.stripInaccessible(
            AccessType.READABLE,
            raw
        );
        return (List<Opportunity>) access.getRecords();
    }

    @AuraEnabled
    public static UpdateResult updateOpportunities(List<Opportunity> opps) {
        if (opps == null || opps.isEmpty()) {
            return new UpdateResult();
        }

        // Only allow updates to whitelisted fields
        List<Opportunity> candidates = new List<Opportunity>();
        for (Opportunity o : opps) {
            Opportunity upd = new Opportunity(Id = o.Id);
            // Guard against nulls: only set fields present in payload
            if (o.Name != null)
                upd.Name = o.Name;
            if (o.StageName != null)
                upd.StageName = o.StageName;
            if (o.CloseDate != null)
                upd.CloseDate = o.CloseDate;
            if (o.Amount != null)
                upd.Amount = o.Amount;
            candidates.add(upd);
        }

        // Enforce FLS on write (UPDATEable)
        SObjectAccessDecision writeAccess = Security.stripInaccessible(
            AccessType.UPDATABLE,
            candidates
        );
        List<SObject> sanitised = writeAccess.getRecords();

        UpdateResult result = new UpdateResult();
        if (sanitised.isEmpty()) {
            // No updatable fields available per FLS
            for (Opportunity original : opps) {
                result.errors.add(
                    new ErrorItem(
                        original.Id,
                        'No updatable fields available due to field-level security.',
                        new List<String>()
                    )
                );
            }
            return result;
        }

        // Perform DML with partial success
        Database.SaveResult[] srList = Database.update(sanitised, false);

        // Map results
        for (Integer i = 0; i < srList.size(); i++) {
            Database.SaveResult sr = srList[i];
            String recId = (String) sanitised[i].get('Id');
            if (sr.isSuccess()) {
                result.successIds.add(recId);
            } else {
                for (Database.Error e : sr.getErrors()) {
                    List<String> fieldNames = new List<String>();
                    if (e.getFields() != null) {
                        // Some Platform versions surface getFields() as a List<String> of API names rather than tokens.
                        // Normalize to API name strings safely.
                        for (Object fld : e.getFields()) {
                            if (fld instanceof Schema.SObjectField) {
                                Schema.DescribeFieldResult dfr = ((Schema.SObjectField) fld)
                                    .getDescribe();
                                fieldNames.add(dfr.getName());
                            } else if (fld instanceof String) {
                                fieldNames.add((String) fld);
                            } else {
                                fieldNames.add(String.valueOf(fld));
                            }
                        }
                    }
                    result.errors.add(
                        new ErrorItem(recId, e.getMessage(), fieldNames)
                    );
                }
            }
        }
        return result;
    }
}
