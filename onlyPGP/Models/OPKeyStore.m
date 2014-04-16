//
//  OPKeyStore.m
//  onlyPGP
//
//  Created 2014. FMDB-backed SQLite key storage singleton.
//

#import "OPKeyStore.h"
#import "OPKeyStore+Migrations.h"
#import "OPKey.h"
#import "OPSubkey.h"
#import "OPUserID.h"
#import "OPSignature.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMResultSet.h"

static OPKeyStore *_sharedStore = nil;

@interface OPKeyStore ()

@property (nonatomic, strong, readwrite) FMDatabase *database;
@property (nonatomic, copy, readwrite) NSString *databasePath;

@end

@implementation OPKeyStore

#pragma mark - Singleton

+ (OPKeyStore *)sharedStore
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedStore = [[OPKeyStore alloc] init];
    });
    return _sharedStore;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDir = [paths firstObject];
        _databasePath = [documentsDir stringByAppendingPathComponent:@"onlyPGP.sqlite"];
        [self setupDatabase];
    }
    return self;
}

#pragma mark - Setup

- (void)setupDatabase
{
    _database = [FMDatabase databaseWithPath:_databasePath];
    _databaseQueue = [FMDatabaseQueue databaseQueueWithPath:_databasePath];

    if (![_database open]) {
        NSLog(@"OPKeyStore: Failed to open database at %@", _databasePath);
        return;
    }

    [_database executeUpdate:@"PRAGMA foreign_keys = ON"];
    [_database executeUpdate:@"PRAGMA journal_mode = WAL"];

    [self runMigrations];
}

#pragma mark - Insert

- (void)insertKey:(OPKey *)key
{
    if (!key.keyID) {
        NSLog(@"OPKeyStore: Cannot insert key without keyID");
        return;
    }

    [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {

        BOOL success = [db executeUpdate:
            @"INSERT OR REPLACE INTO keys "
             "(key_id, fingerprint, algorithm, key_size, creation_date, expiration_date, "
             "is_secret_key, armored_public_key, armored_secret_key, owner_trust, is_revoked) "
             "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            key.keyID,
            key.fingerprint,
            @(key.algorithm),
            @(key.keySize),
            key.creationDate ? @([key.creationDate timeIntervalSince1970]) : [NSNull null],
            key.expirationDate ? @([key.expirationDate timeIntervalSince1970]) : [NSNull null],
            @(key.isSecretKey),
            key.armoredPublicKey ?: [NSNull null],
            key.armoredSecretKey ?: [NSNull null],
            @(key.ownerTrust),
            @(key.isRevoked)];

        if (!success) {
            NSLog(@"OPKeyStore: Failed to insert key %@: %@", key.keyID, [db lastErrorMessage]);
            *rollback = YES;
            return;
        }

        // Delete existing related records before re-inserting
        [db executeUpdate:@"DELETE FROM user_ids WHERE parent_key_id = ?", key.keyID];
        [db executeUpdate:@"DELETE FROM subkeys WHERE parent_key_id = ?", key.keyID];
        [db executeUpdate:@"DELETE FROM signatures WHERE parent_key_id = ?", key.keyID];

        // Insert user IDs
        for (OPUserID *uid in key.userIDs) {
            [db executeUpdate:
                @"INSERT INTO user_ids "
                 "(parent_key_id, name, email, comment, user_id_string, is_primary, creation_date) "
                 "VALUES (?, ?, ?, ?, ?, ?, ?)",
                key.keyID,
                uid.name ?: [NSNull null],
                uid.email ?: [NSNull null],
                uid.comment ?: [NSNull null],
                uid.userIDString ?: [NSNull null],
                @(uid.isPrimary),
                uid.creationDate ? @([uid.creationDate timeIntervalSince1970]) : [NSNull null]];
        }

        // Insert subkeys
        for (OPSubkey *subkey in key.subkeys) {
            [db executeUpdate:
                @"INSERT INTO subkeys "
                 "(key_id, parent_key_id, fingerprint, algorithm, key_size, "
                 "creation_date, expiration_date, can_sign, can_encrypt, is_revoked) "
                 "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                subkey.keyID ?: [NSNull null],
                key.keyID,
                subkey.fingerprint ?: [NSNull null],
                @(subkey.algorithm),
                @(subkey.keySize),
                subkey.creationDate ? @([subkey.creationDate timeIntervalSince1970]) : [NSNull null],
                subkey.expirationDate ? @([subkey.expirationDate timeIntervalSince1970]) : [NSNull null],
                @(subkey.canSign),
                @(subkey.canEncrypt),
                @(subkey.isRevoked)];
        }

        // Insert signatures
        for (OPSignature *sig in key.signatures) {
            [db executeUpdate:
                @"INSERT INTO signatures "
                 "(key_id, signer_key_id, parent_key_id, creation_date, "
                 "expiration_date, signature_type, is_revocation) "
                 "VALUES (?, ?, ?, ?, ?, ?, ?)",
                sig.keyID ?: [NSNull null],
                sig.signerKeyID ?: [NSNull null],
                key.keyID,
                sig.creationDate ? @([sig.creationDate timeIntervalSince1970]) : [NSNull null],
                sig.expirationDate ? @([sig.expirationDate timeIntervalSince1970]) : [NSNull null],
                @(sig.signatureType),
                @(sig.isRevocation)];
        }
    }];
}

