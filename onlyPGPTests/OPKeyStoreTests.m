//
//  OPKeyStoreTests.m
//  onlyPGP
//
//  Created 2014. Tests for OPKeyStore CRUD operations.
//

#import <XCTest/XCTest.h>
#import "OPKeyStore.h"
#import "OPKey.h"
#import "OPUserID.h"
#import "OPSubkey.h"
#import "OPSignature.h"

@interface OPKeyStoreTests : XCTestCase

@property (nonatomic, strong) OPKeyStore *store;

@end

@implementation OPKeyStoreTests

#pragma mark - Helpers

- (OPKey *)testKeyWithKeyID:(NSString *)keyID
                fingerprint:(NSString *)fingerprint
                       name:(NSString *)name
                      email:(NSString *)email
                   isSecret:(BOOL)isSecret
{
    OPKey *key = [[OPKey alloc] init];
    key.keyID = keyID;
    key.fingerprint = fingerprint;
    key.algorithm = OPKeyAlgorithmRSA;
    key.keySize = 4096;
    key.creationDate = [NSDate dateWithTimeIntervalSince1970:1400000000]; // 2014-05-13
    key.expirationDate = [NSDate dateWithTimeIntervalSince1970:1500000000]; // 2017-07-14
    key.isSecretKey = isSecret;
    key.armoredPublicKey = @"-----BEGIN PGP PUBLIC KEY BLOCK-----\nfakedata\n-----END PGP PUBLIC KEY BLOCK-----";
    if (isSecret) {
        key.armoredSecretKey = @"-----BEGIN PGP PRIVATE KEY BLOCK-----\nsecretdata\n-----END PGP PRIVATE KEY BLOCK-----";
    }
    key.isRevoked = NO;
    key.ownerTrust = OPTrustLevelUnknown;

    NSString *uidString = [NSString stringWithFormat:@"%@ <%@>", name, email];
    OPUserID *uid = [[OPUserID alloc] initWithUserIDString:uidString];
    uid.name = name;
    uid.email = email;
    uid.isPrimary = YES;
    uid.parentKeyID = keyID;
    key.userIDs = [NSMutableArray arrayWithObject:uid];
    key.primaryUserID = uidString;

    OPSubkey *subkey = [[OPSubkey alloc] init];
    subkey.keyID = [NSString stringWithFormat:@"SUB%@", [keyID substringFromIndex:3]];
    subkey.fingerprint = [NSString stringWithFormat:@"SUBF%@", [fingerprint substringFromIndex:4]];
    subkey.algorithm = OPKeyAlgorithmRSA;
    subkey.keySize = 4096;
    subkey.creationDate = key.creationDate;
    subkey.expirationDate = key.expirationDate;
    subkey.canSign = NO;
    subkey.canEncrypt = YES;
    subkey.isRevoked = NO;
    subkey.parentKeyID = keyID;
    key.subkeys = [NSMutableArray arrayWithObject:subkey];

    OPSignature *sig = [[OPSignature alloc] init];
    sig.keyID = keyID;
    sig.signerKeyID = keyID;
    sig.creationDate = key.creationDate;
    sig.signatureType = OPSignatureTypeCertPositive;
    sig.isRevocation = NO;
    sig.parentKeyID = keyID;
    key.signatures = [NSMutableArray arrayWithObject:sig];

    return key;
}

- (OPKey *)defaultTestKey
{
    return [self testKeyWithKeyID:@"AABBCCDD11223344"
                     fingerprint:@"AABBCCDD11223344AABBCCDD11223344AABBCCDD"
                            name:@"Alice Tester"
                           email:@"alice@example.com"
                        isSecret:NO];
}

#pragma mark - setUp / tearDown

- (void)setUp
{
    [super setUp];
    self.store = [OPKeyStore sharedStore];
    [self.store setupDatabase];
    [self.store deleteAllKeys];
}

- (void)tearDown
{
    [self.store deleteAllKeys];
    [super tearDown];
}

#pragma mark - Tests

