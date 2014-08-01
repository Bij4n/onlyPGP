//
//  OPPGPService.h
//  onlyPGP
//
//  Created 2014. Core PGP operations wrapper around ObjectivePGP.
//

#import <Foundation/Foundation.h>

@class ObjectivePGP;
@class OPMessage;

@interface OPPGPService : NSObject

+ (OPPGPService *)sharedService;

@property (nonatomic, strong) ObjectivePGP *pgp;

// Key management
- (BOOL)importKeyFromArmoredString:(NSString *)armoredString error:(NSError **)error;
- (BOOL)importKeyFromData:(NSData *)data error:(NSError **)error;
- (NSString *)exportArmoredPublicKeyForKeyID:(NSString *)keyID error:(NSError **)error;
- (NSString *)exportArmoredSecretKeyForKeyID:(NSString *)keyID error:(NSError **)error;
- (void)loadKeysFromStore;

// Encrypt / Decrypt
- (NSString *)encryptMessage:(NSString *)plaintext
             forRecipientIDs:(NSArray *)recipientKeyIDs
                  signWithID:(NSString *)signerKeyID
                  passphrase:(NSString *)passphrase
                       error:(NSError **)error;

- (OPMessage *)decryptArmoredMessage:(NSString *)armoredMessage
                          passphrase:(NSString *)passphrase
                               error:(NSError **)error;

// Sign / Verify
- (NSString *)signMessage:(NSString *)plaintext
               withKeyID:(NSString *)signerKeyID
              passphrase:(NSString *)passphrase
                   error:(NSError **)error;

- (OPMessage *)verifySignedMessage:(NSString *)armoredMessage
                             error:(NSError **)error;

@end
