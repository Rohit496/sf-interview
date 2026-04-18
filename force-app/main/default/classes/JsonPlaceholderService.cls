/**
 * @description Service class for making HTTP callouts to the JSONPlaceholder API.
 *              Retrieves post data and deserializes responses into PostWrapper objects.
 * @author Developer Agent
 * @date 2026-03-07
 */
public with sharing class JsonPlaceholderService {
    @TestVisible
    private static final String ENDPOINT_POSTS = 'callout:JsonPlaceholder/posts';

    @TestVisible
    private static final String HTTP_METHOD_GET = 'GET';

    @TestVisible
    private static final Integer HTTP_STATUS_OK = 200;

    @TestVisible
    private static final String HEADER_CONTENT_TYPE_NAME = 'Content-Type';

    @TestVisible
    private static final String HEADER_CONTENT_TYPE_VALUE = 'application/json';

    @TestVisible
    private static final String ERROR_NON_200 = 'Unexpected HTTP response status: ';

    /**
     * @description Retrieves all posts from the JSONPlaceholder API.
     * @return List of PostWrapper objects deserialized from the API response.
     * @throws AuraHandledException if the HTTP response status is not 200 or any unexpected error occurs (for LWC consumption).
     */
    @AuraEnabled(cacheable=true)
    public static List<PostWrapper> getPosts() {
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(ENDPOINT_POSTS);
            request.setMethod(HTTP_METHOD_GET);
            request.setHeader(
                HEADER_CONTENT_TYPE_NAME,
                HEADER_CONTENT_TYPE_VALUE
            );

            Http http = new Http();
            HttpResponse response = http.send(request);

            if (response.getStatusCode() != HTTP_STATUS_OK) {
                AuraHandledException ex = new AuraHandledException(
                    ERROR_NON_200 + response.getStatusCode()
                );
                ex.setMessage(ERROR_NON_200 + response.getStatusCode());
                throw ex;
            }

            List<PostWrapper> posts = (List<PostWrapper>) JSON.deserialize(
                response.getBody(),
                List<PostWrapper>.class
            );

            return posts;
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }
}
