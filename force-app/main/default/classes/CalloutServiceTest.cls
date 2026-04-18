/**
 * @description Test class for CalloutService.
 *              Covers the success path, full retry exhaustion (all 3 attempts fail),
 *              and the partial-retry path (first attempt fails, second succeeds).
 * @author Unit Testing Agent
 */
@isTest
private class CalloutServiceTest {
    // ─────────────────────────────────────────────────────────────────────────
    // Inner mock classes
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Stateless mock that always returns the configured status code
     *              and response body. Use this for pure-success and pure-failure
     *              scenarios where every callout attempt should get the same result.
     */
    private class FixedResponseMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;

        FixedResponseMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    /**
     * @description Stateful mock that returns a configurable sequence of status
     *              codes, one per callout attempt. Once the list is exhausted the
     *              last entry repeats. Use this to simulate "fail N times then
     *              succeed" scenarios.
     */
    private class SequentialResponseMock implements HttpCalloutMock {
        private final List<Integer> statusCodes;
        private final List<String> bodies;
        private Integer callIndex = 0;

        SequentialResponseMock(List<Integer> statusCodes, List<String> bodies) {
            this.statusCodes = statusCodes;
            this.bodies = bodies;
        }

        public HttpResponse respond(HttpRequest req) {
            Integer idx = Math.min(callIndex, statusCodes.size() - 1);
            callIndex++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCodes[idx]);
            res.setBody(bodies[idx]);
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constant verification
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Verifies the @TestVisible constants have the expected values
     *              so any accidental change is caught immediately.
     */
    @isTest
    static void testConstants_maxRetriesAndDelay() {
        Assert.areEqual(
            3,
            CalloutService.MAX_RETRIES,
            'MAX_RETRIES should be 3'
        );
        Assert.areEqual(
            5000,
            CalloutService.DELAY_MILLIS,
            'DELAY_MILLIS should be 5000 ms'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Success path
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Success path — the first callout returns HTTP 200.
     *              send() should return the response immediately without
     *              consuming any retry attempts.
     */
    @isTest
    static void testSend_firstAttemptSucceeds_returnsResponse() {
        String expectedBody = '{"id":1,"title":"test post"}';
        Test.setMock(
            HttpCalloutMock.class,
            new FixedResponseMock(200, expectedBody)
        );

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api',
            'GET',
            null
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Response should not be null on HTTP 200');
        Assert.areEqual(
            200,
            result.getStatusCode(),
            'Status code should be 200'
        );
        Assert.areEqual(
            expectedBody,
            result.getBody(),
            'Response body should match the mock body'
        );
    }

    /**
     * @description Success path with a non-null request body — verifies that the
     *              body is forwarded to the request and a 201 response (still 2xx)
     *              is treated as success.
     */
    @isTest
    static void testSend_postWith201_returnsResponse() {
        String requestBody = '{"title":"foo"}';
        String responseBody = '{"id":101,"title":"foo"}';
        Test.setMock(
            HttpCalloutMock.class,
            new FixedResponseMock(201, responseBody)
        );

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api/posts',
            'POST',
            requestBody
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Response should not be null on HTTP 201');
        Assert.areEqual(
            201,
            result.getStatusCode(),
            'Status code should be 201'
        );
        Assert.areEqual(
            responseBody,
            result.getBody(),
            'Response body should match'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // All retries exhausted
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description All 3 retry attempts return HTTP 500.
     *              send() should exhaust all retries and return null.
     */
    @isTest
    static void testSend_allRetriesFail500_returnsNull() {
        Test.setMock(
            HttpCalloutMock.class,
            new FixedResponseMock(500, 'Internal Server Error')
        );

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api',
            'GET',
            null
        );
        Test.stopTest();

        Assert.isNull(
            result,
            'Result should be null when all retries return a non-2xx status'
        );
    }

    /**
     * @description All 3 retry attempts return HTTP 404 (another non-2xx code).
     *              send() should exhaust all retries and return null.
     */
    @isTest
    static void testSend_allRetriesFail404_returnsNull() {
        Test.setMock(
            HttpCalloutMock.class,
            new FixedResponseMock(404, 'Not Found')
        );

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api/missing',
            'GET',
            null
        );
        Test.stopTest();

        Assert.isNull(
            result,
            'Result should be null when all retries return a non-2xx status'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Partial retry — fail then succeed
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description First attempt returns HTTP 500, second attempt returns HTTP 200.
     *              send() should return the successful response from the
     *              second attempt without requiring all MAX_RETRIES to be spent.
     */
    @isTest
    static void testSend_firstFailsThenSucceeds_returnsResponse() {
        String successBody = '{"id":42}';
        Test.setMock(
            HttpCalloutMock.class,
            new SequentialResponseMock(
                new List<Integer>{ 500, 200 },
                new List<String>{ 'Server Error', successBody }
            )
        );

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api',
            'GET',
            null
        );
        Test.stopTest();

        Assert.isNotNull(
            result,
            'Response should not be null when second attempt succeeds'
        );
        Assert.areEqual(
            200,
            result.getStatusCode(),
            'Status code should be 200 from the second attempt'
        );
        Assert.areEqual(
            successBody,
            result.getBody(),
            'Body should match the successful response'
        );
    }

    /**
     * @description First two attempts return HTTP 500, third attempt returns HTTP 200.
     *              send() should return the successful response from the
     *              third (final) attempt.
     */
    @isTest
    static void testSend_twoFailsThenSucceeds_returnsResponse() {
        String successBody = '{"status":"ok"}';
        Test.setMock(
            HttpCalloutMock.class,
            new SequentialResponseMock(
                new List<Integer>{ 500, 503, 200 },
                new List<String>{ 'Error', 'Unavailable', successBody }
            )
        );

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api',
            'PUT',
            '{"value":1}'
        );
        Test.stopTest();

        Assert.isNotNull(
            result,
            'Response should not be null when third attempt succeeds'
        );
        Assert.areEqual(
            200,
            result.getStatusCode(),
            'Status code should be 200 from the third attempt'
        );
        Assert.areEqual(
            successBody,
            result.getBody(),
            'Body should match the successful response'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Boundary: exact 2xx edges
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description HTTP 299 is the upper boundary of the 2xx range.
     *              send() should treat it as success and return the response.
     */
    @isTest
    static void testSend_status299_treatedAsSuccess() {
        Test.setMock(
            HttpCalloutMock.class,
            new FixedResponseMock(299, 'edge case')
        );

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api',
            'GET',
            null
        );
        Test.stopTest();

        Assert.isNotNull(result, 'HTTP 299 should be treated as success');
        Assert.areEqual(
            299,
            result.getStatusCode(),
            'Status code should be 299'
        );
    }

    /**
     * @description HTTP 300 is just outside the 2xx range.
     *              send() should treat it as failure and return null after
     *              all retries are exhausted.
     */
    @isTest
    static void testSend_status300_treatedAsFailure() {
        Test.setMock(
            HttpCalloutMock.class,
            new FixedResponseMock(300, 'Multiple Choices')
        );

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api',
            'GET',
            null
        );
        Test.stopTest();

        Assert.isNull(
            result,
            'HTTP 300 should be treated as failure and result in null after all retries'
        );
    }

    /**
     * @description Mock that always throws a CalloutException, simulating a
     *              network-level failure (e.g., DNS resolution error, connection
     *              timeout). Used to drive the catch block in send().
     */
    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            CalloutException ex = new CalloutException();
            ex.setMessage('Simulated network failure');
            throw ex;
        }
    }

