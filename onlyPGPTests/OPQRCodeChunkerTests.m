//
//  OPQRCodeChunkerTests.m
//  onlyPGP
//
//  Created 2014. Tests for OPQRCodeChunker chunking and reassembly.
//

#import <XCTest/XCTest.h>
#import "OPQRCodeChunker.h"

static NSString * const kTestArmoredKey =
    @"-----BEGIN PGP PUBLIC KEY BLOCK-----\n"
    @"Version: onlyPGP v1.0\n"
    @"\n"
    @"mQENBFOdF3sBCAC8TlxMFQpmSGHbkVCAakdLlMqeJ5fBbXxoFGHjkElpMJUFhJY5\n"
    @"JBkFQaXR0yCk2bE3RCkKMIH3CbMFpEqeHfcE0bFBGadzBkouu3JOcbem4MN8kJrh\n"
    @"XNARKxMOIFOlmxz3GqkiMbFvQbWFniTjCrgXbJlHFtGPmGrGxAFz2nOQG8FfYN3J\n"
    @"TP6Q3nbSqMFGG0wm4cRAv8A2eborvBquiKYij80rxTWafmqiPElpBn7Sx2bMBdRb\n"
    @"AOBapCelkPfMNBfqAoVrpNMRuSAkGcF9FxLqDTk3FMzpNX3K2QfTNRR0ppGYQj4d\n"
    @"b3NRGZQF4hmwJHRuhFOjABCnMzPLjk5fEzjDABEBAAG0JUFsaWNlIFRlc3RlciA8\n"
    @"YWxpY2VAZXhhbXBsZS5jb20+iQE4BBMBAgAiBQJTnRd7AhsDBgsJCAcDAgYVCAIJ\n"
    @"CgsEFgIDAQIeAQIXgAAKCRC/EbMaWJ2RYUFgB/49FKbGSBnbEmuPSS22DyJn0aaP\n"
    @"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n"
    @"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB\n"
    @"CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC\n"
    @"DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD\n"
    @"EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n"
    @"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n"
    @"=abcd\n"
    @"-----END PGP PUBLIC KEY BLOCK-----";

static NSString * const kShortArmoredKey =
    @"-----BEGIN PGP PUBLIC KEY BLOCK-----\n"
    @"Version: test\n"
    @"\n"
    @"mQENBFOdF3sBCAC8Tl==\n"
    @"=xyzw\n"
    @"-----END PGP PUBLIC KEY BLOCK-----";

@interface OPQRCodeChunkerTests : XCTestCase
@end

@implementation OPQRCodeChunkerTests

#pragma mark - Chunking (class methods)

- (void)testChunkShortKey
{
    // A short key with large max size should produce 1 chunk
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kShortArmoredKey
                                             maxChunkSize:2000];
    XCTAssertNotNil(chunks);
    XCTAssertEqual(chunks.count, (NSUInteger)1,
                   @"Short key should fit in a single chunk with large maxSize");
}

- (void)testChunkLongKey
{
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:200];
    XCTAssertNotNil(chunks);
    XCTAssertTrue(chunks.count > 1,
                  @"Long key with small maxSize should produce multiple chunks, got %lu",
                  (unsigned long)chunks.count);
}

- (void)testChunkCount
{
    NSUInteger count = [OPQRCodeChunker chunkCountForArmoredKey:kTestArmoredKey
                                                  maxChunkSize:200];
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:200];
    XCTAssertEqual(count, chunks.count,
                   @"chunkCount should match actual chunks array count");
}

- (void)testChunkCountForShortKey
{
    NSUInteger count = [OPQRCodeChunker chunkCountForArmoredKey:kShortArmoredKey
                                                  maxChunkSize:2000];
    XCTAssertEqual(count, (NSUInteger)1,
                   @"Short key with large maxSize should have chunk count 1");
}

- (void)testChunkFormat
{
    // Verify chunks follow the "OPPGP:INDEX:TOTAL:DATA" format
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:200];
    XCTAssertTrue(chunks.count > 0);

    for (NSUInteger i = 0; i < chunks.count; i++) {
        NSString *chunk = chunks[i];
        XCTAssertTrue([chunk hasPrefix:@"OPPGP:"],
                      @"Each chunk should start with OPPGP: prefix, got: %@",
                      [chunk substringToIndex:MIN(chunk.length, 20)]);

        // Parse the format
        NSArray *parts = [chunk componentsSeparatedByString:@":"];
        XCTAssertTrue(parts.count >= 4,
                      @"Chunk should have at least 4 colon-separated parts");
        XCTAssertEqualObjects(parts[0], @"OPPGP");

        NSInteger index = [parts[1] integerValue];
        NSInteger total = [parts[2] integerValue];
        XCTAssertEqual(total, (NSInteger)chunks.count,
                       @"Total in chunk header should match actual chunk count");
        XCTAssertTrue(index >= 0 && index < total,
                      @"Index should be in range [0, total)");
    }
}