#pragma mark - Update

- (void)updateKey:(OPKey *)key
{
    // Re-insert handles INSERT OR REPLACE plus child records
    [self insertKey:key];
}

#pragma mark - Delete

- (void)deleteKeyWithKeyID:(NSString *)keyID
{
    if (!keyID) return;

    [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@"DELETE FROM signatures WHERE parent_key_id = ?", keyID];
        [db executeUpdate:@"DELETE FROM subkeys WHERE parent_key_id = ?", keyID];
        [db executeUpdate:@"DELETE FROM user_ids WHERE parent_key_id = ?", keyID];
        [db executeUpdate:@"DELETE FROM keys WHERE key_id = ?", keyID];
    }];
}

#pragma mark - Fetch Single Key

- (OPKey *)keyWithKeyID:(NSString *)keyID
{
    if (!keyID) return nil;

    __block OPKey *key = nil;

    [_databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT * FROM keys WHERE key_id = ?", keyID];
        if ([rs next]) {
            key = [self keyFromResultSet:rs];
        }
        [rs close];

        if (key) {
            [self loadChildrenForKey:key inDatabase:db];
        }
    }];

    return key;
}

- (OPKey *)keyWithFingerprint:(NSString *)fingerprint
{
    if (!fingerprint) return nil;

    __block OPKey *key = nil;

    [_databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:
            @"SELECT * FROM keys WHERE fingerprint = ? COLLATE NOCASE", fingerprint];
        if ([rs next]) {
            key = [self keyFromResultSet:rs];
        }
        [rs close];

        if (key) {
            [self loadChildrenForKey:key inDatabase:db];
        }
    }];

    return key;
}

#pragma mark - Fetch Multiple Keys

- (NSArray *)allKeys
{
    __block NSMutableArray *keys = [[NSMutableArray alloc] init];

    [_databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT * FROM keys ORDER BY key_id"];
        while ([rs next]) {
            OPKey *key = [self keyFromResultSet:rs];
            [self loadChildrenForKey:key inDatabase:db];
            [keys addObject:key];
        }
        [rs close];
    }];

    return [NSArray arrayWithArray:keys];
}

- (NSArray *)allPublicKeys
{
    __block NSMutableArray *keys = [[NSMutableArray alloc] init];

    [_databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:
            @"SELECT * FROM keys WHERE is_secret_key = 0 ORDER BY key_id"];
        while ([rs next]) {
            OPKey *key = [self keyFromResultSet:rs];
            [self loadChildrenForKey:key inDatabase:db];
            [keys addObject:key];
        }
        [rs close];
    }];

    return [NSArray arrayWithArray:keys];
}

