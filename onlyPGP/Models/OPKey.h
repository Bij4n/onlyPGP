//
//  OPKey.h
//  onlyPGP
//
//  Created 2014. OpenPGP key model.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, OPKeyAlgorithm) {
    OPKeyAlgorithmRSA       = 1,
    OPKeyAlgorithmElGamal   = 16,
    OPKeyAlgorithmDSA       = 17,
    OPKeyAlgorithmECDSA     = 19
};

typedef NS_ENUM(NSInteger, OPTrustLevel) {
    OPTrustLevelUnknown     = 0,
    OPTrustLevelNone,
    OPTrustLevelMarginal,
    OPTrustLevelFull,
    OPTrustLevelUltimate
};

@interface OPKey : NSObject

@property (nonatomic, copy) NSString *keyID;
@property (nonatomic, copy) NSString *fingerprint;
@property (nonatomic, assign) NSInteger algorithm;
@property (nonatomic, assign) NSInteger keySize;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) NSDate *expirationDate;
@property (nonatomic, assign) BOOL isSecretKey;
@property (nonatomic, copy) NSString *armoredPublicKey;
@property (nonatomic, copy) NSString *armoredSecretKey;
@property (nonatomic, copy) NSString *primaryUserID;
@property (nonatomic, strong) NSMutableArray *userIDs;
@property (nonatomic, strong) NSMutableArray *subkeys;
@property (nonatomic, strong) NSMutableArray *signatures;
@property (nonatomic, assign) BOOL isRevoked;
@property (nonatomic, assign) NSInteger ownerTrust;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)toDictionary;

- (NSString *)algorithmName;
- (NSString *)shortKeyID;
- (BOOL)isExpired;
- (NSInteger)daysUntilExpiration;

@end
// onlypgp-wip