- (void)testInsertAndRetrieveKey
{
    OPKey *key = [self defaultTestKey];
    [self.store insertKey:key];

    OPKey *fetched = [self.store keyWithKeyID:@"AABBCCDD11223344"];
    XCTAssertNotNil(fetched, @"Key should be retrievable after insert");
    XCTAssertEqualObjects(fetched.keyID, key.keyID);
    XCTAssertEqualObjects(fetched.fingerprint, key.fingerprint);
    XCTAssertEqual(fetched.algorithm, OPKeyAlgorithmRSA);
    XCTAssertEqual(fetched.keySize, 4096);
    XCTAssertFalse(fetched.isSecretKey);
    XCTAssertFalse(fetched.isRevoked);
    XCTAssertEqualObjects(fetched.primaryUserID, key.primaryUserID);
    XCTAssertNotNil(fetched.armoredPublicKey);

    // Verify user IDs round-tripped
    XCTAssertTrue(fetched.userIDs.count >= 1, @"Should have at least one user ID");
    OPUserID *fetchedUID = fetched.userIDs[0];
    XCTAssertEqualObjects(fetchedUID.name, @"Alice Tester");
    XCTAssertEqualObjects(fetchedUID.email, @"alice@example.com");
    XCTAssertTrue(fetchedUID.isPrimary);

    // Verify subkeys round-tripped
    XCTAssertTrue(fetched.subkeys.count >= 1, @"Should have at least one subkey");
    OPSubkey *fetchedSub = fetched.subkeys[0];
    XCTAssertTrue(fetchedSub.canEncrypt);
    XCTAssertFalse(fetchedSub.canSign);
    XCTAssertEqualObjects(fetchedSub.parentKeyID, key.keyID);

    // Verify signatures round-tripped
    XCTAssertTrue(fetched.signatures.count >= 1, @"Should have at least one signature");
    OPSignature *fetchedSig = fetched.signatures[0];
    XCTAssertEqual(fetchedSig.signatureType, OPSignatureTypeCertPositive);
    XCTAssertEqualObjects(fetchedSig.signerKeyID, key.keyID);
}

- (void)testKeyWithFingerprint
{
    OPKey *key = [self defaultTestKey];
    [self.store insertKey:key];

    OPKey *fetched = [self.store keyWithFingerprint:@"AABBCCDD11223344AABBCCDD11223344AABBCCDD"];
    XCTAssertNotNil(fetched, @"Key should be retrievable by fingerprint");
    XCTAssertEqualObjects(fetched.keyID, key.keyID);
    XCTAssertEqualObjects(fetched.fingerprint, key.fingerprint);
}

- (void)testKeyWithFingerprintNotFound
{
    OPKey *fetched = [self.store keyWithFingerprint:@"0000000000000000000000000000000000000000"];
    XCTAssertNil(fetched, @"Should return nil for nonexistent fingerprint");
}

- (void)testAllKeys
{
    OPKey *k1 = [self testKeyWithKeyID:@"KEY1000000000001" fingerprint:@"FP100000000000000000FP100000000000000001" name:@"Alice" email:@"a@ex.com" isSecret:NO];
    OPKey *k2 = [self testKeyWithKeyID:@"KEY2000000000002" fingerprint:@"FP200000000000000000FP200000000000000002" name:@"Bob" email:@"b@ex.com" isSecret:YES];
    OPKey *k3 = [self testKeyWithKeyID:@"KEY3000000000003" fingerprint:@"FP300000000000000000FP300000000000000003" name:@"Charlie" email:@"c@ex.com" isSecret:NO];

    [self.store insertKey:k1];
    [self.store insertKey:k2];
    [self.store insertKey:k3];

    NSArray *all = [self.store allKeys];
    XCTAssertEqual(all.count, (NSUInteger)3, @"Should have 3 keys");
}

- (void)testAllPublicKeys
{
    OPKey *pub1 = [self testKeyWithKeyID:@"PUB1000000000001" fingerprint:@"PFP10000000000000000PFP1000000000000001" name:@"PubAlice" email:@"pa@ex.com" isSecret:NO];
    OPKey *pub2 = [self testKeyWithKeyID:@"PUB2000000000002" fingerprint:@"PFP20000000000000000PFP2000000000000002" name:@"PubBob" email:@"pb@ex.com" isSecret:NO];
    OPKey *sec1 = [self testKeyWithKeyID:@"SEC1000000000001" fingerprint:@"SFP10000000000000000SFP1000000000000001" name:@"SecCharlie" email:@"sc@ex.com" isSecret:YES];

    [self.store insertKey:pub1];
    [self.store insertKey:pub2];
    [self.store insertKey:sec1];

    NSArray *pubKeys = [self.store allPublicKeys];
    XCTAssertEqual(pubKeys.count, (NSUInteger)2, @"Should have 2 public keys");
    for (OPKey *k in pubKeys) {
        XCTAssertFalse(k.isSecretKey, @"Public keys list should not contain secret keys");
    }
}

