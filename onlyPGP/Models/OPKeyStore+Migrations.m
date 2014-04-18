//
//  OPKeyStore+Migrations.m
//  onlyPGP
//
//  Created 2014. Database migration category.
//

#import "OPKeyStore+Migrations.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"

static const NSInteger kCurrentSchemaVersion = 3;

@implementation OPKeyStore (Migrations)

- (void)runMigrations
{
    [self.databaseQueue inDatabase:^(FMDatabase *db) {

        // Create schema_version table if it doesn't exist
        [db executeUpdate:
            @"CREATE TABLE IF NOT EXISTS schema_version (version INTEGER)"];

        FMResultSet *rs = [db executeQuery:@"SELECT version FROM schema_version LIMIT 1"];
        NSInteger currentVersion = 0;
        if ([rs next]) {
            currentVersion = [rs intForColumnIndex:0];
        }
        [rs close];

        if (currentVersion == 0) {
            // No version row yet — insert one
            FMResultSet *countRS = [db executeQuery:@"SELECT COUNT(*) FROM schema_version"];
            NSInteger rowCount = 0;
            if ([countRS next]) {
                rowCount = [countRS intForColumnIndex:0];
            }
            [countRS close];

            if (rowCount == 0) {
                [db executeUpdate:@"INSERT INTO schema_version (version) VALUES (0)"];
            }
        }

        NSLog(@"OPKeyStore: Current schema version: %ld, target: %ld",
              (long)currentVersion, (long)kCurrentSchemaVersion);

        if (currentVersion < 1) {
            [self performMigrationToVersion1InDatabase:db];
        }
        if (currentVersion < 2) {
            [self performMigrationToVersion2InDatabase:db];
        }
        if (currentVersion < 3) {
            [self performMigrationToVersion3InDatabase:db];
        }
    }];
}

#pragma mark - Public Migration Methods (dispatch to queue)

- (void)migrateToVersion1
{
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        [self performMigrationToVersion1InDatabase:db];
    }];
}

- (void)migrateToVersion2
{
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        [self performMigrationToVersion2InDatabase:db];
    }];
}

- (void)migrateToVersion3
{
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        [self performMigrationToVersion3InDatabase:db];
    }];
}

#pragma mark - Private Migration Implementations

