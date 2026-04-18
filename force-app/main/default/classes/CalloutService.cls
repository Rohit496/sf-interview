/**
 * @description Service class for making HTTP callouts with retry logic.
 *              Retries up to MAX_RETRIES times with a delay between attempts
 *              when a non-2xx response or exception occurs.
 */
public with sharing class CalloutService {
    @TestVisible
    private static final Integer MAX_RETRIES = 3;

    @TestVisible
    private static final Integer DELAY_MILLIS = 5000;

    /**
     * @description Makes an HTTP callout with automatic retry on failure.
     * @param url The endpoint URL for the callout
     * @param method The HTTP method (GET, POST, PUT, DELETE, etc.)
     * @param body The request body (can be null for GET requests)
     * @return HttpResponse on success (2xx), null if all retries exhausted
     */
    public static HttpResponse send(String url, String method, String body) {
        Integer numAttempts = MAX_RETRIES;

        while (numAttempts > 0) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(url);
                req.setMethod(method);

                if (String.isNotBlank(body)) {
                    req.setBody(body);
                }

                Http http = new Http();
                HttpResponse res = http.send(req);

                Integer statusCode = res.getStatusCode();
                if (statusCode >= 200 && statusCode <= 299) {
                    return res;
                }

                numAttempts--;
                if (numAttempts > 0) {
                    sleep(DELAY_MILLIS);
                } else {
                    System.debug(
                        LoggingLevel.ERROR,
                        'CalloutService.send() - All retries exhausted. Non-2xx status: ' +
                            statusCode +
                            ' | Endpoint: ' +
                            url
                    );
                }
            } catch (Exception e) {
                numAttempts--;
                if (numAttempts > 0) {
                    sleep(DELAY_MILLIS);
                } else {
                    System.debug(
                        LoggingLevel.ERROR,
                        'CalloutService.send() - All retries exhausted. Exception: ' +
                            e.getMessage() +
                            ' | Endpoint: ' +
                            url
                    );
                }
            }
        }

        return null;
    }

    /**
     * @description Busy-wait sleep implementation using a DateTime loop.
     *              Used to introduce delay between retry attempts.
     * @param millis The number of milliseconds to sleep
     */
    @TestVisible
    private static void sleep(Integer millis) {
        Long startTime = DateTime.now().getTime();
        while (DateTime.now().getTime() - startTime < millis) {
            // Busy-wait
        }
    }
}
