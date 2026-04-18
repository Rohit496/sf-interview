public with sharing class CaseLookupAction {
    public class CaseRequest {
        @InvocableVariable(
            label='Case Number'
            description='The Salesforce Case Number to look up (e.g. 00001234)'
            required=true
        )
        public String caseNumber;
    }

    public class CaseResult {
        @InvocableVariable(
            label='Case Found'
            description='True if the case was found'
        )
        public Boolean caseFound;

        @InvocableVariable(
            label='Case ID'
            description='Salesforce record ID of the case'
        )
        public String caseId;

        @InvocableVariable(label='Subject' description='Case subject / title')
        public String subject;

        @InvocableVariable(
            label='Status'
            description='Current status of the case'
        )
        public String status;

        @InvocableVariable(
            label='Priority'
            description='Case priority: Low, Medium, High'
        )
        public String priority;

        @InvocableVariable(
            label='Owner Name'
            description='Full name of the case owner'
        )
        public String ownerName;

        @InvocableVariable(
            label='Description'
            description='Detailed description of the case'
        )
        public String description;

        @InvocableVariable(
            label='Account Name'
            description='Account associated with the case'
        )
        public String accountName;

        @InvocableVariable(
            label='Created Date'
            description='Date the case was created'
        )
        public String createdDate;

        @InvocableVariable(
            label='Last Modified Date'
            description='Date the case was last updated'
        )
        public String lastModifiedDate;

        @InvocableVariable(
            label='Error Message'
            description='Error details if lookup failed'
        )
        public String errorMessage;
    }

    @InvocableMethod(
        label='Get Case Details by Case Number'
        description='Retrieves full case details from Salesforce given a Case Number. Use this when the user asks about a specific case.'
        category='Case Management'
    )
    public static List<CaseResult> getCaseDetails(List<CaseRequest> requests) {
        System.debug('Received ' + requests.size() + ' case lookup requests.');
        // print the request details for debugging
        System.debug('Request details: ' + JSON.serializePretty(requests));
        List<CaseResult> results = new List<CaseResult>();

        for (CaseRequest req : requests) {
            CaseResult result = new CaseResult();
            try {
                List<Case> cases = [
                    SELECT
                        Id,
                        CaseNumber,
                        Subject,
                        Status,
                        Priority,
                        Owner.Name,
                        Description,
                        Account.Name,
                        CreatedDate,
                        LastModifiedDate
                    FROM Case
                    WHERE CaseNumber = :req.caseNumber.trim()
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];

                if (!cases.isEmpty()) {
                    Case c = cases[0];
                    result.caseFound = true;
                    result.caseId = c.Id;
                    result.subject = c.Subject;
                    result.status = c.Status;
                    result.priority = c.Priority;
                    result.ownerName = c.Owner?.Name;
                    result.description = c.Description;
                    result.accountName = c.Account?.Name;
                    result.createdDate = String.valueOf(c.CreatedDate.date());
                    result.lastModifiedDate = String.valueOf(
                        c.LastModifiedDate.date()
                    );
                    System.debug(
                        'Case found: ' +
                            c.CaseNumber +
                            ' - ' +
                            c.Subject +
                            ' - ' +
                            c.Status
                    ); // add the status to the debug log
                } else {
                    result.caseFound = false;
                    result.errorMessage =
                        'No case found with number: ' + req.caseNumber;
                }
            } catch (Exception e) {
                result.caseFound = false;
                result.errorMessage =
                    'Error retrieving case: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
}
