//
//  OPTrustCalculatorTests.m
//  onlyPGP
//
//  Created 2014. Tests for OPTrustCalculator web-of-trust logic.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "OPTrustCalculator.h"
#import "OPKey.h"
#import "OPSignature.h"
#import "OPUserID.h"
#import "OPSubkey.h"

@interface OPTrustCalculatorTests : XCTestCase

@property (nonatomic, strong) OPTrustCalculator *calculator;

@end

@implementation OPTrustCalculatorTests

#pragma mark - Helpers

- (OPKey *)keyWithKeyID:(NSString *)keyID
               isSecret:(BOOL)isSecret
              isRevoked:(BOOL)isRevoked
          expirationDate:(NSDate *)expirationDate
             ownerTrust:(OPTrustLevel)ownerTrust
             signatures:(NSArray *)signatures
{
    OPKey *key = [[OPKey alloc] init];
    key.keyID = keyID;
    key.fingerprint = [NSString stringWithFormat:@"%@%@%@", keyID, keyID, [keyID substringToIndex:8]];
    key.algorithm = OPKeyAlgorithmRSA;
    key.keySize = 4096;
    key.creationDate = [NSDate dateWithTimeIntervalSince1970:1400000000];
    key.expirationDate = expirationDate;
    key.isSecretKey = isSecret;
    key.isRevoked = isRevoked;
    key.ownerTrust = ownerTrust;
    key.armoredPublicKey = @"-----BEGIN PGP PUBLIC KEY BLOCK-----\nfake\n-----END PGP PUBLIC KEY BLOCK-----";
    if (isSecret) {
        key.armoredSecretKey = @"-----BEGIN PGP PRIVATE KEY BLOCK-----\nfake\n-----END PGP PRIVATE KEY BLOCK-----";
    }

    OPUserID *uid = [[OPUserID alloc] initWithUserIDString:[NSString stringWithFormat:@"Test User <%@@test.com>", keyID]];
    uid.isPrimary = YES;
    uid.parentKeyID = keyID;
    key.userIDs = [NSMutableArray arrayWithObject:uid];
    key.primaryUserID = uid.userIDString;

    key.subkeys = [NSMutableArray array];

    if (signatures) {
        key.signatures = [NSMutableArray arrayWithArray:signatures];
    } else {
        // Add self-signature by default
        OPSignature *selfSig = [[OPSignature alloc] init];
        selfSig.keyID = keyID;
        selfSig.signerKeyID = keyID;
        selfSig.creationDate = key.creationDate;
        selfSig.signatureType = OPSignatureTypeCertPositive;
        selfSig.isRevocation = NO;
        selfSig.parentKeyID = keyID;
        key.signatures = [NSMutableArray arrayWithObject:selfSig];
    }

    return key;
}

- (OPKey *)validPublicKeyWithKeyID:(NSString *)keyID
{
    // A normal, valid, non-expired public key with self-signature
    NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow:365 * 24 * 60 * 60];
    return [self keyWithKeyID:keyID
                     isSecret:NO
                    isRevoked:NO
                expirationDate:futureDate
                   ownerTrust:OPTrustLevelUnknown
                   signatures:nil];
}

- (OPKey *)secretKeyWithKeyID:(NSString *)keyID
{
    NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow:365 * 24 * 60 * 60];
    return [self keyWithKeyID:keyID
                     isSecret:YES
                    isRevoked:NO
                expirationDate:futureDate
                   ownerTrust:OPTrustLevelUnknown
                   signatures:nil];
}

- (OPSignature *)certificationSignatureFromKeyID:(NSString *)signerKeyID
                                      forKeyID:(NSString *)targetKeyID
{
    OPSignature *sig = [[OPSignature alloc] init];
    sig.keyID = targetKeyID;
    sig.signerKeyID = signerKeyID;
    sig.creationDate = [NSDate dateWithTimeIntervalSinceNow:-86400];
    sig.signatureType = OPSignatureTypeCertPositive;
    sig.isRevocation = NO;
    sig.parentKeyID = targetKeyID;
    return sig;
}

