//
//  OPTrustCalculator.m
//  onlyPGP
//
//  Created 2014. Web of trust calculation for PGP keys.
//

#import "OPTrustCalculator.h"
#import "OPKey.h"
#import "OPSignature.h"
#import "OPKeyStore.h"

static const NSInteger kOPDefaultMarginalsNeeded = 3;
static const NSInteger kOPDefaultCompletesNeeded = 1;

// Maximum depth for trust path traversal to avoid infinite loops
static const NSInteger kOPMaxTrustDepth = 5;

@interface OPTrustCalculator ()

@end

@implementation OPTrustCalculator

#pragma mark - Singleton

+ (OPTrustCalculator *)sharedCalculator
{
    static OPTrustCalculator *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OPTrustCalculator alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _marginalsNeeded = kOPDefaultMarginalsNeeded;
        _completesNeeded = kOPDefaultCompletesNeeded;
    }
    return self;
}

#pragma mark - Key Validity

- (BOOL)isKeyValid:(OPKey *)key
{
    if (!key) {
        return NO;
    }

    // Check if key is revoked
    if (key.isRevoked) {
        return NO;
    }

    // Check if key is expired
    if (key.expirationDate) {
        NSDate *now = [NSDate date];
        if ([key.expirationDate compare:now] == NSOrderedAscending) {
            return NO;
        }
    }

    // Check that the key has at least one user ID
    if (!key.userIDs || [key.userIDs count] == 0) {
        return NO;
    }

    // Check for a valid self-signature
    // A key should have at least one signature from itself (self-certification)
    BOOL hasSelfSig = [self keyHasValidSelfSignature:key];

    // If the key is a secret key (we own it), we trust the self-signature implicitly
    if (key.isSecretKey) {
        return YES;
    }

    // For public keys, we need a valid self-signature
    // However, in practice many imported keys may not have signatures parsed,
    // so we also accept keys that simply have user IDs
    if (!hasSelfSig && key.signatures && [key.signatures count] > 0) {
        // Has some signatures but no self-sig -- questionable validity
        NSLog(@"OPTrustCalculator: Key %@ has signatures but no valid self-signature.", key.keyID);
    }

    // Consider key valid if it has user IDs and is not revoked/expired
    return YES;
}

- (BOOL)keyHasValidSelfSignature:(OPKey *)key
{
    if (!key.signatures || [key.signatures count] == 0) {
        // No signatures parsed -- assume valid for imported keys
        return key.isSecretKey;
    }

    for (OPSignature *sig in key.signatures) {
        // A self-signature is where the signer key ID matches the key's own key ID
        if (sig.signerKeyID && key.keyID) {
            // Compare the last 8 characters (short key IDs)
            NSString *signerShort = [self shortKeyID:sig.signerKeyID];
            NSString *keyShort = [self shortKeyID:key.keyID];

            if ([signerShort isEqualToString:keyShort]) {
                // Check it's not a revocation signature
                if (!sig.isRevocation) {
                    // Check it's not expired
                    if (!sig.expirationDate || [sig.expirationDate compare:[NSDate date]] != NSOrderedAscending) {
                        return YES;
                    }
                }
            }
        }
    }

    return NO;
}

#pragma mark - Trust Calculation

- (OPTrustLevel)effectiveTrustForKey:(OPKey *)key
{
    if (!key) {
        return OPTrustLevelUnknown;
    }

    // If the key has an explicit owner trust set to Ultimate, return it
    if (key.ownerTrust == OPTrustLevelUltimate) {
        return OPTrustLevelUltimate;
    }

    // If this is our own secret key, trust it ultimately
    if (key.isSecretKey) {
        return OPTrustLevelUltimate;
    }

    // If the key is revoked, it gets no trust
    if (key.isRevoked) {
        return OPTrustLevelNone;
    }

    // If the key is expired, it gets no trust
    if (key.expirationDate) {
        if ([key.expirationDate compare:[NSDate date]] == NSOrderedAscending) {
            return OPTrustLevelNone;
        }
    }

    // If the key is not valid, return None
    if (![self isKeyValid:key]) {
        return OPTrustLevelNone;
    }

    // If owner trust is explicitly set (not Unknown), return it
    // Owner trust is the trust WE assign to this key's owner
    if (key.ownerTrust == OPTrustLevelFull) {
        return OPTrustLevelFull;
    }
    if (key.ownerTrust == OPTrustLevelMarginal) {
        return OPTrustLevelMarginal;
    }
    if (key.ownerTrust == OPTrustLevelNone) {
        return OPTrustLevelNone;
    }

    // Calculate trust from the web of trust (signature-based trust)
    OPTrustLevel signatureTrust = [self signatureTrustForKey:key];

    return signatureTrust;
}

