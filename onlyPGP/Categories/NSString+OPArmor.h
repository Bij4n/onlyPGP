//
//  NSString+OPArmor.h
//  onlyPGP
//
//  Created 2014. PGP ASCII armor utilities.
//

#import <Foundation/Foundation.h>

@interface NSString (OPArmor)

- (BOOL)op_isArmoredPGPBlock;
- (BOOL)op_isArmoredPublicKey;
- (BOOL)op_isArmoredPrivateKey;
- (BOOL)op_isArmoredMessage;
- (BOOL)op_isArmoredSignature;
- (NSString *)op_extractArmoredBlock;
- (NSString *)op_stripArmorHeaders;
- (NSArray *)op_splitIntoChunksOfLength:(NSUInteger)length;

@end
