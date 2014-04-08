//
//  OPSubkey.m
//  onlyPGP
//
//  Created 2014. OpenPGP subkey model.
//

#import "OPSubkey.h"
#import "OPKey.h"

@implementation OPSubkey

- (instancetype)init
{
    self = [super init];
    if (self) {
        _canSign = NO;
        _canEncrypt = NO;
        _isRevoked = NO;
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
        _canSign = [dictionary[@"can_sign"] boolValue];
        _canEncrypt = [dictionary[@"can_encrypt"] boolValue];
        _isRevoked = [dictionary[@"is_revoked"] boolValue];
        _parentKeyID = [dictionary[@"parent_key_id"] copy];

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
    if (_parentKeyID) dict[@"parent_key_id"] = _parentKeyID;
    dict[@"algorithm"] = @(_algorithm);
    dict[@"key_size"] = @(_keySize);
    dict[@"can_sign"] = @(_canSign);
    dict[@"can_encrypt"] = @(_canEncrypt);
    dict[@"is_revoked"] = @(_isRevoked);

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

- (BOOL)isExpired
{
    if (!_expirationDate) {
        return NO;
    }
    return [_expirationDate compare:[NSDate date]] == NSOrderedAscending;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<OPSubkey: %@ %@-bit %@ sign:%@ encrypt:%@>",
            _keyID ?: @"(nil)",
            @(_keySize),
            [self algorithmName],
            _canSign ? @"YES" : @"NO",
            _canEncrypt ? @"YES" : @"NO"];
}

@end