- (OPTrustLevel)signatureTrustForKey:(OPKey *)key
{
    if (!key) {
        return OPTrustLevelUnknown;
    }

    // Use visited set to prevent circular trust paths
    NSMutableSet *visitedKeyIDs = [NSMutableSet set];
    return [self calculateSignatureTrustForKey:key visitedKeyIDs:visitedKeyIDs depth:0];
}

- (OPTrustLevel)calculateSignatureTrustForKey:(OPKey *)key
                                visitedKeyIDs:(NSMutableSet *)visitedKeyIDs
                                        depth:(NSInteger)depth
{
    if (!key || !key.keyID) {
        return OPTrustLevelUnknown;
    }

    // Prevent infinite recursion
    if (depth > kOPMaxTrustDepth) {
        return OPTrustLevelUnknown;
    }

    // Prevent circular paths
    if ([visitedKeyIDs containsObject:key.keyID]) {
        return OPTrustLevelUnknown;
    }
    [visitedKeyIDs addObject:key.keyID];

    // If this is our own key, return Ultimate
    if (key.isSecretKey || key.ownerTrust == OPTrustLevelUltimate) {
        return OPTrustLevelUltimate;
    }

    // Collect certification signatures on this key
    NSArray *certificationSignatures = [self certificationSignaturesForKey:key];

    if (!certificationSignatures || [certificationSignatures count] == 0) {
        return OPTrustLevelUnknown;
    }

    OPKeyStore *store = [OPKeyStore sharedStore];

    NSInteger fullTrustSignerCount = 0;
    NSInteger marginalTrustSignerCount = 0;
    NSInteger ultimateTrustSignerCount = 0;

    for (OPSignature *sig in certificationSignatures) {
        // Skip revocation signatures
        if (sig.isRevocation) {
            continue;
        }

        // Skip expired signatures
        if (sig.expirationDate && [sig.expirationDate compare:[NSDate date]] == NSOrderedAscending) {
            continue;
        }

        // Skip self-signatures
        NSString *signerShort = [self shortKeyID:sig.signerKeyID];
        NSString *keyShort = [self shortKeyID:key.keyID];
        if ([signerShort isEqualToString:keyShort]) {
            continue;
        }

        // Look up the signer key
        OPKey *signerKey = [store keyWithKeyID:sig.signerKeyID];
        if (!signerKey) {
            // Try short key ID lookup
            NSArray *allKeys = [store allKeys];
            for (OPKey *candidate in allKeys) {
                NSString *candidateShort = [self shortKeyID:candidate.keyID];
                if ([candidateShort isEqualToString:signerShort]) {
                    signerKey = candidate;
                    break;
                }
            }
        }

        if (!signerKey) {
            // Signer key not in our keyring -- cannot evaluate trust
            continue;
        }

        // Check validity of signer key
        if (![self isKeyValid:signerKey]) {
            continue;
        }

        // Determine the trust level of the signer key
        OPTrustLevel signerTrust = OPTrustLevelUnknown;

        // First check explicit owner trust on the signer
        if (signerKey.ownerTrust == OPTrustLevelUltimate || signerKey.isSecretKey) {
            signerTrust = OPTrustLevelUltimate;
        } else if (signerKey.ownerTrust == OPTrustLevelFull) {
            signerTrust = OPTrustLevelFull;
        } else if (signerKey.ownerTrust == OPTrustLevelMarginal) {
            signerTrust = OPTrustLevelMarginal;
        } else if (signerKey.ownerTrust == OPTrustLevelNone) {
            signerTrust = OPTrustLevelNone;
        } else {
            // Recurse: calculate the signer's trust from their signatures
            signerTrust = [self calculateSignatureTrustForKey:signerKey
                                               visitedKeyIDs:visitedKeyIDs
                                                       depth:depth + 1];
        }

        // Count by trust level
        switch (signerTrust) {
            case OPTrustLevelUltimate:
                ultimateTrustSignerCount++;
                break;
            case OPTrustLevelFull:
                fullTrustSignerCount++;
                break;
            case OPTrustLevelMarginal:
                marginalTrustSignerCount++;
                break;
            case OPTrustLevelNone:
            case OPTrustLevelUnknown:
            default:
                break;
        }
    }

    // Ultimate-trust signers count as fully trusted signers
    NSInteger effectiveFullCount = fullTrustSignerCount + ultimateTrustSignerCount;

    // Apply the classic PGP web of trust rules:
    // If we have enough fully trusted signers OR enough marginally trusted signers, grant Full trust
    if (effectiveFullCount >= _completesNeeded) {
        return OPTrustLevelFull;
    }

    if (marginalTrustSignerCount >= _marginalsNeeded) {
        return OPTrustLevelFull;
    }

    // If we have any marginal signers, grant Marginal trust
    if (marginalTrustSignerCount > 0) {
        return OPTrustLevelMarginal;
    }

    // If we have any fully trusted signers but not enough, still Marginal
    if (effectiveFullCount > 0) {
        return OPTrustLevelMarginal;
    }

    return OPTrustLevelUnknown;
}

