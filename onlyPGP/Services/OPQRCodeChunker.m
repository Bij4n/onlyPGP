//
//  OPQRCodeChunker.m
//  onlyPGP
//
//  Created 2014. Splits armored PGP keys into QR code chunks and reassembles.
//

#import "OPQRCodeChunker.h"

static NSString * const kOPQRChunkPrefix = @"OPPGP";
static NSString * const kOPQRChunkSeparator = @":";
static const NSUInteger kOPQRDefaultMaxChunkSize = 800;

// Chunk format: "OPPGP:CHUNK_INDEX:TOTAL_CHUNKS:DATA"
// CHUNK_INDEX is 1-based.

@interface OPQRCodeChunker ()

@property (nonatomic, assign) NSUInteger expectedChunkCount;
@property (nonatomic, strong) NSMutableDictionary *receivedChunks; // index (NSNumber) -> data (NSString)
@property (nonatomic, assign) NSUInteger totalFromFirstChunk;      // total count extracted from first parsed chunk

@end

@implementation OPQRCodeChunker

#pragma mark - Class Methods (Chunking for Display)

+ (NSArray *)chunksForArmoredKey:(NSString *)armoredKey maxChunkSize:(NSUInteger)maxSize
{
    if (!armoredKey || [armoredKey length] == 0) {
        return @[];
    }

    if (maxSize == 0) {
        maxSize = kOPQRDefaultMaxChunkSize;
    }

    // Calculate the header overhead to determine actual data capacity per chunk
    // Header format: "OPPGP:XX:XX:" -- worst case is about 15 characters for "OPPGP:99:99:"
    // We need to account for this overhead when splitting
    NSUInteger totalLength = [armoredKey length];

    // First pass: estimate chunk count to know header size
    NSUInteger estimatedChunks = [self chunkCountForArmoredKey:armoredKey maxChunkSize:maxSize];
    if (estimatedChunks == 0) {
        estimatedChunks = 1;
    }

    // Calculate actual overhead per chunk
    NSUInteger headerOverhead = [kOPQRChunkPrefix length] + 1; // "OPPGP:"
    headerOverhead += [self digitsInNumber:estimatedChunks] + 1; // "INDEX:"
    headerOverhead += [self digitsInNumber:estimatedChunks] + 1; // "TOTAL:"

    NSUInteger dataCapacityPerChunk = maxSize - headerOverhead;
    if (dataCapacityPerChunk == 0 || dataCapacityPerChunk > maxSize) {
        // Safety: if overhead is somehow larger than max size, use a minimum capacity
        dataCapacityPerChunk = maxSize / 2;
    }

    // Split the armored key into data segments
    NSMutableArray *dataSegments = [NSMutableArray array];
    NSUInteger offset = 0;

    while (offset < totalLength) {
        NSUInteger remaining = totalLength - offset;
        NSUInteger segmentLength = MIN(dataCapacityPerChunk, remaining);

        NSString *segment = [armoredKey substringWithRange:NSMakeRange(offset, segmentLength)];
        [dataSegments addObject:segment];

        offset += segmentLength;
    }

    // Recalculate if our chunk count estimate was wrong
    NSUInteger actualChunkCount = [dataSegments count];
    if (actualChunkCount != estimatedChunks) {
        // The header size might have changed; re-split if needed
        // This handles edge cases where digit count changes (e.g., 9 -> 10 chunks)
        NSUInteger newHeaderOverhead = [kOPQRChunkPrefix length] + 1;
        newHeaderOverhead += [self digitsInNumber:actualChunkCount] + 1;
        newHeaderOverhead += [self digitsInNumber:actualChunkCount] + 1;

        if (newHeaderOverhead != headerOverhead) {
            dataCapacityPerChunk = maxSize - newHeaderOverhead;
            [dataSegments removeAllObjects];
            offset = 0;

            while (offset < totalLength) {
                NSUInteger remaining = totalLength - offset;
                NSUInteger segmentLength = MIN(dataCapacityPerChunk, remaining);
                NSString *segment = [armoredKey substringWithRange:NSMakeRange(offset, segmentLength)];
                [dataSegments addObject:segment];
                offset += segmentLength;
            }

            actualChunkCount = [dataSegments count];
        }
    }

    // Build the final chunk strings with headers
    NSMutableArray *chunks = [NSMutableArray arrayWithCapacity:actualChunkCount];

    for (NSUInteger i = 0; i < actualChunkCount; i++) {
        NSUInteger chunkIndex = i + 1; // 1-based index
        NSString *chunkString = [NSString stringWithFormat:@"%@%@%lu%@%lu%@%@",
                                 kOPQRChunkPrefix,
                                 kOPQRChunkSeparator,
                                 (unsigned long)chunkIndex,
                                 kOPQRChunkSeparator,
                                 (unsigned long)actualChunkCount,
                                 kOPQRChunkSeparator,
                                 dataSegments[i]];
        [chunks addObject:chunkString];
    }

    return [NSArray arrayWithArray:chunks];
}