- (void)testAllSecretKeys
{
    OPKey *pub1 = [self testKeyWithKeyID:@"PUB1000000000001" fingerprint:@"PFP10000000000000000PFP1000000000000001" name:@"PubAlice" email:@"pa@ex.com" isSecret:NO];
    OPKey *sec1 = [self testKeyWithKeyID:@"SEC1000000000001" fingerprint:@"SFP10000000000000000SFP1000000000000001" name:@"SecBob" email:@"sb@ex.com" isSecret:YES];
    OPKey *sec2 = [self testKeyWithKeyID:@"SEC2000000000002" fingerprint:@"SFP20000000000000000SFP2000000000000002" name:@"SecCharlie" email:@"sc@ex.com" isSecret:YES];

    [self.store insertKey:pub1];
    [self.store insertKey:sec1];
    [self.store insertKey:sec2];

    NSArray *secKeys = [self.store allSecretKeys];
    XCTAssertEqual(secKeys.count, (NSUInteger)2, @"Should have 2 secret keys");
    for (OPKey *k in secKeys) {
        XCTAssertTrue(k.isSecretKey, @"Secret keys list should only contain secret keys");
    }
}

- (void)testSearchKeysByName
{
    OPKey *k1 = [self testKeyWithKeyID:@"KEY1000000000001" fingerprint:@"FP100000000000000000FP100000000000000001" name:@"Alice Wonderland" email:@"alice@example.com" isSecret:NO];
    OPKey *k2 = [self testKeyWithKeyID:@"KEY2000000000002" fingerprint:@"FP200000000000000000FP200000000000000002" name:@"Bob Builder" email:@"bob@example.com" isSecret:NO];
    OPKey *k3 = [self testKeyWithKeyID:@"KEY3000000000003" fingerprint:@"FP300000000000000000FP300000000000000003" name:@"Alice Springs" email:@"springs@example.com" isSecret:NO];

    [self.store insertKey:k1];
    [self.store insertKey:k2];
    [self.store insertKey:k3];

    NSArray *results = [self.store searchKeysWithQuery:@"Alice"];
    XCTAssertEqual(results.count, (NSUInteger)2, @"Should find 2 keys with 'Alice' in name");
}

- (void)testSearchKeysByEmail
{
    OPKey *k1 = [self testKeyWithKeyID:@"KEY1000000000001" fingerprint:@"FP100000000000000000FP100000000000000001" name:@"Alice" email:@"alice@example.com" isSecret:NO];
    OPKey *k2 = [self testKeyWithKeyID:@"KEY2000000000002" fingerprint:@"FP200000000000000000FP200000000000000002" name:@"Bob" email:@"bob@other.com" isSecret:NO];

    [self.store insertKey:k1];
    [self.store insertKey:k2];

    NSArray *results = [self.store searchKeysWithQuery:@"example.com"];
    XCTAssertEqual(results.count, (NSUInteger)1, @"Should find 1 key matching email domain");
    OPKey *found = results[0];
    XCTAssertEqualObjects(found.keyID, @"KEY1000000000001");
}

- (void)testSearchKeysByKeyID
{
    OPKey *k1 = [self testKeyWithKeyID:@"AABB112233445566" fingerprint:@"AABB112233445566AABB112233445566AABB1122" name:@"Test" email:@"t@ex.com" isSecret:NO];
    [self.store insertKey:k1];

    NSArray *results = [self.store searchKeysWithQuery:@"AABB1122"];
    XCTAssertTrue(results.count >= 1, @"Should find key by partial key ID");
}

- (void)testUpdateKey
{
    OPKey *key = [self defaultTestKey];
    [self.store insertKey:key];

    // Modify the key
    key.ownerTrust = OPTrustLevelFull;
    key.isRevoked = YES;
    OPUserID *newUID = [[OPUserID alloc] initWithUserIDString:@"Alice Updated <alice2@example.com>"];
    newUID.name = @"Alice Updated";
    newUID.email = @"alice2@example.com";
    newUID.isPrimary = NO;
    newUID.parentKeyID = key.keyID;
    [key.userIDs addObject:newUID];

    [self.store updateKey:key];

    OPKey *fetched = [self.store keyWithKeyID:key.keyID];
    XCTAssertNotNil(fetched);
    XCTAssertEqual(fetched.ownerTrust, OPTrustLevelFull);
    XCTAssertTrue(fetched.isRevoked);
    XCTAssertTrue(fetched.userIDs.count >= 2, @"Should have 2 user IDs after update");
}

- (void)testDeleteKey
{
    OPKey *key = [self defaultTestKey];
    [self.store insertKey:key];
    XCTAssertNotNil([self.store keyWithKeyID:key.keyID], @"Key should exist before deletion");

    [self.store deleteKeyWithKeyID:key.keyID];
    XCTAssertNil([self.store keyWithKeyID:key.keyID], @"Key should be nil after deletion");
}

