//
//  OPMessage.h
//  onlyPGP
//
//  Created 2014. OpenPGP message model.
//

#import <Foundation/Foundation.h>

@interface OPMessage : NSObject

@property (nonatomic, copy) NSString *plaintext;
@property (nonatomic, copy) NSString *armoredText;
@property (nonatomic, assign) BOOL isEncrypted;
@property (nonatomic, assign) BOOL isSigned;
@property (nonatomic, copy) NSString *signerKeyID;
@property (nonatomic, copy) NSArray *recipientKeyIDs;
@property (nonatomic, assign) BOOL signatureVerified;
@property (nonatomic, copy) NSString *signatureError;
@property (nonatomic, copy) NSString *decryptionError;

- (instancetype)initWithArmoredText:(NSString *)armoredText;
- (instancetype)initWithPlaintext:(NSString *)plaintext
                       recipients:(NSArray *)recipientKeyIDs
                      signerKeyID:(NSString *)signerKeyID;

@end
