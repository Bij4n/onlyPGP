//
//  NSData+OPHex.h
//  onlyPGP
//
//  Created 2014. Hex encoding/decoding utilities.
//

#import <Foundation/Foundation.h>

@interface NSData (OPHex)

- (NSString *)op_hexString;
- (NSString *)op_uppercaseHexString;
- (NSString *)op_fingerprintString;
+ (NSData *)op_dataWithHexString:(NSString *)hexString;

@end
