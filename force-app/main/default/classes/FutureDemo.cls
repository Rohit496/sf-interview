public with sharing class FutureDemo {
    @future
    public static void futureMethod(String name) {
        System.debug('Hello, ' + name + '! This is a future method.');
    }
}
