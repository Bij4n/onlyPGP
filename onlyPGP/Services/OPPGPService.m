//
//  OPPGPService.m
//  onlyPGP
//
//  Created 2014. Core PGP operations wrapper around ObjectivePGP.
//

#import "OPPGPService.h"
#import <ObjectivePGP/ObjectivePGP.h>
#import "OPKey.h"
#import "OPMessage.h"
#import "OPKeyStore.h"
#import "OPPassphraseCache.h"

static NSString * const kOPPGPServiceErrorDomain = @"com.onlypgp.pgpservice";

@interface OPPGPService ()

@property (nonatomic, strong) NSLock *pgpLock;

@end

@implementation OPPGPService

#pragma mark - Singleton

+ (OPPGPService *)sharedService
{
    static OPPGPService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OPPGPService alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _pgp = [[ObjectivePGP alloc] init];
        _pgpLock = [[NSLock alloc] init];
        [self loadKeysFromStore];
    }
    return self;
}

#pragma mark - Key Management

- (void)loadKeysFromStore
{
    [_pgpLock lock];

    // Clear existing keys and reload from store
    ObjectivePGP *freshPGP = [[ObjectivePGP alloc] init];

    OPKeyStore *store = [OPKeyStore sharedStore];
    NSArray *allKeys = [store allKeys];

    for (OPKey *opKey in allKeys) {
        @try {
            // Import public key if available
            if (opKey.armoredPublicKey && [opKey.armoredPublicKey length] > 0) {
                NSData *publicKeyData = [PGPArmor readArmoredData:opKey.armoredPublicKey];
                if (publicKeyData) {
                    NSArray *keys = [freshPGP importKeysFromData:publicKeyData];
                    if (!keys || [keys count] == 0) {
                        NSLog(@"OPPGPService: Failed to import public key for keyID %@", opKey.keyID);
                    }
                }
            }

            // Import secret key if available
            if (opKey.armoredSecretKey && [opKey.armoredSecretKey length] > 0) {
                NSData *secretKeyData = [PGPArmor readArmoredData:opKey.armoredSecretKey];
                if (secretKeyData) {
                    NSArray *keys = [freshPGP importKeysFromData:secretKeyData];
                    if (!keys || [keys count] == 0) {
                        NSLog(@"OPPGPService: Failed to import secret key for keyID %@", opKey.keyID);
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"OPPGPService: Exception importing key %@: %@", opKey.keyID, exception.reason);
        }
    }

    _pgp = freshPGP;
    [_pgpLock unlock];

    NSLog(@"OPPGPService: Loaded %lu keys from store", (unsigned long)[allKeys count]);
}

- (BOOL)importKeyFromArmoredString:(NSString *)armoredString error:(NSError **)error
{
    if (!armoredString || [armoredString length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:100
                                     userInfo:@{NSLocalizedDescriptionKey: @"Armored key string is empty."}];
        }
        return NO;
    }

    NSData *keyData = [PGPArmor readArmoredData:armoredString];
    if (!keyData) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:101
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse armored key data."}];
        }
        return NO;
    }

    return [self importKeyFromData:keyData error:error];
}

- (BOOL)importKeyFromData:(NSData *)data error:(NSError **)error
{
    if (!data || [data length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:102
                                     userInfo:@{NSLocalizedDescriptionKey: @"Key data is empty."}];
        }
        return NO;
    }

    [_pgpLock lock];

    NSArray *importedKeys = nil;
    @try {
        importedKeys = [_pgp importKeysFromData:data];
    } @catch (NSException *exception) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:103
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to import key: %@", exception.reason]}];
        }
        return NO;
    }

    [_pgpLock unlock];

    if (!importedKeys || [importedKeys count] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:104
                                     userInfo:@{NSLocalizedDescriptionKey: @"No valid keys found in data."}];
        }
        return NO;
    }

    // For each imported PGP key, create an OPKey model and store it
    OPKeyStore *store = [OPKeyStore sharedStore];
    for (PGPKey *pgpKey in importedKeys) {
        OPKey *opKey = [self opKeyFromPGPKey:pgpKey];
        if (opKey) {
            // Check if key already exists in store
            OPKey *existingKey = [store keyWithKeyID:opKey.keyID];
            if (existingKey) {
                // Merge: if the existing key doesn't have a secret part but the new one does, update
                if (!existingKey.isSecretKey && opKey.isSecretKey) {
                    existingKey.isSecretKey = YES;
                    existingKey.armoredSecretKey = opKey.armoredSecretKey;
                    [store updateKey:existingKey];
                } else {
                    [store updateKey:opKey];
                }
            } else {
                [store insertKey:opKey];
            }
        }
    }

    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"OPKeyringDidChangeNotification"
                                                        object:self];

    return YES;
}

