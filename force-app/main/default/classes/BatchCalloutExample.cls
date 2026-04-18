global class BatchCalloutExample implements Database.Batchable<sObject>, Database.AllowsCallouts {
    private String message;

    // constructor
    public BatchCalloutExample(String message) {
        this.message = message;
        System.debug('Constructor called with message: ' + message);
    }
    global Database.QueryLocator start(Database.BatchableContext BC) {
        system.debug('Callout from start method');
        // print the message passed to the constructor
        system.debug('Message: ' + message);

        calloutMethod();
        calloutMethod();
        String query = 'SELECT Id, Name FROM Account';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Account> accList) {
        system.debug('Callout from execute method');
        calloutMethod();
        calloutMethod();
        // FutureDemo.futureMethod('BatchCalloutExample');
    }

    global void finish(Database.BatchableContext BC) {
        system.debug('Callout from finish method');
        calloutMethod();
        calloutMethod();
    }

    void calloutMethod() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            'https://th-apex-http-callout.herokuapp.com/animals'
        );
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json;charset=UTF-8');
        request.setBody('{"name":"mighty moose"}');
        request.setTimeout(10000);

        HttpResponse response;

        try {
            response = http.send(request);
        } catch (System.CalloutException e) {
            System.debug('Callout failed (network/timeout): ' + e.getMessage());
            return;
        }

        Integer statusCode = response.getStatusCode();

        if (statusCode >= 200 && statusCode < 300) {
            System.debug('Success: ' + response.getBody());
        } else if (statusCode == 401 || statusCode == 403) {
            System.debug(
                'Auth error ' + statusCode + ': ' + response.getStatus()
            );
        } else if (statusCode == 404) {
            System.debug('Resource not found: ' + response.getStatus());
        } else if (statusCode >= 500) {
            System.debug(
                'Server error ' + statusCode + ': ' + response.getBody()
            );
        } else {
            System.debug(
                'Unexpected status ' + statusCode + ': ' + response.getStatus()
            );
        }
    }
}
