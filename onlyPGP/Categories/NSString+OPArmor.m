//
//  NSString+OPArmor.m
//  onlyPGP
//
//  Created 2014. PGP ASCII armor utilities.
//

#import "NSString+OPArmor.h"

@implementation NSString (OPArmor)

- (BOOL)op_isArmoredPGPBlock
{
    return [self rangeOfString:@"-----BEGIN PGP "].location != NSNotFound;
}

- (BOOL)op_isArmoredPublicKey
{
    return [self rangeOfString:@"-----BEGIN PGP PUBLIC KEY BLOCK-----"].location != NSNotFound;
}

- (BOOL)op_isArmoredPrivateKey
{
    return ([self rangeOfString:@"-----BEGIN PGP PRIVATE KEY BLOCK-----"].location != NSNotFound ||
            [self rangeOfString:@"-----BEGIN PGP SECRET KEY BLOCK-----"].location != NSNotFound);
}

- (BOOL)op_isArmoredMessage
{
    return [self rangeOfString:@"-----BEGIN PGP MESSAGE-----"].location != NSNotFound;
}

- (BOOL)op_isArmoredSignature
{
    return ([self rangeOfString:@"-----BEGIN PGP SIGNATURE-----"].location != NSNotFound ||
            [self rangeOfString:@"-----BEGIN PGP SIGNED MESSAGE-----"].location != NSNotFound);
}

- (NSString *)op_extractArmoredBlock
{
    // Find the first -----BEGIN PGP marker and its matching -----END PGP marker
    NSRange beginRange = [self rangeOfString:@"-----BEGIN PGP "];
    if (beginRange.location == NSNotFound) {
        return nil;
    }

    // Find the end of the BEGIN line (including the trailing dashes)
    NSRange beginLineEnd = [self rangeOfString:@"-----"
                                       options:0
                                         range:NSMakeRange(beginRange.location + beginRange.length,
                                                           [self length] - beginRange.location - beginRange.length)];
    if (beginLineEnd.location == NSNotFound) {
        return nil;
    }

    // Extract the block type from the BEGIN line
    NSRange typeRange = NSMakeRange(beginRange.location + 15,
                                    beginLineEnd.location + 5 - beginRange.location - 15);
    NSString *blockType = [self substringWithRange:typeRange];

    // Build the expected END marker
    NSString *endMarker = [NSString stringWithFormat:@"-----END PGP %@", blockType];
    NSRange endRange = [self rangeOfString:endMarker];
    if (endRange.location == NSNotFound) {
        return nil;
    }

    // Find the end of the END line
    NSRange endLineEnd = [self rangeOfString:@"\n"
                                     options:0
                                       range:NSMakeRange(endRange.location,
                                                         MIN([self length] - endRange.location, 200))];

    NSUInteger endPos;
    if (endLineEnd.location != NSNotFound) {
        endPos = endLineEnd.location + 1;
    } else {
        endPos = [self length];
    }

    return [self substringWithRange:NSMakeRange(beginRange.location,
                                                 endPos - beginRange.location)];
}

- (NSString *)op_stripArmorHeaders
{
    NSMutableArray *outputLines = [[NSMutableArray alloc] init];
    NSArray *lines = [self componentsSeparatedByString:@"\n"];

    BOOL inHeaders = NO;
    BOOL passedHeaders = NO;

    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // Detect BEGIN line — keep it, start watching for headers
        if ([trimmed hasPrefix:@"-----BEGIN PGP "]) {
            [outputLines addObject:line];
            inHeaders = YES;
            passedHeaders = NO;
            continue;
        }

        // If we're in the header section after BEGIN
        if (inHeaders && !passedHeaders) {
            // Blank line marks end of headers
            if ([trimmed length] == 0) {
                inHeaders = NO;
                passedHeaders = YES;
                [outputLines addObject:line];
                continue;
            }
            // Header lines contain a colon (e.g., "Version:", "Comment:", "Hash:")
            if ([trimmed rangeOfString:@":"].location != NSNotFound) {
                // Skip this header line
                continue;
            }
            // Not a header — we've passed headers already (no blank line separator)
            inHeaders = NO;
            passedHeaders = YES;
            [outputLines addObject:line];
            continue;
        }

        [outputLines addObject:line];
    }

    return [outputLines componentsJoinedByString:@"\n"];
}

- (NSArray *)op_splitIntoChunksOfLength:(NSUInteger)length
{
    if (length == 0) {
        return @[self];
    }

    NSMutableArray *chunks = [[NSMutableArray alloc] init];
    NSUInteger totalLength = [self length];
    NSUInteger offset = 0;

    while (offset < totalLength) {
        NSUInteger chunkLen = MIN(length, totalLength - offset);
        NSString *chunk = [self substringWithRange:NSMakeRange(offset, chunkLen)];
        [chunks addObject:chunk];
        offset += chunkLen;
    }

    return [NSArray arrayWithArray:chunks];
}

@end
