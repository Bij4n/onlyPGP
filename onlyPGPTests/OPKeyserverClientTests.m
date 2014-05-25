//
//  OPKeyserverClientTests.m
//  onlyPGP
//
//  Created 2014. Tests for OPKeyserverClient HKP operations.
//

#import <XCTest/XCTest.h>
#import "OPKeyserverClient.h"

@interface OPKeyserverClientTests : XCTestCase

@property (nonatomic, strong) OPKeyserverClient *client;

@end

@implementation OPKeyserverClientTests

- (void)setUp
{
    [super setUp];
    self.client = [OPKeyserverClient sharedClient];
}

- (void)tearDown
{
    // Reset to default URL in case a test changed it
    self.client.keyserverURL = @"https://pool.sks-keyservers.net";
    [super tearDown];
}

#pragma mark - Singleton

- (void)testSharedClient
{
    OPKeyserverClient *c1 = [OPKeyserverClient sharedClient];
    OPKeyserverClient *c2 = [OPKeyserverClient sharedClient];
    XCTAssertNotNil(c1, @"Shared client should not be nil");
    XCTAssertEqual(c1, c2, @"Shared client should be a singleton");
}

- (void)testClientHasManager
{
    XCTAssertNotNil(self.client.manager, @"Client should have an AFHTTPRequestOperationManager");
}

#pragma mark - Default configuration

- (void)testDefaultKeyserverURL
{
    NSString *url = self.client.keyserverURL;
    XCTAssertNotNil(url, @"Default keyserver URL should not be nil");
    // Should contain sks-keyservers.net or a known default
    BOOL containsExpected = ([url rangeOfString:@"sks-keyservers.net"].location != NSNotFound ||
                             [url rangeOfString:@"keyserver"].location != NSNotFound);
    XCTAssertTrue(containsExpected, @"Default URL should reference a known keyserver, got: %@", url);
}

#pragma mark - Custom URL

- (void)testSetCustomKeyserverURL
{
    NSString *customURL = @"https://keys.openpgp.org";
    self.client.keyserverURL = customURL;
    XCTAssertEqualObjects(self.client.keyserverURL, customURL,
                          @"Custom keyserver URL should persist");
}

- (void)testSetKeyserverURLDoesNotAffectManager
{
    self.client.keyserverURL = @"https://custom.keyserver.example.com";
    XCTAssertNotNil(self.client.manager,
                    @"Manager should still be valid after URL change");
}

#pragma mark - Search callback

- (void)testSearchCallsCompletion
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Search completion called"];

    [self.client searchForQuery:@"test@example.com"
                     completion:^(NSArray *results, NSError *error) {
        // In a unit test environment without network, we expect either
        // an error or empty results, but the callback must fire.
        XCTAssertTrue(results != nil || error != nil,
                      @"Completion should provide results or an error");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:15.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Search expectation timed out: %@", error);
        }
    }];
}

- (void)testSearchWithEmptyQuery
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Empty search completion"];

    [self.client searchForQuery:@""
                     completion:^(NSArray *results, NSError *error) {
        // Should handle gracefully -- either empty results or an error
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:15.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Empty search expectation timed out: %@", error);
        }
    }];
}

- (void)testSearchWithNilQuery
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Nil search completion"];

    [self.client searchForQuery:nil
                     completion:^(NSArray *results, NSError *error) {
        // Should handle nil gracefully
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:15.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Nil search timed out -- may be expected if nil is rejected synchronously");
        }
    }];
}

#pragma mark - Fetch callback

- (void)testFetchKeyCallsCompletion
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Fetch completion called"];

    [self.client fetchKeyWithID:@"0x1234567890ABCDEF"
                     completion:^(NSString *armoredKey, NSError *error) {
        // Without real network we expect error, but callback must fire
        XCTAssertTrue(armoredKey != nil || error != nil,
                      @"Fetch completion should provide key or error");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:15.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Fetch expectation timed out: %@", error);
        }
    }];
}

- (void)testFetchKeyWithInvalidID
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Invalid fetch completion"];

    [self.client fetchKeyWithID:@"not-a-real-keyid"
                     completion:^(NSString *armoredKey, NSError *error) {
        // Should result in error or nil key
        BOOL handledGracefully = (armoredKey == nil || error != nil);
        XCTAssertTrue(handledGracefully,
                      @"Fetching invalid key ID should fail gracefully");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:15.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Invalid fetch timed out: %@", error);
        }
    }];
}

#pragma mark - Upload callback

- (void)testUploadInvalidKey
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Upload completion called"];

    [self.client uploadKey:@"not a valid armored key"
                completion:^(BOOL success, NSError *error) {
        // Should fail
        XCTAssertTrue(!success || error != nil,
                      @"Uploading invalid key should fail");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:15.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Upload expectation timed out: %@", error);
        }
    }];
}

- (void)testKeyserverURLFormat
{
    // Verify the URL is a valid HTTPS URL
    NSString *url = self.client.keyserverURL;
    NSURL *parsed = [NSURL URLWithString:url];
    XCTAssertNotNil(parsed, @"Keyserver URL should be a valid URL");
    XCTAssertTrue([[parsed scheme] isEqualToString:@"https"] || [[parsed scheme] isEqualToString:@"http"],
                  @"Keyserver URL should use http or https scheme");
}

@end
// onlypgp-wip
