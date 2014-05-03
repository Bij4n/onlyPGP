//
//  OPSignature.m
//  onlyPGP
//
//  Created 2014. OpenPGP signature model.
//

#import "OPSignature.h"

@implementation OPSignature

- (instancetype)init
{
    self = [super init];
    if (self) {
        _isRevocation = NO;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [self init];
    if (self) {
        _keyID = [dictionary[@"key_id"] copy];
        _signerKeyID = [dictionary[@"signer_key_id"] copy];
        _signatureType = [dictionary[@"signature_type"] integerValue];
        _isRevocation = [dictionary[@"is_revocation"] boolValue];
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
    if (_signerKeyID) dict[@"signer_key_id"] = _signerKeyID;
    if (_parentKeyID) dict[@"parent_key_id"] = _parentKeyID;
    dict[@"signature_type"] = @(_signatureType);
    dict[@"is_revocation"] = @(_isRevocation);

    if (_creationDate) {
        dict[@"creation_date"] = @([_creationDate timeIntervalSince1970]);
    }
    if (_expirationDate) {
        dict[@"expiration_date"] = @([_expirationDate timeIntervalSince1970]);
    }

    return [NSDictionary dictionaryWithDictionary:dict];
}

- (NSString *)signatureTypeName
{
    switch ((OPSignatureType)_signatureType) {
        case OPSignatureTypeBinary:
            return @"Binary Signature";
        case OPSignatureTypeText:
            return @"Text Signature";
        case OPSignatureTypeCertGeneric:
            return @"Generic Certification";
        case OPSignatureTypeCertPersona:
            return @"Persona Certification";
        case OPSignatureTypeCertCasual:
            return @"Casual Certification";
        case OPSignatureTypeCertPositive:
            return @"Positive Certification";
        case OPSignatureTypeSubkeyBinding:
            return @"Subkey Binding";
        case OPSignatureTypePrimaryKeyBinding:
            return @"Primary Key Binding";
        case OPSignatureTypeKeyRevocation:
            return @"Key Revocation";
        case OPSignatureTypeSubkeyRevocation:
            return @"Subkey Revocation";
        default:
            return [NSString stringWithFormat:@"Unknown (0x%02lx)", (long)_signatureType];
    }
}

- (BOOL)isCertification
{
    return (_signatureType == OPSignatureTypeCertGeneric ||
            _signatureType == OPSignatureTypeCertPersona ||
            _signatureType == OPSignatureTypeCertCasual ||
            _signatureType == OPSignatureTypeCertPositive);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<OPSignature: %@ by %@ type:%@>",
            _keyID ?: @"(nil)",
            _signerKeyID ?: @"(nil)",
            [self signatureTypeName]];
}

@end
