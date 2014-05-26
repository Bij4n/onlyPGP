//
//  OPQRCodeChunker.h
//  onlyPGP
//
//  Created 2014. Splits armored PGP keys into QR code chunks and reassembles.
//

#import <Foundation/Foundation.h>

@interface OPQRCodeChunker : NSObject

// Chunking for display
+ (NSArray *)chunksForArmoredKey:(NSString *)armoredKey maxChunkSize:(NSUInteger)maxSize;
+ (NSUInteger)chunkCountForArmoredKey:(NSString *)armoredKey maxChunkSize:(NSUInteger)maxSize;

// Reassembly from scanned chunks
- (instancetype)initWithExpectedChunkCount:(NSUInteger)count;
- (BOOL)addChunkString:(NSString *)chunkString;
- (BOOL)isComplete;
- (float)progress;
- (NSString *)assembledArmoredKey;
- (NSArray *)missingChunkIndices;
- (void)reset;

@end
// onlypgp-wip
