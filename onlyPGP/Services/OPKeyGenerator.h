//
//  OPKeyGenerator.h
//  onlyPGP
//
//  Created 2014. PGP keypair generation service.
//

#import <Foundation/Foundation.h>

@class OPKey;

typedef void(^OPKeyGenerationCompletion)(OPKey *key, NSError *error);
typedef void(^OPKeyGenerationProgress)(float progress);

@interface OPKeyGenerator : NSObject

+ (OPKeyGenerator *)sharedGenerator;

- (void)generateKeyPairWithName:(NSString *)name
                          email:(NSString *)email
                        keySize:(NSInteger)keySize
                     passphrase:(NSString *)passphrase
                       progress:(OPKeyGenerationProgress)progressBlock
                     completion:(OPKeyGenerationCompletion)completionBlock;

- (BOOL)isGenerating;
- (void)cancelGeneration;

@end

extern NSString * const OPKeyringDidChangeNotification;