#pragma mark - setUp / tearDown

- (void)setUp
{
    [super setUp];
    self.calculator = [OPTrustCalculator sharedCalculator];
    // Reset to defaults
    self.calculator.marginalsNeeded = 3;
    self.calculator.completesNeeded = 1;
}

- (void)tearDown
{
    self.calculator.marginalsNeeded = 3;
    self.calculator.completesNeeded = 1;
    [super tearDown];
}

#pragma mark - Singleton

- (void)testSharedCalculator
{
    OPTrustCalculator *c1 = [OPTrustCalculator sharedCalculator];
    OPTrustCalculator *c2 = [OPTrustCalculator sharedCalculator];
    XCTAssertNotNil(c1, @"Shared calculator should not be nil");
    XCTAssertEqual(c1, c2, @"Shared calculator should be a singleton");
}

#pragma mark - Default settings

- (void)testDefaultSettings
{
    OPTrustCalculator *calc = [OPTrustCalculator sharedCalculator];
    XCTAssertEqual(calc.marginalsNeeded, (NSInteger)3,
                   @"Default marginalsNeeded should be 3");
    XCTAssertEqual(calc.completesNeeded, (NSInteger)1,
                   @"Default completesNeeded should be 1");
}

- (void)testCustomMarginalsNeeded
{
    self.calculator.marginalsNeeded = 5;
    XCTAssertEqual(self.calculator.marginalsNeeded, (NSInteger)5);
}

- (void)testCustomCompletesNeeded
{
    self.calculator.completesNeeded = 2;
    XCTAssertEqual(self.calculator.completesNeeded, (NSInteger)2);
}

#pragma mark - Trust for secret keys

- (void)testUltimateTrustForSecretKey
{
    OPKey *secretKey = [self secretKeyWithKeyID:@"SECRETKEY0000001"];
    OPTrustLevel trust = [self.calculator effectiveTrustForKey:secretKey];
    XCTAssertEqual(trust, OPTrustLevelUltimate,
                   @"Secret (own) keys should have ultimate trust");
}

#pragma mark - Trust for revoked keys

- (void)testNoneTrustForRevokedKey
{
    NSDate *future = [NSDate dateWithTimeIntervalSinceNow:365 * 24 * 60 * 60];
    OPKey *revokedKey = [self keyWithKeyID:@"REVOKEDKEY000001"
                                 isSecret:NO
                                isRevoked:YES
                            expirationDate:future
                               ownerTrust:OPTrustLevelUnknown
                               signatures:nil];
    OPTrustLevel trust = [self.calculator effectiveTrustForKey:revokedKey];
    XCTAssertEqual(trust, OPTrustLevelNone,
                   @"Revoked keys should have none trust");
}

#pragma mark - Trust for expired keys

- (void)testNoneTrustForExpiredKey
{
    NSDate *pastDate = [NSDate dateWithTimeIntervalSinceNow:-86400]; // yesterday
    OPKey *expiredKey = [self keyWithKeyID:@"EXPIREDKEY000001"
                                 isSecret:NO
                                isRevoked:NO
                            expirationDate:pastDate
                               ownerTrust:OPTrustLevelUnknown
                               signatures:nil];
    OPTrustLevel trust = [self.calculator effectiveTrustForKey:expiredKey];
    XCTAssertEqual(trust, OPTrustLevelNone,
                   @"Expired keys should have none trust");
}

#pragma mark - Trust for unsigned keys

- (void)testUnknownTrustForUnsignedKey
{
    OPKey *key = [self validPublicKeyWithKeyID:@"UNSIGNEDKEY00001"];
    // Remove all signatures (no third-party sigs, but keep self-sig conceptually)
    key.signatures = [NSMutableArray array];
    key.ownerTrust = OPTrustLevelUnknown;

    OPTrustLevel trust = [self.calculator effectiveTrustForKey:key];
    XCTAssertTrue(trust == OPTrustLevelUnknown || trust == OPTrustLevelNone,
                  @"Key with no signatures should have unknown or none trust, got %ld",
                  (long)trust);
}

