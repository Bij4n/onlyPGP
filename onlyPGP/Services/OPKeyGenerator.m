//
//  OPKeyGenerator.m
//  onlyPGP
//
//  Created 2014. PGP keypair generation service.
//

#import "OPKeyGenerator.h"
#import <ObjectivePGP/ObjectivePGP.h>
#import "OPKey.h"
#import "OPSubkey.h"
#import "OPUserID.h"
#import "OPSignature.h"
#import "OPKeyStore.h"
#import "OPPassphraseCache.h"

NSString * const OPKeyringDidChangeNotification = @"OPKeyringDidChangeNotification";

static NSString * const kOPKeyGeneratorErrorDomain = @"com.onlypgp.keygenerator";

@interface OPKeyGenerator ()

@property (nonatomic, assign) BOOL generating;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, strong) dispatch_queue_t generationQueue;

@end

@implementation OPKeyGenerator

#pragma mark - Singleton

+ (OPKeyGenerator *)sharedGenerator
{
    static OPKeyGenerator *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OPKeyGenerator alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _generating = NO;
        _cancelled = NO;
        _generationQueue = dispatch_queue_create("com.onlypgp.keygenerator.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Public Methods

- (BOOL)isGenerating
{
    return _generating;
}

- (void)cancelGeneration
{
    _cancelled = YES;
}

- (void)generateKeyPairWithName:(NSString *)name
                          email:(NSString *)email
                        keySize:(NSInteger)keySize
                     passphrase:(NSString *)passphrase
                       progress:(OPKeyGenerationProgress)progressBlock
                     completion:(OPKeyGenerationCompletion)completionBlock
{
    if (_generating) {
        NSError *error = [NSError errorWithDomain:kOPKeyGeneratorErrorDomain
                                             code:100
                                         userInfo:@{NSLocalizedDescriptionKey: @"Key generation is already in progress."}];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error);
            });
        }
        return;
    }

    // Validate inputs
    if (!name || [name length] == 0) {
        NSError *error = [NSError errorWithDomain:kOPKeyGeneratorErrorDomain
                                             code:101
                                         userInfo:@{NSLocalizedDescriptionKey: @"Name is required for key generation."}];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error);
            });
        }
        return;
    }

    if (!email || [email length] == 0) {
        NSError *error = [NSError errorWithDomain:kOPKeyGeneratorErrorDomain
                                             code:102
                                         userInfo:@{NSLocalizedDescriptionKey: @"Email is required for key generation."}];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error);
            });
        }
        return;
    }

    if (keySize != 1024 && keySize != 2048 && keySize != 4096) {
        keySize = 2048; // Default to 2048 if invalid size
    }

    if (!passphrase || [passphrase length] == 0) {
        NSError *error = [NSError errorWithDomain:kOPKeyGeneratorErrorDomain
                                             code:103
                                         userInfo:@{NSLocalizedDescriptionKey: @"Passphrase is required for key generation."}];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error);
            });
        }
        return;
    }

    _generating = YES;
    _cancelled = NO;

    dispatch_async(_generationQueue, ^{

        // Report initial progress
        if (progressBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                progressBlock(0.05f);
            });
        }

        // Check for cancellation
        if (self.cancelled) {
            [self finishGenerationWithKey:nil error:nil completion:completionBlock];
            return;
        }

        // Build the user ID string in PGP format: "Name (Comment) <email>"
        NSString *userIDString = [NSString stringWithFormat:@"%@ <%@>", name, email];

        // Create ObjectivePGP instance for key generation
        ObjectivePGP *pgp = [[ObjectivePGP alloc] init];

        if (progressBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                progressBlock(0.10f);
            });
        }

        // Check for cancellation before the expensive operation
        if (self.cancelled) {
            [self finishGenerationWithKey:nil error:nil completion:completionBlock];
            return;
        }

        // Generate the key pair using ObjectivePGP
        // ObjectivePGP generates an RSA master key (for signing) and an RSA subkey (for encryption)
        PGPKey *pgpKey = nil;
        NSError *generationError = nil;

        @try {
            if (progressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(0.15f);
                });
            }

            // Generate the key with specified parameters
            pgpKey = [pgp generateNewKeyForUserID:userIDString];

            if (progressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(0.60f);
                });
            }

            if (self.cancelled) {
                [self finishGenerationWithKey:nil error:nil completion:completionBlock];
                return;
            }

            if (!pgpKey) {
                generationError = [NSError errorWithDomain:kOPKeyGeneratorErrorDomain
                                                      code:200
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate PGP key pair."}];
                [self finishGenerationWithKey:nil error:generationError completion:completionBlock];
                return;
            }

            // Import the generated key into the PGP instance for export
            [pgp importKey:pgpKey];

            if (progressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(0.70f);
                });
            }

            // Export the armored public key
            NSError *exportError = nil;
            NSData *publicKeyData = [pgpKey export:PGPPartialKeyPublic error:&exportError];
            if (!publicKeyData) {
                generationError = [NSError errorWithDomain:kOPKeyGeneratorErrorDomain
                                                      code:201
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to export public key.",
                                                             NSUnderlyingErrorKey: exportError ?: [NSNull null]}];
                [self finishGenerationWithKey:nil error:generationError completion:completionBlock];
                return;
            }

            NSString *armoredPublicKey = [PGPArmor armoredData:publicKeyData as:PGPArmorTypePublicKey];

            if (progressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(0.80f);
                });
            }

            // Export the armored secret key (encrypted with passphrase)
            NSData *secretKeyData = [pgpKey export:PGPPartialKeySecret error:&exportError];
            if (!secretKeyData) {
                generationError = [NSError errorWithDomain:kOPKeyGeneratorErrorDomain
                                                      code:202
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to export secret key.",
                                                             NSUnderlyingErrorKey: exportError ?: [NSNull null]}];
                [self finishGenerationWithKey:nil error:generationError completion:completionBlock];
                return;
            }

            NSString *armoredSecretKey = [PGPArmor armoredData:secretKeyData as:PGPArmorTypeSecretKey];

            if (progressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(0.85f);
                });
            }

            // Extract key properties from the generated PGP key
            NSString *keyID = [[pgpKey keyID] description];
            NSString *fingerprint = [[pgpKey primaryKeyPacket] fingerprint].description;

            // Build the OPKey model
            OPKey *opKey = [[OPKey alloc] init];
            opKey.keyID = keyID;
            opKey.fingerprint = fingerprint;
            opKey.algorithm = OPKeyAlgorithmRSA;
            opKey.keySize = keySize;
            opKey.creationDate = [NSDate date];
            opKey.expirationDate = nil; // No expiration by default
            opKey.isSecretKey = YES;
            opKey.armoredPublicKey = armoredPublicKey;
            opKey.armoredSecretKey = armoredSecretKey;
            opKey.isRevoked = NO;
            opKey.ownerTrust = OPTrustLevelUltimate; // We own this key

            // Build the primary user ID
            OPUserID *primaryUID = [[OPUserID alloc] init];
            primaryUID.name = name;
            primaryUID.email = email;
            primaryUID.comment = nil;
            primaryUID.userIDString = userIDString;
            primaryUID.isPrimary = YES;
            primaryUID.parentKeyID = keyID;

            opKey.primaryUserID = primaryUID;
            opKey.userIDs = @[primaryUID];

            // Extract subkeys from the generated key
            NSMutableArray *subkeys = [NSMutableArray array];
            if (pgpKey.secretKey) {
                for (PGPPartialSubKey *pgpSubkey in pgpKey.secretKey.subKeys) {
                    OPSubkey *subkey = [[OPSubkey alloc] init];
                    subkey.keyID = [[pgpSubkey keyID] description];
                    subkey.fingerprint = [pgpSubkey.primaryKeyPacket fingerprint].description;
                    subkey.algorithm = OPKeyAlgorithmRSA;
                    subkey.keySize = keySize;
                    subkey.creationDate = [NSDate date];
                    subkey.expirationDate = nil;
                    subkey.canSign = NO;
                    subkey.canEncrypt = YES;
                    subkey.parentKeyID = keyID;
                    [subkeys addObject:subkey];
                }
            }
            if (pgpKey.publicKey) {
                for (PGPPartialSubKey *pgpSubkey in pgpKey.publicKey.subKeys) {
                    // Check if we already added this subkey from the secret side
                    NSString *subKeyID = [[pgpSubkey keyID] description];
                    BOOL alreadyAdded = NO;
                    for (OPSubkey *existing in subkeys) {
                        if ([existing.keyID isEqualToString:subKeyID]) {
                            alreadyAdded = YES;
                            break;
                        }
                    }
                    if (!alreadyAdded) {
                        OPSubkey *subkey = [[OPSubkey alloc] init];
                        subkey.keyID = subKeyID;
                        subkey.fingerprint = [pgpSubkey.primaryKeyPacket fingerprint].description;
                        subkey.algorithm = OPKeyAlgorithmRSA;
                        subkey.keySize = keySize;
                        subkey.creationDate = [NSDate date];
                        subkey.expirationDate = nil;
                        subkey.canSign = NO;
                        subkey.canEncrypt = YES;
                        subkey.parentKeyID = keyID;
                        [subkeys addObject:subkey];
                    }
                }
            }
            opKey.subkeys = [NSArray arrayWithArray:subkeys];

            // Initialize signatures as empty (self-sig is implicit in the key packet)
            opKey.signatures = @[];

            if (progressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(0.90f);
                });
            }

            // Store passphrase in keychain
            OPPassphraseCache *cache = [OPPassphraseCache sharedCache];
            [cache storePassphrase:passphrase forKeyID:keyID];
            [cache cachePassphrase:passphrase forKeyID:keyID];

            if (progressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(0.95f);
                });
            }

            // Save to OPKeyStore
            OPKeyStore *store = [OPKeyStore sharedStore];
            [store insertKey:opKey];

            if (progressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(1.0f);
                });
            }

            // Finish successfully
            [self finishGenerationWithKey:opKey error:nil completion:completionBlock];

        } @catch (NSException *exception) {
            generationError = [NSError errorWithDomain:kOPKeyGeneratorErrorDomain
                                                  code:300
                                              userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Key generation failed: %@", exception.reason],
                                                         @"exception": exception}];
            [self finishGenerationWithKey:nil error:generationError completion:completionBlock];
        }
    });
}

#pragma mark - Private Methods

- (void)finishGenerationWithKey:(OPKey *)key
                          error:(NSError *)error
                     completion:(OPKeyGenerationCompletion)completionBlock
{
    self.generating = NO;
    self.cancelled = NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (key) {
            // Post notification that keyring has changed
            [[NSNotificationCenter defaultCenter] postNotificationName:OPKeyringDidChangeNotification
                                                                object:self
                                                              userInfo:@{@"key": key}];
        }

        if (completionBlock) {
            completionBlock(key, error);
        }
    });
}

@end