- (NSArray *)allSecretKeys
{
    __block NSMutableArray *keys = [[NSMutableArray alloc] init];

    [_databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:
            @"SELECT * FROM keys WHERE is_secret_key = 1 ORDER BY key_id"];
        while ([rs next]) {
            OPKey *key = [self keyFromResultSet:rs];
            [self loadChildrenForKey:key inDatabase:db];
            [keys addObject:key];
        }
        [rs close];
    }];

    return [NSArray arrayWithArray:keys];
}

- (NSArray *)searchKeysWithQuery:(NSString *)query
{
    if (!query || [query length] == 0) {
        return [self allKeys];
    }

    __block NSMutableArray *keys = [[NSMutableArray alloc] init];
    NSString *likeQuery = [NSString stringWithFormat:@"%%%@%%", query];

    [_databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:
            @"SELECT DISTINCT k.* FROM keys k "
             "LEFT JOIN user_ids u ON k.key_id = u.parent_key_id "
             "WHERE k.key_id LIKE ? "
             "OR k.fingerprint LIKE ? "
             "OR u.name LIKE ? "
             "OR u.email LIKE ? "
             "ORDER BY k.key_id",
            likeQuery, likeQuery, likeQuery, likeQuery];

        while ([rs next]) {
            OPKey *key = [self keyFromResultSet:rs];
            [self loadChildrenForKey:key inDatabase:db];
            [keys addObject:key];
        }
        [rs close];
    }];

    return [NSArray arrayWithArray:keys];
}

#pragma mark - Count & Delete All

- (NSInteger)keyCount
{
    __block NSInteger count = 0;

    [_databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) FROM keys"];
        if ([rs next]) {
            count = [rs intForColumnIndex:0];
        }
        [rs close];
    }];

    return count;
}

- (void)deleteAllKeys
{
    [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@"DELETE FROM signatures"];
        [db executeUpdate:@"DELETE FROM subkeys"];
        [db executeUpdate:@"DELETE FROM user_ids"];
        [db executeUpdate:@"DELETE FROM keys"];
    }];
}

#pragma mark - Close

- (void)close
{
    [_databaseQueue close];
    [_database close];
}

#pragma mark - Private Helpers

- (OPKey *)keyFromResultSet:(FMResultSet *)rs
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    NSString *keyID = [rs stringForColumn:@"key_id"];
    if (keyID) dict[@"key_id"] = keyID;

    NSString *fingerprint = [rs stringForColumn:@"fingerprint"];
    if (fingerprint) dict[@"fingerprint"] = fingerprint;

    dict[@"algorithm"] = @([rs intForColumn:@"algorithm"]);
    dict[@"key_size"] = @([rs intForColumn:@"key_size"]);
    dict[@"is_secret_key"] = @([rs boolForColumn:@"is_secret_key"]);
    dict[@"owner_trust"] = @([rs intForColumn:@"owner_trust"]);
    dict[@"is_revoked"] = @([rs boolForColumn:@"is_revoked"]);

    if (![rs columnIsNull:@"creation_date"]) {
        dict[@"creation_date"] = @([rs doubleForColumn:@"creation_date"]);
    }
    if (![rs columnIsNull:@"expiration_date"]) {
        dict[@"expiration_date"] = @([rs doubleForColumn:@"expiration_date"]);
    }

    NSString *armoredPub = [rs stringForColumn:@"armored_public_key"];
    if (armoredPub) dict[@"armored_public_key"] = armoredPub;

    NSString *armoredSec = [rs stringForColumn:@"armored_secret_key"];
    if (armoredSec) dict[@"armored_secret_key"] = armoredSec;

    return [[OPKey alloc] initWithDictionary:dict];
}