#pragma mark - Key validity

- (void)testIsKeyValidForValidKey
{
    OPKey *key = [self validPublicKeyWithKeyID:@"VALIDKEY00000001"];
    BOOL valid = [self.calculator isKeyValid:key];
    XCTAssertTrue(valid, @"Non-expired, non-revoked key should be valid");
}

- (void)testIsKeyValidForExpiredKey
{
    NSDate *pastDate = [NSDate dateWithTimeIntervalSinceNow:-86400];
    OPKey *key = [self keyWithKeyID:@"EXPIREDKEY000001"
                           isSecret:NO
                          isRevoked:NO
                      expirationDate:pastDate
                         ownerTrust:OPTrustLevelUnknown
                         signatures:nil];
    BOOL valid = [self.calculator isKeyValid:key];
    XCTAssertFalse(valid, @"Expired key should not be valid");
}

- (void)testIsKeyValidForRevokedKey
{
    NSDate *future = [NSDate dateWithTimeIntervalSinceNow:365 * 24 * 60 * 60];
    OPKey *key = [self keyWithKeyID:@"REVOKEDKEY000001"
                           isSecret:NO
                          isRevoked:YES
                      expirationDate:future
                         ownerTrust:OPTrustLevelUnknown
                         signatures:nil];
    BOOL valid = [self.calculator isKeyValid:key];
    XCTAssertFalse(valid, @"Revoked key should not be valid");
}

- (void)testIsKeyValidForKeyWithNoExpiration
{
    OPKey *key = [self keyWithKeyID:@"NOEXPIREKEY00001"
                           isSecret:NO
                          isRevoked:NO
                      expirationDate:nil
                         ownerTrust:OPTrustLevelUnknown
                         signatures:nil];
    BOOL valid = [self.calculator isKeyValid:key];
    XCTAssertTrue(valid, @"Key with no expiration date should be valid if not revoked");
}

#pragma mark - Explicit owner trust

- (void)testExplicitOwnerTrustUltimate
{
    OPKey *key = [self validPublicKeyWithKeyID:@"TRUSTEDKEY000001"];
    key.ownerTrust = OPTrustLevelUltimate;

    OPTrustLevel trust = [self.calculator effectiveTrustForKey:key];
    XCTAssertEqual(trust, OPTrustLevelUltimate,
                   @"Key with explicit ultimate owner trust should return ultimate");
}

- (void)testExplicitOwnerTrustFull
{
    OPKey *key = [self validPublicKeyWithKeyID:@"FULLTRUST0000001"];
    key.ownerTrust = OPTrustLevelFull;

    OPTrustLevel trust = [self.calculator effectiveTrustForKey:key];
    XCTAssertTrue(trust >= OPTrustLevelFull,
                  @"Key with explicit full owner trust should return at least full");
}

- (void)testExplicitOwnerTrustNone
{
    OPKey *key = [self validPublicKeyWithKeyID:@"NONETRUST0000001"];
    key.ownerTrust = OPTrustLevelNone;

    OPTrustLevel trust = [self.calculator effectiveTrustForKey:key];
    XCTAssertEqual(trust, OPTrustLevelNone,
                   @"Key with explicit none trust should return none");
}

#pragma mark - Signature trust

- (void)testSignatureTrustForKeyWithNoCertifications
{
    OPKey *key = [self validPublicKeyWithKeyID:@"NOCERTSKEY000001"];
    key.signatures = [NSMutableArray array];

    OPTrustLevel sigTrust = [self.calculator signatureTrustForKey:key];
    XCTAssertTrue(sigTrust == OPTrustLevelUnknown || sigTrust == OPTrustLevelNone,
                  @"Key with no certifications should have unknown/none signature trust");
}

