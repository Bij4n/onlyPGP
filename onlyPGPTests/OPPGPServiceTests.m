//
//  OPPGPServiceTests.m
//  onlyPGP
//
//  Created 2014. Tests for OPPGPService wrapper.
//

#import <XCTest/XCTest.h>
#import "OPPGPService.h"
#import "OPKeyStore.h"
#import "OPKey.h"
#import "OPMessage.h"

@interface OPPGPServiceTests : XCTestCase

@property (nonatomic, strong) OPPGPService *service;

@end

@implementation OPPGPServiceTests

- (void)setUp
{
    [super setUp];
    self.service = [OPPGPService sharedService];
    // Ensure a clean store for each test
    [[OPKeyStore sharedStore] setupDatabase];
    [[OPKeyStore sharedStore] deleteAllKeys];
}

- (void)tearDown
{
    [[OPKeyStore sharedStore] deleteAllKeys];
    [super tearDown];
}

#pragma mark - Singleton

- (void)testSharedService
{
    OPPGPService *s1 = [OPPGPService sharedService];
    OPPGPService *s2 = [OPPGPService sharedService];
    XCTAssertNotNil(s1, @"Shared service should not be nil");
    XCTAssertEqual(s1, s2, @"Shared service should return the same instance");
}

- (void)testServiceHasPGPInstance
{
    XCTAssertNotNil(self.service.pgp, @"Service should have an ObjectivePGP instance");
}

#pragma mark - Import errors

- (void)testImportInvalidKey
{
    NSError *error = nil;
    BOOL result = [self.service importKeyFromArmoredString:@"this is not a valid PGP key"
                                                    error:&error];
    XCTAssertFalse(result, @"Importing garbage should fail");
    XCTAssertNotNil(error, @"Should provide an error for invalid input");
}

- (void)testImportEmptyString
{
    NSError *error = nil;
    BOOL result = [self.service importKeyFromArmoredString:@""
                                                    error:&error];
    XCTAssertFalse(result, @"Importing empty string should fail");
}

- (void)testImportNilKey
{
    NSError *error = nil;
    BOOL result = [self.service importKeyFromArmoredString:nil
                                                    error:&error];
    XCTAssertFalse(result, @"Importing nil should fail");
}

- (void)testImportMalformedArmoredBlock
{
    // Has headers but no valid base64 payload
    NSString *malformed = @"-----BEGIN PGP PUBLIC KEY BLOCK-----\n\n"
                          @"not-valid-base64!!!\n"
                          @"-----END PGP PUBLIC KEY BLOCK-----";
    NSError *error = nil;
    BOOL result = [self.service importKeyFromArmoredString:malformed error:&error];
    XCTAssertFalse(result, @"Importing malformed armored block should fail");
}

#pragma mark - Export errors

- (void)testExportNonexistentKey
{
    NSError *error = nil;
    NSString *armored = [self.service exportArmoredPublicKeyForKeyID:@"DOESNOTEXIST0000"
                                                              error:&error];
    // Should either return nil or provide an error
    BOOL failed = (armored == nil || error != nil);
    XCTAssertTrue(failed, @"Exporting a nonexistent key should fail or return nil");
}

- (void)testExportSecretKeyNonexistent
{
    NSError *error = nil;
    NSString *armored = [self.service exportArmoredSecretKeyForKeyID:@"DOESNOTEXIST0000"
                                                              error:&error];
    BOOL failed = (armored == nil || error != nil);
    XCTAssertTrue(failed, @"Exporting nonexistent secret key should fail");
}

#pragma mark - Load from store

- (void)testLoadKeysFromStoreEmpty
{
    // Should not crash with an empty store
    XCTAssertNoThrow([self.service loadKeysFromStore],
                     @"loadKeysFromStore should not crash on empty store");
}

- (void)testLoadKeysFromStoreDoesNotCrash
{
    // Insert a key into the store first, then load
    OPKey *key = [[OPKey alloc] init];
    key.keyID = @"LOADTEST00000001";
    key.fingerprint = @"LOADTEST00000001LOADTEST00000001LOADTEST";
    key.algorithm = OPKeyAlgorithmRSA;
    key.keySize = 2048;
    key.creationDate = [NSDate date];
    key.isSecretKey = NO;
    key.userIDs = [NSMutableArray array];
    key.subkeys = [NSMutableArray array];
    key.signatures = [NSMutableArray array];
    key.armoredPublicKey = @"-----BEGIN PGP PUBLIC KEY BLOCK-----\nfake\n-----END PGP PUBLIC KEY BLOCK-----";
    [[OPKeyStore sharedStore] insertKey:key];

    XCTAssertNoThrow([self.service loadKeysFromStore],
                     @"loadKeysFromStore should not crash with keys in store");
}

#pragma mark - Encrypt errors

- (void)testEncryptWithNoRecipients
{
    NSError *error = nil;
    NSString *result = [self.service encryptMessage:@"Hello, world!"
                                   forRecipientIDs:@[]
                                        signWithID:nil
                                        passphrase:nil
                                             error:&error];
    BOOL failed = (result == nil || error != nil);
    XCTAssertTrue(failed, @"Encrypting with no recipients should fail");
}

- (void)testEncryptWithNilMessage
{
    NSError *error = nil;
    NSString *result = [self.service encryptMessage:nil
                                   forRecipientIDs:@[@"SOMEKEY000000001"]
                                        signWithID:nil
                                        passphrase:nil
                                             error:&error];
    BOOL failed = (result == nil || error != nil);
    XCTAssertTrue(failed, @"Encrypting nil message should fail");
}

- (void)testEncryptWithNonexistentRecipient
{
    NSError *error = nil;
    NSString *result = [self.service encryptMessage:@"Test message"
                                   forRecipientIDs:@[@"NOSUCHKEY0000001"]
                                        signWithID:nil
                                        passphrase:nil
                                             error:&error];
    BOOL failed = (result == nil || error != nil);
    XCTAssertTrue(failed, @"Encrypting to nonexistent recipient should fail");
}

#pragma mark - Decrypt errors

- (void)testDecryptInvalidMessage
{
    NSError *error = nil;
    OPMessage *result = [self.service decryptArmoredMessage:@"not a PGP message"
                                                passphrase:@"test"
                                                     error:&error];
    BOOL failed = (result == nil || error != nil);
    XCTAssertTrue(failed, @"Decrypting invalid message should fail");
}

- (void)testDecryptNilMessage
{
    NSError *error = nil;
    OPMessage *result = [self.service decryptArmoredMessage:nil
                                                passphrase:@"test"
                                                     error:&error];
    BOOL failed = (result == nil || error != nil);
    XCTAssertTrue(failed, @"Decrypting nil message should fail");
}

#pragma mark - Sign / Verify errors

- (void)testSignWithNonexistentKey
{
    NSError *error = nil;
    NSString *result = [self.service signMessage:@"Hello"
                                      withKeyID:@"NOSUCHKEY0000001"
                                     passphrase:@"test"
                                          error:&error];
    BOOL failed = (result == nil || error != nil);
    XCTAssertTrue(failed, @"Signing with nonexistent key should fail");
}

- (void)testVerifyInvalidSignedMessage
{
    NSError *error = nil;
    OPMessage *result = [self.service verifySignedMessage:@"not a signed message"
                                                   error:&error];
    BOOL failed = (result == nil || error != nil);
    XCTAssertTrue(failed, @"Verifying invalid signed message should fail");
}

@end
// onlypgp-wip