- (NSString *)exportArmoredPublicKeyForKeyID:(NSString *)keyID error:(NSError **)error
{
    if (!keyID || [keyID length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:110
                                     userInfo:@{NSLocalizedDescriptionKey: @"Key ID is required for export."}];
        }
        return nil;
    }

    [_pgpLock lock];

    PGPKey *pgpKey = [self pgpKeyForKeyID:keyID];
    if (!pgpKey) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:111
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"No key found for key ID %@", keyID]}];
        }
        return nil;
    }

    NSError *exportError = nil;
    NSData *publicKeyData = [pgpKey export:PGPPartialKeyPublic error:&exportError];
    [_pgpLock unlock];

    if (!publicKeyData) {
        if (error) {
            *error = exportError ?: [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                                        code:112
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to export public key."}];
        }
        return nil;
    }

    NSString *armoredKey = [PGPArmor armoredData:publicKeyData as:PGPArmorTypePublicKey];
    return armoredKey;
}

- (NSString *)exportArmoredSecretKeyForKeyID:(NSString *)keyID error:(NSError **)error
{
    if (!keyID || [keyID length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:120
                                     userInfo:@{NSLocalizedDescriptionKey: @"Key ID is required for export."}];
        }
        return nil;
    }

    [_pgpLock lock];

    PGPKey *pgpKey = [self pgpKeyForKeyID:keyID];
    if (!pgpKey) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:121
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"No key found for key ID %@", keyID]}];
        }
        return nil;
    }

    if (!pgpKey.secretKey) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:122
                                     userInfo:@{NSLocalizedDescriptionKey: @"Key does not have a secret component."}];
        }
        return nil;
    }

    NSError *exportError = nil;
    NSData *secretKeyData = [pgpKey export:PGPPartialKeySecret error:&exportError];
    [_pgpLock unlock];

    if (!secretKeyData) {
        if (error) {
            *error = exportError ?: [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                                        code:123
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to export secret key."}];
        }
        return nil;
    }

    NSString *armoredKey = [PGPArmor armoredData:secretKeyData as:PGPArmorTypeSecretKey];
    return armoredKey;
}

#pragma mark - Encrypt / Decrypt

- (NSString *)encryptMessage:(NSString *)plaintext
             forRecipientIDs:(NSArray *)recipientKeyIDs
                  signWithID:(NSString *)signerKeyID
                  passphrase:(NSString *)passphrase
                       error:(NSError **)error
{
    if (!plaintext || [plaintext length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:200
                                     userInfo:@{NSLocalizedDescriptionKey: @"Plaintext message is empty."}];
        }
        return nil;
    }

    if (!recipientKeyIDs || [recipientKeyIDs count] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:201
                                     userInfo:@{NSLocalizedDescriptionKey: @"At least one recipient key ID is required."}];
        }
        return nil;
    }

    [_pgpLock lock];

    // Collect recipient PGPKey objects
    NSMutableArray *recipientKeys = [NSMutableArray array];
    for (NSString *recipientKeyID in recipientKeyIDs) {
        PGPKey *recipientKey = [self pgpKeyForKeyID:recipientKeyID];
        if (recipientKey) {
            [recipientKeys addObject:recipientKey];
        } else {
            NSLog(@"OPPGPService: Recipient key not found for ID %@", recipientKeyID);
        }
    }

    if ([recipientKeys count] == 0) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:202
                                     userInfo:@{NSLocalizedDescriptionKey: @"No valid recipient keys found."}];
        }
        return nil;
    }

    // Optionally find the signer key
    PGPKey *signerKey = nil;
    if (signerKeyID && [signerKeyID length] > 0) {
        signerKey = [self pgpKeyForKeyID:signerKeyID];
        if (!signerKey) {
            NSLog(@"OPPGPService: Signer key not found for ID %@, proceeding without signing.", signerKeyID);
        } else if (!signerKey.secretKey) {
            NSLog(@"OPPGPService: Signer key %@ has no secret component, cannot sign.", signerKeyID);
            signerKey = nil;
        }
    }

    NSData *plaintextData = [plaintext dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptedData = nil;
    NSError *encryptionError = nil;

    @try {
        if (signerKey && passphrase) {
            // Encrypt and sign
            encryptedData = [_pgp encryptData:plaintextData
                              usingKeys:recipientKeys
                           signWithKey:signerKey
                            passphrase:passphrase
                              armored:NO
                                error:&encryptionError];
        } else {
            // Encrypt only (no signing)
            encryptedData = [_pgp encryptData:plaintextData
                              usingKeys:recipientKeys
                           signWithKey:nil
                            passphrase:nil
                              armored:NO
                                error:&encryptionError];
        }
    } @catch (NSException *exception) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:203
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Encryption failed: %@", exception.reason]}];
        }
        return nil;
    }

    [_pgpLock unlock];

    if (!encryptedData) {
        if (error) {
            *error = encryptionError ?: [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                                            code:204
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Encryption produced no output."}];
        }
        return nil;
    }

    // Armor the encrypted data
    NSString *armoredOutput = [PGPArmor armoredData:encryptedData as:PGPArmorTypeMessage];
    if (!armoredOutput || [armoredOutput length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:205
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to armor encrypted data."}];
        }
        return nil;
    }

    return armoredOutput;
}

