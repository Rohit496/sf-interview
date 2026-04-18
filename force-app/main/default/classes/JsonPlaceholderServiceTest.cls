/**
 * @description Test class for JsonPlaceholderService and PostWrapper.
 *              Covers all branches of getPosts():
 *                - Happy path: HTTP 200 with a valid JSON array deserializes
 *                  into a List<PostWrapper> with all fields populated.
 *                - Error path: Non-200 HTTP status causes getPosts() to
 *                  throw an AuraHandledException.
 *                - Empty-body path: HTTP 200 with an empty JSON array "[]"
 *                  returns an empty list without error.
 *
 *              PostWrapper field coverage is validated through the happy-path
 *              test (userId, id, title, body are all asserted).
 *
 *              No @TestSetup is required — the class under test makes HTTP
 *              callouts and has no prerequisite SObject records.
 *
 * @see JsonPlaceholderService
 * @see PostWrapper
 */
@IsTest
private with sharing class JsonPlaceholderServiceTest {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    private static final Integer HTTP_200 = 200;
    private static final Integer HTTP_500 = 500;
    private static final Integer HTTP_404 = 404;

    /** Minimal valid JSON that mirrors a JSONPlaceholder API response item. */
    private static final String SINGLE_POST_JSON = '[{"userId":1,"id":42,"title":"Test Title","body":"Test body content."}]';

    /** Two-item JSON response used in the bulk-response test. */
    private static final String TWO_POST_JSON =
        '[' +
        '{"userId":1,"id":1,"title":"First Title","body":"First body."},' +
        '{"userId":2,"id":2,"title":"Second Title","body":"Second body."}' +
        ']';

    /** Empty JSON array — valid 200 response with no posts. */
    private static final String EMPTY_ARRAY_JSON = '[]';

    // -------------------------------------------------------------------------
    // Mock Implementations
    // -------------------------------------------------------------------------

    /**
     * @description Configurable HttpCalloutMock that returns a preset
     *              status code and response body for any HTTP request.
     */
    private class MockHttpCallout implements HttpCalloutMock {
        private final Integer statusCode;
        private final String responseBody;

        MockHttpCallout(Integer code, String body) {
            this.statusCode = code;
            this.responseBody = body;
        }

        public HttpResponse respond(HttpRequest req) {
            Assert.areEqual(
                'GET',
                req.getMethod(),
                'Service must use GET method'
            );
            Assert.areEqual(
                JsonPlaceholderService.ENDPOINT_POSTS,
                req.getEndpoint(),
                'Service must call the correct endpoint'
            );

            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    // =========================================================================
    // Happy path — HTTP 200, valid JSON array
    // =========================================================================

    /**
     * @description When the API returns HTTP 200 with a valid JSON array
     *              containing one post, getPosts() must return a non-null list
     *              of exactly one PostWrapper with all fields correctly
     *              deserialized (userId, id, title, body).
     */
    @IsTest
    static void getPosts_http200ValidSinglePost_returnsOnePostWithAllFields() {
        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpCallout(HTTP_200, SINGLE_POST_JSON)
        );

        Test.startTest();
        List<PostWrapper> posts = JsonPlaceholderService.getPosts();
        Test.stopTest();

        Assert.isNotNull(
            posts,
            'getPosts() must never return null on a 200 response'
        );
        Assert.areEqual(
            1,
            posts.size(),
            'Exactly one PostWrapper should be returned for a single-item JSON array'
        );

        PostWrapper post = posts[0];
        Assert.areEqual(1, post.userId, 'userId must be deserialized as 1');
        Assert.areEqual(42, post.id, 'id must be deserialized as 42');
        Assert.areEqual(
            'Test Title',
            post.title,
            'title must be deserialized correctly'
        );
        Assert.areEqual(
            'Test body content.',
            post.body,
            'body must be deserialized correctly'
        );
    }

    /**
     * @description When the API returns HTTP 200 with a two-item JSON array,
     *              getPosts() must return a list of two PostWrappers with each
     *              item's fields matching the corresponding JSON object.
     */
    @IsTest
    static void getPosts_http200ValidMultiplePosts_returnsAllPostsInOrder() {
        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpCallout(HTTP_200, TWO_POST_JSON)
        );

        Test.startTest();
        List<PostWrapper> posts = JsonPlaceholderService.getPosts();
        Test.stopTest();

        Assert.isNotNull(
            posts,
            'getPosts() must return a non-null list for a two-item response'
        );
        Assert.areEqual(
            2,
            posts.size(),
            'Two PostWrapper objects should be returned for a two-item JSON array'
        );

        Assert.areEqual(1, posts[0].userId, 'First post userId must be 1');
        Assert.areEqual(1, posts[0].id, 'First post id must be 1');
        Assert.areEqual(
            'First Title',
            posts[0].title,
            'First post title must match'
        );
        Assert.areEqual(
            'First body.',
            posts[0].body,
            'First post body must match'
        );

        Assert.areEqual(2, posts[1].userId, 'Second post userId must be 2');
        Assert.areEqual(2, posts[1].id, 'Second post id must be 2');
        Assert.areEqual(
            'Second Title',
            posts[1].title,
            'Second post title must match'
        );
        Assert.areEqual(
            'Second body.',
            posts[1].body,
            'Second post body must match'
        );
    }

    /**
     * @description When the API returns HTTP 200 with an empty JSON array,
     *              getPosts() must return an empty list (not null, no exception).
     */
    @IsTest
    static void getPosts_http200EmptyJsonArray_returnsEmptyList() {
        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpCallout(HTTP_200, EMPTY_ARRAY_JSON)
        );

        Test.startTest();
        List<PostWrapper> posts = JsonPlaceholderService.getPosts();
        Test.stopTest();

        Assert.isNotNull(
            posts,
            'getPosts() must return a non-null list even when the array is empty'
        );
        Assert.areEqual(
            0,
            posts.size(),
            'An empty JSON array must deserialize to an empty list, not null'
        );
    }

    // =========================================================================
    // Error path — non-200 HTTP status throws AuraHandledException
    // =========================================================================

    /**
     * @description When the API returns HTTP 500, getPosts() must throw an
     *              AuraHandledException whose message contains the status code.
     */
    @IsTest
    static void getPosts_http500_throwsCalloutExceptionWithStatusCode() {
        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpCallout(HTTP_500, 'Internal Server Error')
        );

        Test.startTest();
        try {
            List<PostWrapper> posts = JsonPlaceholderService.getPosts();
            Assert.fail(
                'An AuraHandledException should have been thrown for HTTP 500'
            );
        } catch (AuraHandledException ahe) {
            Assert.isTrue(
                ahe.getMessage().contains('500'),
                'AuraHandledException message must include the HTTP status code 500; got: ' +
                ahe.getMessage()
            );
        } catch (Exception e) {
            Assert.fail(
                'Expected AuraHandledException but caught: ' +
                    e.getTypeName() +
                    ' — ' +
                    e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description When the API returns HTTP 404, getPosts() must throw an
     *              AuraHandledException whose message contains the 404 status code.
     *              This verifies the non-200 branch fires for any non-200 code,
     *              not only 500.
     */
    @IsTest
    static void getPosts_http404_throwsCalloutExceptionWithStatusCode() {
        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpCallout(HTTP_404, 'Not Found')
        );

        Test.startTest();
        try {
            List<PostWrapper> posts = JsonPlaceholderService.getPosts();
            Assert.fail(
                'An AuraHandledException should have been thrown for HTTP 404'
            );
        } catch (AuraHandledException ahe) {
            Assert.isTrue(
                ahe.getMessage().contains('404'),
                'AuraHandledException message must include the HTTP status code 404; got: ' +
                ahe.getMessage()
            );
            Assert.isTrue(
                ahe.getMessage()
                    .startsWith(JsonPlaceholderService.ERROR_NON_200),
                'Exception message must start with the ERROR_NON_200 constant'
            );
        } catch (Exception e) {
            Assert.fail(
                'Expected AuraHandledException but caught: ' +
                    e.getTypeName() +
                    ' — ' +
                    e.getMessage()
            );
        }
        Test.stopTest();
    }

    // =========================================================================
    // Constant verification — @TestVisible static fields
    // =========================================================================

    /**
     * @description Verifies the @TestVisible constants on JsonPlaceholderService
     *              have the expected values, ensuring no accidental modification
     *              in production code changes the endpoint or method.
     */
    @IsTest
    static void constants_verifyExpectedValues() {
        Assert.areEqual(
            'callout:JsonPlaceholder/posts',
            JsonPlaceholderService.ENDPOINT_POSTS,
            'ENDPOINT_POSTS must use the JsonPlaceholder Named Credential'
        );
        Assert.areEqual(
            'GET',
            JsonPlaceholderService.HTTP_METHOD_GET,
            'HTTP_METHOD_GET must be the string GET'
        );
        Assert.areEqual(
            200,
            JsonPlaceholderService.HTTP_STATUS_OK,
            'HTTP_STATUS_OK must equal 200'
        );
        Assert.isTrue(
            JsonPlaceholderService.ERROR_NON_200.length() > 0,
            'ERROR_NON_200 must be a non-empty string'
        );
    }
}