- (void)testSignatureTrustForKeyWithSelfSignatureOnly
{
    OPKey *key = [self validPublicKeyWithKeyID:@"SELFSIGKEY000001"];
    // Has only the self-signature added by helper

    OPTrustLevel sigTrust = [self.calculator signatureTrustForKey:key];
    // Self-sig alone should not confer full trust from third parties
    XCTAssertTrue(sigTrust <= OPTrustLevelMarginal,
                  @"Self-signature alone should not produce full signature trust");
}

#pragma mark - Trust level strings

- (void)testTrustLevelStringUnknown
{
    NSString *str = [OPTrustCalculator trustLevelString:OPTrustLevelUnknown];
    XCTAssertNotNil(str);
    XCTAssertTrue(str.length > 0, @"Trust level string should not be empty");
}

- (void)testTrustLevelStringNone
{
    NSString *str = [OPTrustCalculator trustLevelString:OPTrustLevelNone];
    XCTAssertNotNil(str);
    XCTAssertTrue(str.length > 0);
}

- (void)testTrustLevelStringMarginal
{
    NSString *str = [OPTrustCalculator trustLevelString:OPTrustLevelMarginal];
    XCTAssertNotNil(str);
    XCTAssertTrue(str.length > 0);
}

- (void)testTrustLevelStringFull
{
    NSString *str = [OPTrustCalculator trustLevelString:OPTrustLevelFull];
    XCTAssertNotNil(str);
    XCTAssertTrue(str.length > 0);
}

- (void)testTrustLevelStringUltimate
{
    NSString *str = [OPTrustCalculator trustLevelString:OPTrustLevelUltimate];
    XCTAssertNotNil(str);
    XCTAssertTrue(str.length > 0);
}

- (void)testAllTrustLevelStringsAreDifferent
{
    NSString *unknown  = [OPTrustCalculator trustLevelString:OPTrustLevelUnknown];
    NSString *none     = [OPTrustCalculator trustLevelString:OPTrustLevelNone];
    NSString *marginal = [OPTrustCalculator trustLevelString:OPTrustLevelMarginal];
    NSString *full     = [OPTrustCalculator trustLevelString:OPTrustLevelFull];
    NSString *ultimate = [OPTrustCalculator trustLevelString:OPTrustLevelUltimate];

    NSSet *uniqueStrings = [NSSet setWithArray:@[unknown, none, marginal, full, ultimate]];
    XCTAssertEqual(uniqueStrings.count, (NSUInteger)5,
                   @"All 5 trust level strings should be unique");
}

#pragma mark - Trust level colors

- (void)testTrustLevelColorNotNil
{
    NSArray *levels = @[@(OPTrustLevelUnknown), @(OPTrustLevelNone),
                        @(OPTrustLevelMarginal), @(OPTrustLevelFull),
                        @(OPTrustLevelUltimate)];
    for (NSNumber *level in levels) {
        UIColor *color = [OPTrustCalculator trustLevelColor:[level integerValue]];
        XCTAssertNotNil(color,
                        @"Trust level color should not be nil for level %@", level);
    }
}

- (void)testTrustLevelColorsAreDifferent
{
    // At minimum, unknown/none and ultimate should be visually distinct
    UIColor *noneColor = [OPTrustCalculator trustLevelColor:OPTrustLevelNone];
    UIColor *ultimateColor = [OPTrustCalculator trustLevelColor:OPTrustLevelUltimate];
    XCTAssertFalse([noneColor isEqual:ultimateColor],
                   @"None and Ultimate trust colors should be different");
}

#pragma mark - Nil key handling

- (void)testEffectiveTrustForNilKey
{
    // Should handle nil gracefully
    OPTrustLevel trust = [self.calculator effectiveTrustForKey:nil];
    XCTAssertTrue(trust == OPTrustLevelUnknown || trust == OPTrustLevelNone,
                  @"Nil key should return unknown or none trust");
}

- (void)testIsKeyValidForNilKey
{
    BOOL valid = [self.calculator isKeyValid:nil];
    XCTAssertFalse(valid, @"Nil key should not be valid");
}

@end
// onlypgp-wip