    /**
     * @description Stateful mock that throws a CalloutException on the first
     *              call and returns HTTP 200 on every subsequent call. Used to
     *              verify the retry-after-exception path where recovery is
     *              possible within the retry budget.
     */
    private class ThrowThenSucceedMock implements HttpCalloutMock {
        private Integer callCount = 0;
        private final String successBody;

        ThrowThenSucceedMock(String successBody) {
            this.successBody = successBody;
        }

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            if (callCount == 1) {
                CalloutException ex = new CalloutException();
                ex.setMessage('Simulated network failure');
                throw ex;
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(successBody);
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Exception catch block coverage
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description All 3 retry attempts throw a CalloutException.
     *              send() should exhaust all retries via the catch block and
     *              return null.
     */
    @isTest
    static void testSend_exceptionOnAllRetries_returnsNull() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api',
            'GET',
            null
        );
        Test.stopTest();

        Assert.isNull(
            result,
            'Result should be null when all retries throw a CalloutException'
        );
    }

    /**
     * @description First attempt throws a CalloutException; second attempt
     *              returns HTTP 200. send() should recover via the retry loop
     *              and return the successful response.
     */
    @isTest
    static void testSend_exceptionThenSuccess_returnsResponse() {
        String successBody = '{"id":7,"title":"recovered"}';
        Test.setMock(
            HttpCalloutMock.class,
            new ThrowThenSucceedMock(successBody)
        );

        Test.startTest();
        HttpResponse result = CalloutService.send(
            'callout:ExampleService/api',
            'GET',
            null
        );
        Test.stopTest();

        Assert.isNotNull(
            result,
            'Response should not be null when second attempt succeeds after a thrown exception'
        );
        Assert.areEqual(
            200,
            result.getStatusCode(),
            'Status code should be 200 from the recovered attempt'
        );
        Assert.areEqual(
            successBody,
            result.getBody(),
            'Body should match the successful response body'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // sleep() utility
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Verifies that sleep() completes without throwing an exception.
     *              A zero-millisecond sleep is used to keep the test fast while
     *              still exercising the method entry/exit path.
     */
    @isTest
    static void testSleep_zeroMillis_completesWithoutException() {
        Test.startTest();
        try {
            CalloutService.sleep(0);
        } catch (Exception e) {
            Assert.fail(
                'sleep(0) should not throw an exception: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }
}
