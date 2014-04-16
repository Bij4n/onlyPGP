//
//  OPKeyStore.h
//  onlyPGP
//
//  Created 2014. FMDB-backed SQLite key storage singleton.
//

#import <Foundation/Foundation.h>

@class OPKey;
@class FMDatabase;
@class FMDatabaseQueue;

@interface OPKeyStore : NSObject

@property (nonatomic, strong, readonly) FMDatabase *database;
@property (nonatomic, copy, readonly) NSString *databasePath;
@property (nonatomic, strong) FMDatabaseQueue *databaseQueue;

+ (OPKeyStore *)sharedStore;

- (void)setupDatabase;

- (void)insertKey:(OPKey *)key;
- (void)updateKey:(OPKey *)key;
- (void)deleteKeyWithKeyID:(NSString *)keyID;

- (OPKey *)keyWithKeyID:(NSString *)keyID;
- (OPKey *)keyWithFingerprint:(NSString *)fingerprint;

- (NSArray *)allKeys;
- (NSArray *)allPublicKeys;
- (NSArray *)allSecretKeys;
- (NSArray *)searchKeysWithQuery:(NSString *)query;

- (NSInteger)keyCount;
- (void)deleteAllKeys;
- (void)close;

@end
// onlypgp-wip