- (OPMessage *)decryptArmoredMessage:(NSString *)armoredMessage
                          passphrase:(NSString *)passphrase
                               error:(NSError **)error
{
    if (!armoredMessage || [armoredMessage length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:210
                                     userInfo:@{NSLocalizedDescriptionKey: @"Armored message is empty."}];
        }
        return nil;
    }

    // De-armor the message
    NSData *messageData = [PGPArmor readArmoredData:armoredMessage];
    if (!messageData) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:211
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse armored message."}];
        }
        return nil;
    }

    [_pgpLock lock];

    OPMessage *message = [[OPMessage alloc] init];
    message.armoredText = armoredMessage;
    message.isEncrypted = YES;

    NSData *decryptedData = nil;
    NSError *decryptionError = nil;

    @try {
        // Try to find the appropriate secret key for decryption
        // ObjectivePGP will search loaded keys for matching recipient key
        NSArray *allLoadedKeys = [_pgp keys];

        // Build the list of secret keys we can try
        NSMutableArray *secretKeys = [NSMutableArray array];
        for (PGPKey *key in allLoadedKeys) {
            if (key.secretKey) {
                [secretKeys addObject:key];
            }
        }

        if ([secretKeys count] == 0) {
            [_pgpLock unlock];
            if (error) {
                *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                             code:212
                                         userInfo:@{NSLocalizedDescriptionKey: @"No secret keys available for decryption."}];
            }
            message.decryptionError = @"No secret keys available for decryption.";
            return message;
        }

        // Attempt decryption
        decryptedData = [_pgp decryptData:messageData
                              passphrase:passphrase
                                   error:&decryptionError];

    } @catch (NSException *exception) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:213
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Decryption failed: %@", exception.reason]}];
        }
        message.decryptionError = exception.reason;
        return message;
    }

    if (!decryptedData) {
        [_pgpLock unlock];
        NSString *errorDesc = decryptionError.localizedDescription ?: @"Decryption failed. Wrong passphrase or missing key.";
        if (error) {
            *error = decryptionError ?: [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                                            code:214
                                                        userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
        }
        message.decryptionError = errorDesc;
        return message;
    }

    // Convert decrypted data to plaintext string
    NSString *plaintext = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    if (!plaintext) {
        // Try Latin-1 as fallback
        plaintext = [[NSString alloc] initWithData:decryptedData encoding:NSISOLatin1StringEncoding];
    }

    message.plaintext = plaintext ?: @"";

    // Check for signatures in the decrypted message
    @try {
        NSError *verifyError = nil;
        BOOL signatureVerified = [_pgp verifyData:messageData error:&verifyError];

        message.isSigned = YES;
        message.signatureVerified = signatureVerified;

        if (!signatureVerified && verifyError) {
            message.signatureError = verifyError.localizedDescription;
        }
    } @catch (NSException *exception) {
        // No signature or verification failed -- not necessarily an error
        message.isSigned = NO;
        message.signatureVerified = NO;
    }

    [_pgpLock unlock];

    return message;
}

#pragma mark - Sign / Verify