- (void)loadChildrenForKey:(OPKey *)key inDatabase:(FMDatabase *)db
{
    // Load user IDs
    FMResultSet *uidRS = [db executeQuery:
        @"SELECT * FROM user_ids WHERE parent_key_id = ? ORDER BY is_primary DESC",
        key.keyID];
    while ([uidRS next]) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"parent_key_id"] = key.keyID;

        NSString *name = [uidRS stringForColumn:@"name"];
        if (name) dict[@"name"] = name;

        NSString *email = [uidRS stringForColumn:@"email"];
        if (email) dict[@"email"] = email;

        NSString *comment = [uidRS stringForColumn:@"comment"];
        if (comment) dict[@"comment"] = comment;

        NSString *uidString = [uidRS stringForColumn:@"user_id_string"];
        if (uidString) dict[@"user_id_string"] = uidString;

        dict[@"is_primary"] = @([uidRS boolForColumn:@"is_primary"]);

        if (![uidRS columnIsNull:@"creation_date"]) {
            dict[@"creation_date"] = @([uidRS doubleForColumn:@"creation_date"]);
        }

        OPUserID *uid = [[OPUserID alloc] initWithDictionary:dict];
        [key.userIDs addObject:uid];
    }
    [uidRS close];

    // Load subkeys
    FMResultSet *subRS = [db executeQuery:
        @"SELECT * FROM subkeys WHERE parent_key_id = ?", key.keyID];
    while ([subRS next]) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"parent_key_id"] = key.keyID;

        NSString *skID = [subRS stringForColumn:@"key_id"];
        if (skID) dict[@"key_id"] = skID;

        NSString *fp = [subRS stringForColumn:@"fingerprint"];
        if (fp) dict[@"fingerprint"] = fp;

        dict[@"algorithm"] = @([subRS intForColumn:@"algorithm"]);
        dict[@"key_size"] = @([subRS intForColumn:@"key_size"]);
        dict[@"can_sign"] = @([subRS boolForColumn:@"can_sign"]);
        dict[@"can_encrypt"] = @([subRS boolForColumn:@"can_encrypt"]);
        dict[@"is_revoked"] = @([subRS boolForColumn:@"is_revoked"]);

        if (![subRS columnIsNull:@"creation_date"]) {
            dict[@"creation_date"] = @([subRS doubleForColumn:@"creation_date"]);
        }
        if (![subRS columnIsNull:@"expiration_date"]) {
            dict[@"expiration_date"] = @([subRS doubleForColumn:@"expiration_date"]);
        }

        OPSubkey *subkey = [[OPSubkey alloc] initWithDictionary:dict];
        [key.subkeys addObject:subkey];
    }
    [subRS close];

    // Load signatures
    FMResultSet *sigRS = [db executeQuery:
        @"SELECT * FROM signatures WHERE parent_key_id = ?", key.keyID];
    while ([sigRS next]) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"parent_key_id"] = key.keyID;

        NSString *skID = [sigRS stringForColumn:@"key_id"];
        if (skID) dict[@"key_id"] = skID;

        NSString *signerID = [sigRS stringForColumn:@"signer_key_id"];
        if (signerID) dict[@"signer_key_id"] = signerID;

        dict[@"signature_type"] = @([sigRS intForColumn:@"signature_type"]);
        dict[@"is_revocation"] = @([sigRS boolForColumn:@"is_revocation"]);

        if (![sigRS columnIsNull:@"creation_date"]) {
            dict[@"creation_date"] = @([sigRS doubleForColumn:@"creation_date"]);
        }
        if (![sigRS columnIsNull:@"expiration_date"]) {
            dict[@"expiration_date"] = @([sigRS doubleForColumn:@"expiration_date"]);
        }

        OPSignature *sig = [[OPSignature alloc] initWithDictionary:dict];
        [key.signatures addObject:sig];
    }
    [sigRS close];
}

@end
