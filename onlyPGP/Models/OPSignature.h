//
//  OPSignature.h
//  onlyPGP
//
//  Created 2014. OpenPGP signature model.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, OPSignatureType) {
    OPSignatureTypeBinary           = 0x00,
    OPSignatureTypeText             = 0x01,
    OPSignatureTypeCertGeneric      = 0x10,
    OPSignatureTypeCertPersona      = 0x11,
    OPSignatureTypeCertCasual       = 0x12,
    OPSignatureTypeCertPositive     = 0x13,
    OPSignatureTypeSubkeyBinding    = 0x18,
    OPSignatureTypePrimaryKeyBinding = 0x19,
    OPSignatureTypeKeyRevocation    = 0x20,
    OPSignatureTypeSubkeyRevocation = 0x28
};

@interface OPSignature : NSObject

@property (nonatomic, copy) NSString *keyID;
@property (nonatomic, copy) NSString *signerKeyID;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) NSDate *expirationDate;
@property (nonatomic, assign) NSInteger signatureType;
@property (nonatomic, assign) BOOL isRevocation;
@property (nonatomic, copy) NSString *parentKeyID;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)toDictionary;

- (NSString *)signatureTypeName;
- (BOOL)isCertification;

@end
