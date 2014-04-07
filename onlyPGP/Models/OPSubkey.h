//
//  OPSubkey.h
//  onlyPGP
//
//  Created 2014. OpenPGP subkey model.
//

#import <Foundation/Foundation.h>

@interface OPSubkey : NSObject

@property (nonatomic, copy) NSString *keyID;
@property (nonatomic, copy) NSString *fingerprint;
@property (nonatomic, assign) NSInteger algorithm;
@property (nonatomic, assign) NSInteger keySize;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) NSDate *expirationDate;
@property (nonatomic, assign) BOOL canSign;
@property (nonatomic, assign) BOOL canEncrypt;
@property (nonatomic, assign) BOOL isRevoked;
@property (nonatomic, copy) NSString *parentKeyID;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)toDictionary;

- (NSString *)algorithmName;
- (BOOL)isExpired;

@end