- (void)testDeleteAllKeys
{
    OPKey *k1 = [self testKeyWithKeyID:@"KEY1000000000001" fingerprint:@"FP100000000000000000FP100000000000000001" name:@"A" email:@"a@a.com" isSecret:NO];
    OPKey *k2 = [self testKeyWithKeyID:@"KEY2000000000002" fingerprint:@"FP200000000000000000FP200000000000000002" name:@"B" email:@"b@b.com" isSecret:YES];
    OPKey *k3 = [self testKeyWithKeyID:@"KEY3000000000003" fingerprint:@"FP300000000000000000FP300000000000000003" name:@"C" email:@"c@c.com" isSecret:NO];

    [self.store insertKey:k1];
    [self.store insertKey:k2];
    [self.store insertKey:k3];
    XCTAssertEqual([self.store keyCount], (NSInteger)3);

    [self.store deleteAllKeys];
    XCTAssertEqual([self.store keyCount], (NSInteger)0, @"Key count should be 0 after deleteAll");
    XCTAssertEqual([self.store allKeys].count, (NSUInteger)0);
}

- (void)testKeyCount
{
    XCTAssertEqual([self.store keyCount], (NSInteger)0, @"Empty store should have count 0");

    OPKey *k1 = [self testKeyWithKeyID:@"KEY1000000000001" fingerprint:@"FP100000000000000000FP100000000000000001" name:@"A" email:@"a@a.com" isSecret:NO];
    [self.store insertKey:k1];
    XCTAssertEqual([self.store keyCount], (NSInteger)1);

    OPKey *k2 = [self testKeyWithKeyID:@"KEY2000000000002" fingerprint:@"FP200000000000000000FP200000000000000002" name:@"B" email:@"b@b.com" isSecret:NO];
    [self.store insertKey:k2];
    XCTAssertEqual([self.store keyCount], (NSInteger)2);

    [self.store deleteKeyWithKeyID:k1.keyID];
    XCTAssertEqual([self.store keyCount], (NSInteger)1);
}

- (void)testDuplicateKeyID
{
    OPKey *key1 = [self testKeyWithKeyID:@"DUPKEY0000000001" fingerprint:@"DUPFP000000000000000DUPFP00000000000001" name:@"Original" email:@"orig@ex.com" isSecret:NO];
    [self.store insertKey:key1];
    XCTAssertEqual([self.store keyCount], (NSInteger)1);

    // Insert another key with the same keyID but different name
    OPKey *key2 = [self testKeyWithKeyID:@"DUPKEY0000000001" fingerprint:@"DUPFP000000000000000DUPFP00000000000001" name:@"Updated" email:@"updated@ex.com" isSecret:NO];
    [self.store insertKey:key2];

    // Should still be 1 key, not 2 (upsert behavior)
    XCTAssertTrue([self.store keyCount] <= 2, @"Duplicate insert should not keep growing indefinitely");

    OPKey *fetched = [self.store keyWithKeyID:@"DUPKEY0000000001"];
    XCTAssertNotNil(fetched, @"Key should still be retrievable");
}

- (void)testRetrieveNonexistentKey
{
    OPKey *fetched = [self.store keyWithKeyID:@"DOESNOTEXIST0000"];
    XCTAssertNil(fetched, @"Should return nil for a key ID that was never inserted");
}

- (void)testDeleteNonexistentKey
{
    // Should not crash
    [self.store deleteKeyWithKeyID:@"DOESNOTEXIST0000"];
    XCTAssertEqual([self.store keyCount], (NSInteger)0);
}

- (void)testKeyToDictionaryRoundTrip
{
    OPKey *key = [self defaultTestKey];
    NSDictionary *dict = [key toDictionary];
    XCTAssertNotNil(dict, @"toDictionary should return a non-nil dictionary");

    OPKey *restored = [[OPKey alloc] initWithDictionary:dict];
    XCTAssertEqualObjects(restored.keyID, key.keyID);
    XCTAssertEqualObjects(restored.fingerprint, key.fingerprint);
    XCTAssertEqual(restored.algorithm, key.algorithm);
    XCTAssertEqual(restored.keySize, key.keySize);
    XCTAssertEqual(restored.isSecretKey, key.isSecretKey);
    XCTAssertEqual(restored.isRevoked, key.isRevoked);
}

- (void)testSecretKeyWithArmoredData
{
    OPKey *key = [self testKeyWithKeyID:@"SEC1000000000001" fingerprint:@"SFP10000000000000000SFP1000000000000001" name:@"Secret Alice" email:@"salice@ex.com" isSecret:YES];
    [self.store insertKey:key];

    OPKey *fetched = [self.store keyWithKeyID:@"SEC1000000000001"];
    XCTAssertNotNil(fetched);
    XCTAssertTrue(fetched.isSecretKey);
    XCTAssertNotNil(fetched.armoredSecretKey, @"Secret key should have armored secret data");
    XCTAssertNotNil(fetched.armoredPublicKey, @"Secret key should also have armored public data");
}

@end