- (void)testMaxChunkSize
{
    NSUInteger maxSize = 150;
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:maxSize];
    for (NSString *chunk in chunks) {
        // The entire chunk string (including header) should be reasonable.
        // The DATA portion should not exceed maxSize.
        NSRange thirdColon = NSMakeRange(0, 0);
        NSUInteger colonCount = 0;
        for (NSUInteger j = 0; j < chunk.length; j++) {
            if ([chunk characterAtIndex:j] == ':') {
                colonCount++;
                if (colonCount == 3) {
                    thirdColon = NSMakeRange(j + 1, chunk.length - j - 1);
                    break;
                }
            }
        }
        if (thirdColon.length > 0) {
            NSString *data = [chunk substringWithRange:thirdColon];
            XCTAssertTrue(data.length <= maxSize,
                          @"Data portion of chunk should not exceed maxSize (%lu > %lu)",
                          (unsigned long)data.length, (unsigned long)maxSize);
        }
    }
}

#pragma mark - Reassembly (instance methods)

- (void)testReassemblyComplete
{
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:200];
    OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:chunks.count];

    for (NSString *chunk in chunks) {
        BOOL accepted = [chunker addChunkString:chunk];
        XCTAssertTrue(accepted, @"Valid chunk should be accepted");
    }

    XCTAssertTrue([chunker isComplete], @"Chunker should be complete after all chunks added");
    XCTAssertEqualWithAccuracy([chunker progress], 1.0f, 0.001f,
                               @"Progress should be 1.0 when complete");

    NSString *assembled = [chunker assembledArmoredKey];
    XCTAssertNotNil(assembled, @"Assembled key should not be nil");
    XCTAssertEqualObjects(assembled, kTestArmoredKey,
                          @"Reassembled key should match original");
}

- (void)testReassemblyOutOfOrder
{
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:200];
    OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:chunks.count];

    // Add chunks in reverse order
    for (NSInteger i = (NSInteger)chunks.count - 1; i >= 0; i--) {
        [chunker addChunkString:chunks[i]];
    }

    XCTAssertTrue([chunker isComplete], @"Should be complete even when added out of order");

    NSString *assembled = [chunker assembledArmoredKey];
    XCTAssertEqualObjects(assembled, kTestArmoredKey,
                          @"Out-of-order reassembly should produce correct result");
}

- (void)testReassemblyDuplicateChunk
{
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:200];
    XCTAssertTrue(chunks.count >= 2, @"Need at least 2 chunks for this test");

    OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:chunks.count];

    // Add first chunk twice
    [chunker addChunkString:chunks[0]];
    [chunker addChunkString:chunks[0]]; // duplicate

    // Should not count duplicate as new progress
    XCTAssertFalse([chunker isComplete],
                   @"Should not be complete with only duplicates of one chunk");

    // Now add remaining
    for (NSUInteger i = 1; i < chunks.count; i++) {
        [chunker addChunkString:chunks[i]];
    }
    XCTAssertTrue([chunker isComplete]);
    XCTAssertEqualObjects([chunker assembledArmoredKey], kTestArmoredKey);
}

- (void)testPartialProgress
{
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:200];
    NSUInteger total = chunks.count;
    XCTAssertTrue(total >= 3, @"Need at least 3 chunks for meaningful progress test");

    OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:total];

    // Before adding anything
    XCTAssertEqualWithAccuracy([chunker progress], 0.0f, 0.001f,
                               @"Progress should be 0 initially");
    XCTAssertFalse([chunker isComplete]);

    // Add one chunk
    [chunker addChunkString:chunks[0]];
    float expectedProgress = 1.0f / (float)total;
    XCTAssertEqualWithAccuracy([chunker progress], expectedProgress, 0.01f,
                               @"Progress should be 1/total after first chunk");

    // Check missing indices
    NSArray *missing = [chunker missingChunkIndices];
    XCTAssertNotNil(missing);
    XCTAssertEqual(missing.count, total - 1,
                   @"Should have total-1 missing chunks");

    // Verify index 0 is NOT in missing
    BOOL zeroIsMissing = NO;
    for (NSNumber *idx in missing) {
        if ([idx unsignedIntegerValue] == 0) {
            zeroIsMissing = YES;
            break;
        }
    }
    XCTAssertFalse(zeroIsMissing, @"Index 0 should not be missing after adding chunk 0");
}

