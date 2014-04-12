//
//  NSData+OPHex.m
//  onlyPGP
//
//  Created 2014. Hex encoding/decoding utilities.
//

#import "NSData+OPHex.h"

@implementation NSData (OPHex)

- (NSString *)op_hexString
{
    const unsigned char *bytes = [self bytes];
    NSUInteger length = [self length];
    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:length * 2];

    for (NSUInteger i = 0; i < length; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }

    return [NSString stringWithString:hex];
}

- (NSString *)op_uppercaseHexString
{
    const unsigned char *bytes = [self bytes];
    NSUInteger length = [self length];
    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:length * 2];

    for (NSUInteger i = 0; i < length; i++) {
        [hex appendFormat:@"%02X", bytes[i]];
    }

    return [NSString stringWithString:hex];
}

- (NSString *)op_fingerprintString
{
    NSString *upperHex = [self op_uppercaseHexString];
    NSUInteger length = [upperHex length];

    if (length == 0) {
        return @"";
    }

    NSMutableString *formatted = [[NSMutableString alloc] initWithCapacity:length + (length / 4)];

    for (NSUInteger i = 0; i < length; i++) {
        if (i > 0 && i % 4 == 0) {
            [formatted appendString:@" "];
        }
        [formatted appendFormat:@"%C", [upperHex characterAtIndex:i]];
    }

    return [NSString stringWithString:formatted];
}

+ (NSData *)op_dataWithHexString:(NSString *)hexString
{
    if (!hexString) {
        return nil;
    }

    // Strip spaces and normalize
    NSString *clean = [[hexString stringByReplacingOccurrencesOfString:@" " withString:@""]
                        stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    clean = [clean lowercaseString];

    NSUInteger length = [clean length];

    // Must be even number of characters
    if (length % 2 != 0) {
        return nil;
    }

    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:length / 2];

    for (NSUInteger i = 0; i < length; i += 2) {
        unsigned int byteValue = 0;
        unichar highChar = [clean characterAtIndex:i];
        unichar lowChar = [clean characterAtIndex:i + 1];

        int high = [self hexValueForChar:highChar];
        int low = [self hexValueForChar:lowChar];

        if (high < 0 || low < 0) {
            return nil; // Invalid hex character
        }

        byteValue = (unsigned int)((high << 4) | low);
        uint8_t byte = (uint8_t)byteValue;
        [data appendBytes:&byte length:1];
    }

    return [NSData dataWithData:data];
}

#pragma mark - Private

+ (int)hexValueForChar:(unichar)c
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return 10 + (c - 'a');
    if (c >= 'A' && c <= 'F') return 10 + (c - 'A');
    return -1;
}

@end