#pragma mark - Signature Helpers

- (NSArray *)certificationSignaturesForKey:(OPKey *)key
{
    if (!key.signatures || [key.signatures count] == 0) {
        return @[];
    }

    NSMutableArray *certSigs = [NSMutableArray array];

    for (OPSignature *sig in key.signatures) {
        // Include certification signatures (types 0x10-0x13 in PGP):
        //  - 0x10: Generic certification
        //  - 0x11: Persona certification
        //  - 0x12: Casual certification
        //  - 0x13: Positive certification
        //
        // We use signatureType values; assuming they map to these.
        // Also include any non-revocation signature from another key.

        if (sig.isRevocation) {
            continue;
        }

        // If signatureType is available, filter for certification types
        NSInteger sigType = sig.signatureType;
        if (sigType >= 0x10 && sigType <= 0x13) {
            [certSigs addObject:sig];
        } else if (sigType == 0) {
            // signatureType may not be set -- include it as a candidate
            [certSigs addObject:sig];
        }
    }

    return [NSArray arrayWithArray:certSigs];
}

- (NSString *)shortKeyID:(NSString *)keyID
{
    if (!keyID || [keyID length] < 8) {
        return [keyID uppercaseString];
    }

    // Return the last 8 characters (short key ID)
    return [[keyID substringFromIndex:[keyID length] - 8] uppercaseString];
}

#pragma mark - Display Helpers

+ (NSString *)trustLevelString:(OPTrustLevel)level
{
    switch (level) {
        case OPTrustLevelUnknown:
            return @"Unknown";
        case OPTrustLevelNone:
            return @"Not Trusted";
        case OPTrustLevelMarginal:
            return @"Marginally Trusted";
        case OPTrustLevelFull:
            return @"Fully Trusted";
        case OPTrustLevelUltimate:
            return @"Ultimately Trusted";
        default:
            return @"Unknown";
    }
}

+ (UIColor *)trustLevelColor:(OPTrustLevel)level
{
    switch (level) {
        case OPTrustLevelUnknown:
            // Gray
            return [UIColor colorWithRed:0.6f green:0.6f blue:0.6f alpha:1.0f];
        case OPTrustLevelNone:
            // Red
            return [UIColor colorWithRed:0.85f green:0.2f blue:0.15f alpha:1.0f];
        case OPTrustLevelMarginal:
            // Orange/Yellow
            return [UIColor colorWithRed:0.9f green:0.65f blue:0.1f alpha:1.0f];
        case OPTrustLevelFull:
            // Green
            return [UIColor colorWithRed:0.2f green:0.7f blue:0.3f alpha:1.0f];
        case OPTrustLevelUltimate:
            // Blue
            return [UIColor colorWithRed:0.15f green:0.45f blue:0.85f alpha:1.0f];
        default:
            return [UIColor grayColor];
    }
}

@end
// onlypgp-wip