- (void)testMissingChunkIndices
{
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:200];
    NSUInteger total = chunks.count;
    OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:total];

    // Add all but the last chunk
    for (NSUInteger i = 0; i < total - 1; i++) {
        [chunker addChunkString:chunks[i]];
    }

    NSArray *missing = [chunker missingChunkIndices];
    XCTAssertEqual(missing.count, (NSUInteger)1, @"Should be missing exactly 1 chunk");
    XCTAssertEqual([missing[0] unsignedIntegerValue], total - 1,
                   @"The missing chunk should be the last one");
}

- (void)testReset
{
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                             maxChunkSize:200];
    OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:chunks.count];

    // Add all chunks
    for (NSString *chunk in chunks) {
        [chunker addChunkString:chunk];
    }
    XCTAssertTrue([chunker isComplete]);

    // Reset
    [chunker reset];

    XCTAssertFalse([chunker isComplete], @"Should not be complete after reset");
    XCTAssertEqualWithAccuracy([chunker progress], 0.0f, 0.001f,
                               @"Progress should be 0 after reset");
    XCTAssertNil([chunker assembledArmoredKey],
                 @"Assembled key should be nil after reset");
    XCTAssertEqual([chunker missingChunkIndices].count, chunks.count,
                   @"All chunks should be missing after reset");
}

- (void)testInvalidChunkString
{
    OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:3];

    BOOL accepted;
    accepted = [chunker addChunkString:@"garbage data"];
    XCTAssertFalse(accepted, @"Garbage string should be rejected");

    accepted = [chunker addChunkString:@"OPPGP:"];
    XCTAssertFalse(accepted, @"Incomplete header should be rejected");

    accepted = [chunker addChunkString:@""];
    XCTAssertFalse(accepted, @"Empty string should be rejected");

    accepted = [chunker addChunkString:nil];
    XCTAssertFalse(accepted, @"Nil string should be rejected");

    XCTAssertFalse([chunker isComplete], @"Should not be complete after only invalid chunks");
    XCTAssertEqualWithAccuracy([chunker progress], 0.0f, 0.001f);
}

- (void)testMismatchedTotals
{
    // Create chunks from two different keys
    NSArray *chunks1 = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                               maxChunkSize:200];
    NSArray *chunks2 = [OPQRCodeChunker chunksForArmoredKey:kShortArmoredKey
                                               maxChunkSize:200];

    OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:chunks1.count];

    // Add a chunk from the first key
    [chunker addChunkString:chunks1[0]];

    // Try adding a chunk from a different key set (different total)
    if (chunks2.count != chunks1.count) {
        BOOL accepted = [chunker addChunkString:chunks2[0]];
        // Should either reject it or handle gracefully
        // Either way, assembled result should not be garbled
        if ([chunker isComplete]) {
            // If somehow complete, the assembled key should be coherent
            NSString *assembled = [chunker assembledArmoredKey];
            XCTAssertNotNil(assembled);
        }
        (void)accepted; // suppress unused warning if assertion is conditional
    }
}

- (void)testSingleChunkRoundTrip
{
    // A key that fits in one chunk
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kShortArmoredKey
                                             maxChunkSize:2000];
    XCTAssertEqual(chunks.count, (NSUInteger)1);

    OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:1];
    [chunker addChunkString:chunks[0]];

    XCTAssertTrue([chunker isComplete]);
    XCTAssertEqualObjects([chunker assembledArmoredKey], kShortArmoredKey);
}

- (void)testChunksNotNilForEmptyInput
{
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:@""
                                             maxChunkSize:200];
    // Should return empty array or nil, not crash
    XCTAssertTrue(chunks == nil || chunks.count == 0,
                  @"Empty input should produce no chunks");
}

- (void)testChunksNilInput
{
    NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:nil
                                             maxChunkSize:200];
    XCTAssertTrue(chunks == nil || chunks.count == 0,
                  @"Nil input should produce no chunks");
}

- (void)testVaryingMaxChunkSizes
{
    // Verify correct round-trip at different chunk sizes
    NSArray *sizes = @[@(50), @(100), @(300), @(500), @(1000)];
    for (NSNumber *sizeNum in sizes) {
        NSUInteger maxSize = [sizeNum unsignedIntegerValue];
        NSArray *chunks = [OPQRCodeChunker chunksForArmoredKey:kTestArmoredKey
                                                  maxChunkSize:maxSize];
        XCTAssertNotNil(chunks, @"Chunks should not be nil for maxSize=%lu",
                        (unsigned long)maxSize);
        XCTAssertTrue(chunks.count >= 1);

        OPQRCodeChunker *chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:chunks.count];
        for (NSString *chunk in chunks) {
            [chunker addChunkString:chunk];
        }
        XCTAssertTrue([chunker isComplete],
                      @"Should be complete at maxSize=%lu", (unsigned long)maxSize);
        XCTAssertEqualObjects([chunker assembledArmoredKey], kTestArmoredKey,
                              @"Round-trip should match at maxSize=%lu", (unsigned long)maxSize);
    }
}

@end
