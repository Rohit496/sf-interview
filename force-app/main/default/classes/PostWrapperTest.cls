/**
 * @description Test class for PostWrapper.
 *              PostWrapper is a plain data-holder class with four @AuraEnabled
 *              public properties (userId, id, title, body).  There is no
 *              business logic to branch through, so the goal here is to:
 *                - Confirm the class is instantiable.
 *                - Confirm every field is readable and writable.
 *                - Confirm default values for unset fields (Integer → null,
 *                  String → null).
 *
 *              Coverage is also achieved transitively through
 *              JsonPlaceholderServiceTest, but this class provides explicit,
 *              self-documenting coverage for PostWrapper in isolation.
 *
 * @see PostWrapper
 */
@IsTest
private with sharing class PostWrapperTest {
    // =========================================================================
    // Field assignment and retrieval
    // =========================================================================

    /**
     * @description Setting all four fields on a new PostWrapper instance and
     *              reading them back must return the exact values that were set.
     */
    @IsTest
    static void postWrapper_setAllFields_gettersReturnAssignedValues() {
        PostWrapper wrapper = new PostWrapper();
        wrapper.userId = 7;
        wrapper.id = 99;
        wrapper.title = 'Sample Title';
        wrapper.body = 'Sample body text for the post.';

        Assert.areEqual(
            7,
            wrapper.userId,
            'userId getter must return the assigned value 7'
        );
        Assert.areEqual(
            99,
            wrapper.id,
            'id getter must return the assigned value 99'
        );
        Assert.areEqual(
            'Sample Title',
            wrapper.title,
            'title getter must return the assigned string'
        );
        Assert.areEqual(
            'Sample body text for the post.',
            wrapper.body,
            'body getter must return the assigned string'
        );
    }

    /**
     * @description A freshly instantiated PostWrapper must have all fields
     *              defaulting to null (no implicit non-null defaults are set
     *              by the class).
     */
    @IsTest
    static void postWrapper_newInstance_allFieldsDefaultToNull() {
        PostWrapper wrapper = new PostWrapper();

        Assert.isNull(
            wrapper.userId,
            'userId must be null on a new PostWrapper instance'
        );
        Assert.isNull(
            wrapper.id,
            'id must be null on a new PostWrapper instance'
        );
        Assert.isNull(
            wrapper.title,
            'title must be null on a new PostWrapper instance'
        );
        Assert.isNull(
            wrapper.body,
            'body must be null on a new PostWrapper instance'
        );
    }

    /**
     * @description Fields must be independently overwritable. Assigning a new
     *              value to one field must not affect any other field.
     */
    @IsTest
    static void postWrapper_overwriteOneField_otherFieldsUnchanged() {
        PostWrapper wrapper = new PostWrapper();
        wrapper.userId = 1;
        wrapper.id = 10;
        wrapper.title = 'Original Title';
        wrapper.body = 'Original Body';

        // Overwrite only title
        wrapper.title = 'Updated Title';

        Assert.areEqual(
            1,
            wrapper.userId,
            'userId must remain 1 after overwriting title'
        );
        Assert.areEqual(
            10,
            wrapper.id,
            'id must remain 10 after overwriting title'
        );
        Assert.areEqual(
            'Updated Title',
            wrapper.title,
            'title must reflect the new value'
        );
        Assert.areEqual(
            'Original Body',
            wrapper.body,
            'body must remain unchanged after overwriting title'
        );
    }

    /**
     * @description Integer fields (userId, id) must accept zero as a valid
     *              value and return it exactly.
     */
    @IsTest
    static void postWrapper_integerFieldsSetToZero_returnZero() {
        PostWrapper wrapper = new PostWrapper();
        wrapper.userId = 0;
        wrapper.id = 0;

        Assert.areEqual(0, wrapper.userId, 'userId must support the value 0');
        Assert.areEqual(0, wrapper.id, 'id must support the value 0');
    }

    /**
     * @description String fields (title, body) must accept an empty string
     *              and distinguish it from null.
     */
    @IsTest
    static void postWrapper_stringFieldsSetToEmptyString_returnEmptyString() {
        PostWrapper wrapper = new PostWrapper();
        wrapper.title = '';
        wrapper.body = '';

        Assert.areEqual(
            '',
            wrapper.title,
            'title must distinguish empty string from null'
        );
        Assert.areEqual(
            '',
            wrapper.body,
            'body must distinguish empty string from null'
        );
    }
}
