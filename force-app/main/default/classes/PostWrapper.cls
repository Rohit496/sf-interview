/**
 * @description Wrapper class representing a Post resource from the JSONPlaceholder API.
 *              Used for deserializing JSON responses from https://jsonplaceholder.typicode.com/posts.
 * @author Developer Agent
 * @date 2026-03-07
 */
public with sharing class PostWrapper {
    /** @description The ID of the user who created the post */
    @AuraEnabled
    public Integer userId { get; set; }

    /** @description The unique identifier of the post */
    @AuraEnabled
    public Integer id { get; set; }

    /** @description The title of the post */
    @AuraEnabled
    public String title { get; set; }

    /** @description The body content of the post */
    @AuraEnabled
    public String body { get; set; }
}