- (NSString *)signMessage:(NSString *)plaintext
               withKeyID:(NSString *)signerKeyID
              passphrase:(NSString *)passphrase
                   error:(NSError **)error
{
    if (!plaintext || [plaintext length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:300
                                     userInfo:@{NSLocalizedDescriptionKey: @"Plaintext message is empty."}];
        }
        return nil;
    }

    if (!signerKeyID || [signerKeyID length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:301
                                     userInfo:@{NSLocalizedDescriptionKey: @"Signer key ID is required."}];
        }
        return nil;
    }

    if (!passphrase) {
        // Try to get passphrase from cache
        passphrase = [[OPPassphraseCache sharedCache] cachedPassphraseForKeyID:signerKeyID];
        if (!passphrase) {
            passphrase = [[OPPassphraseCache sharedCache] passphraseForKeyID:signerKeyID];
        }
        if (!passphrase) {
            if (error) {
                *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                             code:302
                                         userInfo:@{NSLocalizedDescriptionKey: @"Passphrase is required for signing."}];
            }
            return nil;
        }
    }

    [_pgpLock lock];

    PGPKey *signerKey = [self pgpKeyForKeyID:signerKeyID];
    if (!signerKey) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:303
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Signer key not found for ID %@", signerKeyID]}];
        }
        return nil;
    }

    if (!signerKey.secretKey) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:304
                                     userInfo:@{NSLocalizedDescriptionKey: @"Signer key does not have a secret component."}];
        }
        return nil;
    }

    NSData *plaintextData = [plaintext dataUsingEncoding:NSUTF8StringEncoding];
    NSData *signedData = nil;
    NSError *signError = nil;

    @try {
        // Clearsign the message
        signedData = [_pgp signData:plaintextData
                        usingKey:signerKey
                      passphrase:passphrase
                        detached:NO
                           error:&signError];
    } @catch (NSException *exception) {
        [_pgpLock unlock];
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:305
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Signing failed: %@", exception.reason]}];
        }
        return nil;
    }

    [_pgpLock unlock];

    if (!signedData) {
        if (error) {
            *error = signError ?: [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                                      code:306
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Signing produced no output."}];
        }
        return nil;
    }

    // Armor the signed data
    NSString *armoredSigned = [PGPArmor armoredData:signedData as:PGPArmorTypeMessage];

    // If ObjectivePGP returns cleartext signed, it may already be armored
    if (!armoredSigned) {
        // Try returning as UTF8 string directly (cleartext signed messages are already ASCII)
        armoredSigned = [[NSString alloc] initWithData:signedData encoding:NSUTF8StringEncoding];
    }

    if (!armoredSigned || [armoredSigned length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:307
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to armor signed message."}];
        }
        return nil;
    }

    return armoredSigned;
}

