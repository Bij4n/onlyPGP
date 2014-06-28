//
//  OPKey.m
//  onlyPGP
//
//  Created 2014. OpenPGP key model.
//

#import "OPKey.h"
#import "OPUserID.h"
#import "OPSubkey.h"
#import "OPSignature.h"

@implementation OPKey

- (instancetype)init
{
    self = [super init];
    if (self) {
        _userIDs = [[NSMutableArray alloc] init];
        _subkeys = [[NSMutableArray alloc] init];
        _signatures = [[NSMutableArray alloc] init];
        _ownerTrust = OPTrustLevelUnknown;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [self init];
    if (self) {
        _keyID = [dictionary[@"key_id"] copy];
        _fingerprint = [dictionary[@"fingerprint"] copy];
        _algorithm = [dictionary[@"algorithm"] integerValue];
        _keySize = [dictionary[@"key_size"] integerValue];
        _isSecretKey = [dictionary[@"is_secret_key"] boolValue];
        _armoredPublicKey = [dictionary[@"armored_public_key"] copy];
        _armoredSecretKey = [dictionary[@"armored_secret_key"] copy];
        _isRevoked = [dictionary[@"is_revoked"] boolValue];
        _ownerTrust = [dictionary[@"owner_trust"] integerValue];

        id creationVal = dictionary[@"creation_date"];
        if (creationVal && creationVal != [NSNull null]) {
            _creationDate = [NSDate dateWithTimeIntervalSince1970:[creationVal doubleValue]];
        }

        id expirationVal = dictionary[@"expiration_date"];
        if (expirationVal && expirationVal != [NSNull null]) {
            _expirationDate = [NSDate dateWithTimeIntervalSince1970:[expirationVal doubleValue]];
        }
    }
    return self;
}

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    if (_keyID) dict[@"key_id"] = _keyID;
    if (_fingerprint) dict[@"fingerprint"] = _fingerprint;
    dict[@"algorithm"] = @(_algorithm);
    dict[@"key_size"] = @(_keySize);
    dict[@"is_secret_key"] = @(_isSecretKey);
    dict[@"is_revoked"] = @(_isRevoked);
    dict[@"owner_trust"] = @(_ownerTrust);

    if (_armoredPublicKey) dict[@"armored_public_key"] = _armoredPublicKey;
    if (_armoredSecretKey) dict[@"armored_secret_key"] = _armoredSecretKey;

    if (_creationDate) {
        dict[@"creation_date"] = @([_creationDate timeIntervalSince1970]);
    }
    if (_expirationDate) {
        dict[@"expiration_date"] = @([_expirationDate timeIntervalSince1970]);
    }

    return [NSDictionary dictionaryWithDictionary:dict];
}

- (NSString *)algorithmName
{
    switch ((OPKeyAlgorithm)_algorithm) {
        case OPKeyAlgorithmRSA:
            return @"RSA";
        case OPKeyAlgorithmDSA:
            return @"DSA";
        case OPKeyAlgorithmECDSA:
            return @"ECDSA";
        case OPKeyAlgorithmElGamal:
            return @"ElGamal";
        default:
            return [NSString stringWithFormat:@"Unknown (%ld)", (long)_algorithm];
    }
}

- (NSString *)shortKeyID
{
    if ([_keyID length] >= 8) {
        return [_keyID substringFromIndex:[_keyID length] - 8];
    }
    return _keyID;
}

- (BOOL)isExpired
{
    if (!_expirationDate) {
        return NO;
    }
    return [_expirationDate compare:[NSDate date]] == NSOrderedAscending;
}

- (NSInteger)daysUntilExpiration
{
    if (!_expirationDate) {
        return NSIntegerMax;
    }

    NSTimeInterval interval = [_expirationDate timeIntervalSinceDate:[NSDate date]];
    return (NSInteger)(interval / 86400.0);
}

- (NSString *)primaryUserID
{
    if (_primaryUserID) {
        return _primaryUserID;
    }

    for (OPUserID *uid in _userIDs) {
        if (uid.isPrimary) {
            return uid.userIDString;
        }
    }

    if ([_userIDs count] > 0) {
        OPUserID *first = _userIDs[0];
        return first.userIDString;
    }

    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<OPKey: %@ %@-bit %@ %@>",
            [self shortKeyID],
            @(_keySize),
            [self algorithmName],
            self.primaryUserID ?: @"(no user ID)"];
}

@end
// onlypgp-wip
