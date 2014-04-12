//
//  OPMessage.m
//  onlyPGP
//
//  Created 2014. OpenPGP message model.
//

#import "OPMessage.h"

@implementation OPMessage

- (instancetype)init
{
    self = [super init];
    if (self) {
        _isEncrypted = NO;
        _isSigned = NO;
        _signatureVerified = NO;
    }
    return self;
}

- (instancetype)initWithArmoredText:(NSString *)armoredText
{
    self = [self init];
    if (self) {
        _armoredText = [armoredText copy];
        [self detectMessageType];
    }
    return self;
}

- (instancetype)initWithPlaintext:(NSString *)plaintext
                       recipients:(NSArray *)recipientKeyIDs
                      signerKeyID:(NSString *)signerKeyID
{
    self = [self init];
    if (self) {
        _plaintext = [plaintext copy];
        _recipientKeyIDs = [recipientKeyIDs copy];
        _signerKeyID = [signerKeyID copy];
        _isEncrypted = ([recipientKeyIDs count] > 0);
        _isSigned = (signerKeyID != nil && [signerKeyID length] > 0);
    }
    return self;
}

#pragma mark - Private

- (void)detectMessageType
{
    if (!_armoredText) {
        return;
    }

    NSRange messageRange = [_armoredText rangeOfString:@"-----BEGIN PGP MESSAGE-----"];
    if (messageRange.location != NSNotFound) {
        _isEncrypted = YES;
    }

    NSRange signedRange = [_armoredText rangeOfString:@"-----BEGIN PGP SIGNED MESSAGE-----"];
    if (signedRange.location != NSNotFound) {
        _isSigned = YES;
        _isEncrypted = NO;
    }

    NSRange sigRange = [_armoredText rangeOfString:@"-----BEGIN PGP SIGNATURE-----"];
    if (sigRange.location != NSNotFound) {
        _isSigned = YES;
    }
}

- (NSString *)description
{
    NSMutableString *desc = [[NSMutableString alloc] initWithString:@"<OPMessage:"];

    if (_isEncrypted) {
        [desc appendString:@" encrypted"];
    }
    if (_isSigned) {
        [desc appendFormat:@" signed-by:%@", _signerKeyID ?: @"unknown"];
        if (_signatureVerified) {
            [desc appendString:@" (verified)"];
        }
    }
    if (_recipientKeyIDs && [_recipientKeyIDs count] > 0) {
        [desc appendFormat:@" recipients:%@", @([_recipientKeyIDs count])];
    }

    [desc appendString:@">"];
    return [NSString stringWithString:desc];
}

@end