- (OPMessage *)verifySignedMessage:(NSString *)armoredMessage
                             error:(NSError **)error
{
    if (!armoredMessage || [armoredMessage length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:310
                                     userInfo:@{NSLocalizedDescriptionKey: @"Armored message is empty."}];
        }
        return nil;
    }

    OPMessage *message = [[OPMessage alloc] init];
    message.armoredText = armoredMessage;
    message.isSigned = YES;
    message.isEncrypted = NO;

    // Check for cleartext signed message format
    BOOL isCleartextSigned = [armoredMessage rangeOfString:@"-----BEGIN PGP SIGNED MESSAGE-----"].location != NSNotFound;

    NSData *messageData = nil;

    if (isCleartextSigned) {
        // For cleartext signed messages, extract the plaintext body
        NSRange hashHeaderRange = [armoredMessage rangeOfString:@"Hash:"];
        NSRange signatureBeginRange = [armoredMessage rangeOfString:@"-----BEGIN PGP SIGNATURE-----"];

        if (hashHeaderRange.location != NSNotFound && signatureBeginRange.location != NSNotFound) {
            // Find the end of the Hash header line
            NSRange afterHash = NSMakeRange(hashHeaderRange.location, armoredMessage.length - hashHeaderRange.location);
            NSRange newlineAfterHash = [armoredMessage rangeOfString:@"\n\n" options:0 range:afterHash];

            if (newlineAfterHash.location != NSNotFound) {
                NSUInteger bodyStart = NSMaxRange(newlineAfterHash);
                NSUInteger bodyEnd = signatureBeginRange.location;

                if (bodyEnd > bodyStart) {
                    NSString *bodyText = [armoredMessage substringWithRange:NSMakeRange(bodyStart, bodyEnd - bodyStart)];
                    // Remove trailing whitespace/newlines before the signature block
                    bodyText = [bodyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                    // Unescape dash-escaped lines (lines starting with "- " become original)
                    NSMutableArray *lines = [[bodyText componentsSeparatedByString:@"\n"] mutableCopy];
                    for (NSUInteger i = 0; i < [lines count]; i++) {
                        NSString *line = lines[i];
                        if ([line hasPrefix:@"- "]) {
                            lines[i] = [line substringFromIndex:2];
                        }
                    }
                    message.plaintext = [lines componentsJoinedByString:@"\n"];
                }
            }
        }

        messageData = [armoredMessage dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        // Binary signed message
        messageData = [PGPArmor readArmoredData:armoredMessage];
    }

    if (!messageData) {
        if (error) {
            *error = [NSError errorWithDomain:kOPPGPServiceErrorDomain
                                         code:311
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse signed message."}];
        }
        return message;
    }

    [_pgpLock lock];

    @try {
        NSError *verifyError = nil;
        BOOL verified = [_pgp verifyData:messageData error:&verifyError];

        message.signatureVerified = verified;

        if (!verified) {
            if (verifyError) {
                message.signatureError = verifyError.localizedDescription;
            } else {
                message.signatureError = @"Signature verification failed. The signer's public key may not be available.";
            }
        }
    } @catch (NSException *exception) {
        message.signatureVerified = NO;
        message.signatureError = [NSString stringWithFormat:@"Verification error: %@", exception.reason];
    }

    [_pgpLock unlock];

    return message;
}

#pragma mark - Private Helpers

- (PGPKey *)pgpKeyForKeyID:(NSString *)keyID
{
    // Search through loaded keys for one matching the key ID
    // Key IDs may be 8 or 16 hex characters (short or long form)
    NSString *normalizedKeyID = [[keyID uppercaseString] stringByReplacingOccurrencesOfString:@"0X" withString:@""];

    NSArray *allKeys = [_pgp keys];
    for (PGPKey *key in allKeys) {
        NSString *thisKeyID = [[[key keyID] description] uppercaseString];

        // Try exact match first
        if ([thisKeyID isEqualToString:normalizedKeyID]) {
            return key;
        }

        // Try suffix match (short key ID matching long key ID)
        if ([normalizedKeyID length] >= 8 && [thisKeyID length] >= 8) {
            NSString *shortThis = [thisKeyID substringFromIndex:[thisKeyID length] - 8];
            NSString *shortTarget = [normalizedKeyID substringFromIndex:[normalizedKeyID length] - 8];
            if ([shortThis isEqualToString:shortTarget]) {
                return key;
            }
        }

        // Also check subkeys
        if (key.publicKey) {
            for (PGPPartialSubKey *subKey in key.publicKey.subKeys) {
                NSString *subKeyID = [[[subKey keyID] description] uppercaseString];
                if ([subKeyID isEqualToString:normalizedKeyID]) {
                    return key;
                }
                if ([normalizedKeyID length] >= 8 && [subKeyID length] >= 8) {
                    NSString *shortSub = [subKeyID substringFromIndex:[subKeyID length] - 8];
                    NSString *shortTarget = [normalizedKeyID substringFromIndex:[normalizedKeyID length] - 8];
                    if ([shortSub isEqualToString:shortTarget]) {
                        return key;
                    }
                }
            }
        }

        if (key.secretKey) {
            for (PGPPartialSubKey *subKey in key.secretKey.subKeys) {
                NSString *subKeyID = [[[subKey keyID] description] uppercaseString];
                if ([subKeyID isEqualToString:normalizedKeyID]) {
                    return key;
                }
            }
        }
    }

    return nil;
}

- (OPKey *)opKeyFromPGPKey:(PGPKey *)pgpKey
{
    if (!pgpKey) {
        return nil;
    }

    OPKey *opKey = [[OPKey alloc] init];
    opKey.keyID = [[pgpKey keyID] description];
    opKey.fingerprint = [[pgpKey primaryKeyPacket] fingerprint].description;
    opKey.algorithm = OPKeyAlgorithmRSA;
    opKey.creationDate = [pgpKey primaryKeyPacket].createDate;
    opKey.isSecretKey = (pgpKey.secretKey != nil);
    opKey.isRevoked = NO;
    opKey.ownerTrust = OPTrustLevelUnknown;

    // Extract key size from the primary key packet
    PGPPublicKeyPacket *primaryPacket = (PGPPublicKeyPacket *)[pgpKey primaryKeyPacket];
    if ([primaryPacket respondsToSelector:@selector(keySize)]) {
        opKey.keySize = [primaryPacket keySize];
    } else {
        opKey.keySize = 0;
    }

    // Export armored keys
    @try {
        NSError *exportErr = nil;
        NSData *pubData = [pgpKey export:PGPPartialKeyPublic error:&exportErr];
        if (pubData) {
            opKey.armoredPublicKey = [PGPArmor armoredData:pubData as:PGPArmorTypePublicKey];
        }

        if (pgpKey.secretKey) {
            NSData *secData = [pgpKey export:PGPPartialKeySecret error:&exportErr];
            if (secData) {
                opKey.armoredSecretKey = [PGPArmor armoredData:secData as:PGPArmorTypeSecretKey];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"OPPGPService: Failed to export key %@: %@", opKey.keyID, exception.reason);
    }

    // Extract user IDs
    NSMutableArray *userIDs = [NSMutableArray array];
    NSArray *pgpUsers = nil;
    if (pgpKey.publicKey) {
        pgpUsers = pgpKey.publicKey.users;
    } else if (pgpKey.secretKey) {
        pgpUsers = pgpKey.secretKey.users;
    }

    BOOL firstUID = YES;
    for (PGPUser *pgpUser in pgpUsers) {
        OPUserID *uid = [[OPUserID alloc] init];
        uid.userIDString = pgpUser.userID;
        uid.parentKeyID = opKey.keyID;
        uid.isPrimary = firstUID;

        // Parse "Name (Comment) <email>" format
        [self parseUserIDString:pgpUser.userID intoUserID:uid];

        [userIDs addObject:uid];

        if (firstUID) {
            opKey.primaryUserID = uid;
            firstUID = NO;
        }
    }
    opKey.userIDs = [NSArray arrayWithArray:userIDs];

    // Extract subkeys
    NSMutableArray *subkeys = [NSMutableArray array];
    NSArray *pgpSubKeys = nil;
    if (pgpKey.publicKey) {
        pgpSubKeys = pgpKey.publicKey.subKeys;
    }
    for (PGPPartialSubKey *pgpSubkey in pgpSubKeys) {
        OPSubkey *subkey = [[OPSubkey alloc] init];
        subkey.keyID = [[pgpSubkey keyID] description];
        subkey.fingerprint = [pgpSubkey.primaryKeyPacket fingerprint].description;
        subkey.algorithm = OPKeyAlgorithmRSA;
        subkey.creationDate = pgpSubkey.primaryKeyPacket.createDate;
        subkey.parentKeyID = opKey.keyID;
        subkey.canSign = NO;  // Subkeys typically used for encryption
        subkey.canEncrypt = YES;
        [subkeys addObject:subkey];
    }
    opKey.subkeys = [NSArray arrayWithArray:subkeys];

    // Signatures (extracted from user ID certification packets)
    opKey.signatures = @[];

    return opKey;
}

- (void)parseUserIDString:(NSString *)uidString intoUserID:(OPUserID *)uid
{
    if (!uidString || [uidString length] == 0) {
        return;
    }

    // Format: "Name (Comment) <email>" or "Name <email>" or just "Name"
    NSString *remaining = [uidString copy];

    // Extract email
    NSRange emailStart = [remaining rangeOfString:@"<"];
    NSRange emailEnd = [remaining rangeOfString:@">"];
    if (emailStart.location != NSNotFound && emailEnd.location != NSNotFound && emailEnd.location > emailStart.location) {
        uid.email = [remaining substringWithRange:NSMakeRange(emailStart.location + 1,
                                                               emailEnd.location - emailStart.location - 1)];
        remaining = [[remaining substringToIndex:emailStart.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    // Extract comment
    NSRange commentStart = [remaining rangeOfString:@"("];
    NSRange commentEnd = [remaining rangeOfString:@")"];
    if (commentStart.location != NSNotFound && commentEnd.location != NSNotFound && commentEnd.location > commentStart.location) {
        uid.comment = [remaining substringWithRange:NSMakeRange(commentStart.location + 1,
                                                                 commentEnd.location - commentStart.location - 1)];
        remaining = [[remaining substringToIndex:commentStart.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    uid.name = [remaining stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

@end
