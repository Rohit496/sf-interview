// HttpResponse res = CalloutService.send(
//     'callout:JsonPlaceholder/posts/1',
//     'GET',
//     null
// );
// if (res != null) {
//     System.debug(res.getStatusCode());
//     System.debug(res.getBody());
// } else {
//     System.debug('All retries exhausted - no response');
// }

AccountInsertService.insertAccount('Test Account2');