+ (NSUInteger)chunkCountForArmoredKey:(NSString *)armoredKey maxChunkSize:(NSUInteger)maxSize
{
    if (!armoredKey || [armoredKey length] == 0) {
        return 0;
    }

    if (maxSize == 0) {
        maxSize = kOPQRDefaultMaxChunkSize;
    }

    NSUInteger totalLength = [armoredKey length];

    // Estimate header overhead conservatively
    // Start with an estimate assuming < 100 chunks
    NSUInteger headerOverhead = [kOPQRChunkPrefix length] + 1 + 2 + 1 + 2 + 1; // "OPPGP:XX:XX:"
    NSUInteger dataCapacity = maxSize - headerOverhead;

    if (dataCapacity == 0 || dataCapacity > maxSize) {
        dataCapacity = maxSize / 2;
    }

    NSUInteger chunkCount = (totalLength + dataCapacity - 1) / dataCapacity;

    // Refine if digits changed
    if (chunkCount >= 10) {
        headerOverhead = [kOPQRChunkPrefix length] + 1;
        headerOverhead += [self digitsInNumber:chunkCount] + 1;
        headerOverhead += [self digitsInNumber:chunkCount] + 1;
        dataCapacity = maxSize - headerOverhead;

        if (dataCapacity > 0 && dataCapacity <= maxSize) {
            chunkCount = (totalLength + dataCapacity - 1) / dataCapacity;
        }
    }

    return MAX(chunkCount, 1);
}

+ (NSUInteger)digitsInNumber:(NSUInteger)number
{
    if (number == 0) return 1;
    NSUInteger digits = 0;
    NSUInteger temp = number;
    while (temp > 0) {
        digits++;
        temp /= 10;
    }
    return digits;
}

#pragma mark - Instance Methods (Reassembly from Scanned Chunks)

- (instancetype)initWithExpectedChunkCount:(NSUInteger)count
{
    self = [super init];
    if (self) {
        _expectedChunkCount = count;
        _totalFromFirstChunk = 0;
        _receivedChunks = [NSMutableDictionary dictionaryWithCapacity:count];
    }
    return self;
}

