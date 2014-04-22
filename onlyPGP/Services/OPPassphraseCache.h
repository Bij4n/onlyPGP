//
//  OPPassphraseCache.h
//  onlyPGP
//
//  Created 2014. Passphrase caching with keychain persistence and memory timeout.
//

#import <Foundation/Foundation.h>

@interface OPPassphraseCache : NSObject

+ (OPPassphraseCache *)sharedCache;

@property (nonatomic, assign) NSTimeInterval cacheTimeout; // default 300 seconds (5 min)

// Keychain (persistent)
- (BOOL)storePassphrase:(NSString *)passphrase forKeyID:(NSString *)keyID;
- (NSString *)passphraseForKeyID:(NSString *)keyID;
- (BOOL)removePassphraseForKeyID:(NSString *)keyID;
- (BOOL)removeAllPassphrases;

// Memory cache (temporary)
- (void)cachePassphrase:(NSString *)passphrase forKeyID:(NSString *)keyID;
- (NSString *)cachedPassphraseForKeyID:(NSString *)keyID;
- (void)clearCache;

@end