- (void)performMigrationToVersion1InDatabase:(FMDatabase *)db
{
    NSLog(@"OPKeyStore: Migrating to version 1 — creating initial schema");

    // Keys table
    BOOL success = [db executeUpdate:
        @"CREATE TABLE IF NOT EXISTS keys ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT, "
         "key_id TEXT UNIQUE, "
         "fingerprint TEXT, "
         "algorithm INTEGER, "
         "key_size INTEGER, "
         "creation_date REAL, "
         "expiration_date REAL, "
         "is_secret_key INTEGER DEFAULT 0, "
         "armored_public_key TEXT, "
         "armored_secret_key TEXT"
         ")"];

    if (!success) {
        NSLog(@"OPKeyStore: Failed to create keys table: %@", [db lastErrorMessage]);
        return;
    }

    // User IDs table
    [db executeUpdate:
        @"CREATE TABLE IF NOT EXISTS user_ids ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT, "
         "parent_key_id TEXT, "
         "name TEXT, "
         "email TEXT, "
         "comment TEXT, "
         "user_id_string TEXT, "
         "is_primary INTEGER DEFAULT 0, "
         "creation_date REAL, "
         "FOREIGN KEY(parent_key_id) REFERENCES keys(key_id)"
         ")"];

    // Subkeys table
    [db executeUpdate:
        @"CREATE TABLE IF NOT EXISTS subkeys ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT, "
         "key_id TEXT, "
         "parent_key_id TEXT, "
         "fingerprint TEXT, "
         "algorithm INTEGER, "
         "key_size INTEGER, "
         "creation_date REAL, "
         "expiration_date REAL, "
         "can_sign INTEGER DEFAULT 0, "
         "can_encrypt INTEGER DEFAULT 0, "
         "FOREIGN KEY(parent_key_id) REFERENCES keys(key_id)"
         ")"];

    // Signatures table
    [db executeUpdate:
        @"CREATE TABLE IF NOT EXISTS signatures ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT, "
         "key_id TEXT, "
         "signer_key_id TEXT, "
         "parent_key_id TEXT, "
         "creation_date REAL, "
         "expiration_date REAL, "
         "signature_type INTEGER, "
         "FOREIGN KEY(parent_key_id) REFERENCES keys(key_id)"
         ")"];

    // Indexes
    [db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_keys_fingerprint ON keys(fingerprint)"];
    [db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_user_ids_parent ON user_ids(parent_key_id)"];
    [db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_user_ids_email ON user_ids(email)"];
    [db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_subkeys_parent ON subkeys(parent_key_id)"];
    [db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_signatures_parent ON signatures(parent_key_id)"];
    [db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_signatures_signer ON signatures(signer_key_id)"];

    [db executeUpdate:@"UPDATE schema_version SET version = 1"];
    NSLog(@"OPKeyStore: Migration to version 1 complete");
}

- (void)performMigrationToVersion2InDatabase:(FMDatabase *)db
{
    NSLog(@"OPKeyStore: Migrating to version 2 — adding owner_trust column");

    // Check if column already exists to be safe
    BOOL hasOwnerTrust = NO;
    FMResultSet *pragma = [db executeQuery:@"PRAGMA table_info(keys)"];
    while ([pragma next]) {
        NSString *colName = [pragma stringForColumn:@"name"];
        if ([colName isEqualToString:@"owner_trust"]) {
            hasOwnerTrust = YES;
            break;
        }
    }
    [pragma close];

    if (!hasOwnerTrust) {
        [db executeUpdate:@"ALTER TABLE keys ADD COLUMN owner_trust INTEGER DEFAULT 0"];
    }

    [db executeUpdate:@"UPDATE schema_version SET version = 2"];
    NSLog(@"OPKeyStore: Migration to version 2 complete");
}

- (void)performMigrationToVersion3InDatabase:(FMDatabase *)db
{
    NSLog(@"OPKeyStore: Migrating to version 3 — adding is_revoked columns");

    // Check keys table for is_revoked
    BOOL keysHasRevoked = NO;
    FMResultSet *keysPragma = [db executeQuery:@"PRAGMA table_info(keys)"];
    while ([keysPragma next]) {
        NSString *colName = [keysPragma stringForColumn:@"name"];
        if ([colName isEqualToString:@"is_revoked"]) {
            keysHasRevoked = YES;
            break;
        }
    }
    [keysPragma close];

    if (!keysHasRevoked) {
        [db executeUpdate:@"ALTER TABLE keys ADD COLUMN is_revoked INTEGER DEFAULT 0"];
    }

    // Check subkeys table for is_revoked
    BOOL subkeysHasRevoked = NO;
    FMResultSet *subkeysPragma = [db executeQuery:@"PRAGMA table_info(subkeys)"];
    while ([subkeysPragma next]) {
        NSString *colName = [subkeysPragma stringForColumn:@"name"];
        if ([colName isEqualToString:@"is_revoked"]) {
            subkeysHasRevoked = YES;
            break;
        }
    }
    [subkeysPragma close];

    if (!subkeysHasRevoked) {
        [db executeUpdate:@"ALTER TABLE subkeys ADD COLUMN is_revoked INTEGER DEFAULT 0"];
    }

    // Check signatures table for is_revocation
    BOOL sigsHasRevocation = NO;
    FMResultSet *sigsPragma = [db executeQuery:@"PRAGMA table_info(signatures)"];
    while ([sigsPragma next]) {
        NSString *colName = [sigsPragma stringForColumn:@"name"];
        if ([colName isEqualToString:@"is_revocation"]) {
            sigsHasRevocation = YES;
            break;
        }
    }
    [sigsPragma close];

    if (!sigsHasRevocation) {
        [db executeUpdate:@"ALTER TABLE signatures ADD COLUMN is_revocation INTEGER DEFAULT 0"];
    }

    [db executeUpdate:@"UPDATE schema_version SET version = 3"];
    NSLog(@"OPKeyStore: Migration to version 3 complete");
}

@end