- (instancetype)init
{
    // Default init with unknown count; will be determined from first chunk
    self = [super init];
    if (self) {
        _expectedChunkCount = 0;
        _totalFromFirstChunk = 0;
        _receivedChunks = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)addChunkString:(NSString *)chunkString
{
    if (!chunkString || [chunkString length] == 0) {
        return NO;
    }

    // Parse the chunk format: "OPPGP:CHUNK_INDEX:TOTAL_CHUNKS:DATA"
    // We need at least 4 components separated by ":"
    // But DATA itself might contain ":" characters, so we split carefully

    // First check the prefix
    if (![chunkString hasPrefix:kOPQRChunkPrefix]) {
        NSLog(@"OPQRCodeChunker: Chunk does not start with expected prefix '%@'", kOPQRChunkPrefix);
        return NO;
    }

    // Find the positions of the first 3 separators
    NSUInteger prefixLength = [kOPQRChunkPrefix length];
    NSString *afterPrefix = [chunkString substringFromIndex:prefixLength];

    // afterPrefix should be ":INDEX:TOTAL:DATA"
    if (![afterPrefix hasPrefix:kOPQRChunkSeparator]) {
        return NO;
    }

    afterPrefix = [afterPrefix substringFromIndex:1]; // Remove leading ":"

    // Find second separator (after INDEX)
    NSRange secondSep = [afterPrefix rangeOfString:kOPQRChunkSeparator];
    if (secondSep.location == NSNotFound) {
        return NO;
    }

    NSString *indexString = [afterPrefix substringToIndex:secondSep.location];
    NSString *afterIndex = [afterPrefix substringFromIndex:NSMaxRange(secondSep)];

    // Find third separator (after TOTAL)
    NSRange thirdSep = [afterIndex rangeOfString:kOPQRChunkSeparator];
    if (thirdSep.location == NSNotFound) {
        return NO;
    }

    NSString *totalString = [afterIndex substringToIndex:thirdSep.location];
    NSString *data = [afterIndex substringFromIndex:NSMaxRange(thirdSep)];

    // Parse index and total
    NSInteger chunkIndex = [indexString integerValue];
    NSInteger totalChunks = [totalString integerValue];

    // Validate
    if (chunkIndex < 1 || totalChunks < 1 || chunkIndex > totalChunks) {
        NSLog(@"OPQRCodeChunker: Invalid chunk header - index:%ld total:%ld", (long)chunkIndex, (long)totalChunks);
        return NO;
    }

    if (!data) {
        NSLog(@"OPQRCodeChunker: Chunk contains no data");
        return NO;
    }

    // If this is the first chunk we've received, set the total
    if (_totalFromFirstChunk == 0) {
        _totalFromFirstChunk = (NSUInteger)totalChunks;

        if (_expectedChunkCount == 0) {
            _expectedChunkCount = _totalFromFirstChunk;
        }
    }

    // Validate consistency
    if ((NSUInteger)totalChunks != _totalFromFirstChunk) {
        NSLog(@"OPQRCodeChunker: Inconsistent total chunk count. Expected %lu, got %ld",
              (unsigned long)_totalFromFirstChunk, (long)totalChunks);
        return NO;
    }

    if (_expectedChunkCount > 0 && (NSUInteger)totalChunks != _expectedChunkCount) {
        NSLog(@"OPQRCodeChunker: Total chunks %ld does not match expected %lu",
              (long)totalChunks, (unsigned long)_expectedChunkCount);
        return NO;
    }

    // Store the chunk data (1-based index)
    NSNumber *indexKey = @(chunkIndex);

    // Check for duplicate (same chunk scanned again)
    if (_receivedChunks[indexKey]) {
        // Already have this chunk -- still return YES (it's a valid chunk, just duplicate)
        NSLog(@"OPQRCodeChunker: Duplicate chunk %ld received, ignoring.", (long)chunkIndex);
        return YES;
    }

    _receivedChunks[indexKey] = data;

    NSLog(@"OPQRCodeChunker: Received chunk %ld of %ld (%.0f%% complete)",
          (long)chunkIndex, (long)totalChunks, [self progress] * 100.0f);

    return YES;
}

- (BOOL)isComplete
{
    if (_expectedChunkCount == 0) {
        return NO;
    }

    return [_receivedChunks count] >= _expectedChunkCount;
}

- (float)progress
{
    if (_expectedChunkCount == 0) {
        if (_totalFromFirstChunk > 0) {
            return (float)[_receivedChunks count] / (float)_totalFromFirstChunk;
        }
        return 0.0f;
    }

    return (float)[_receivedChunks count] / (float)_expectedChunkCount;
}

- (NSString *)assembledArmoredKey
{
    if (![self isComplete]) {
        NSLog(@"OPQRCodeChunker: Cannot assemble key -- not all chunks received. Missing: %@", [self missingChunkIndices]);
        return nil;
    }

    NSMutableString *assembled = [NSMutableString string];

    for (NSUInteger i = 1; i <= _expectedChunkCount; i++) {
        NSString *chunkData = _receivedChunks[@(i)];
        if (chunkData) {
            [assembled appendString:chunkData];
        } else {
            NSLog(@"OPQRCodeChunker: Missing chunk %lu during assembly", (unsigned long)i);
            return nil;
        }
    }

    // Validate the assembled string looks like an armored PGP key
    NSString *result = [NSString stringWithString:assembled];

    if ([result rangeOfString:@"-----BEGIN PGP"].location == NSNotFound) {
        NSLog(@"OPQRCodeChunker: Assembled data does not appear to be a valid armored PGP key");
        // Return it anyway -- the caller can validate
    }

    return result;
}

- (NSArray *)missingChunkIndices
{
    NSUInteger total = _expectedChunkCount;
    if (total == 0) {
        total = _totalFromFirstChunk;
    }
    if (total == 0) {
        return @[];
    }

    NSMutableArray *missing = [NSMutableArray array];

    for (NSUInteger i = 1; i <= total; i++) {
        if (!_receivedChunks[@(i)]) {
            [missing addObject:@(i)];
        }
    }

    return [NSArray arrayWithArray:missing];
}

- (void)reset
{
    [_receivedChunks removeAllObjects];
    _totalFromFirstChunk = 0;
    // Keep expectedChunkCount as originally set
}

@end
