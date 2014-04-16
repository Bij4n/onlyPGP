//
//  OPKeyStore+Migrations.h
//  onlyPGP
//
//  Created 2014. Database migration category.
//

#import "OPKeyStore.h"

@interface OPKeyStore (Migrations)

- (void)runMigrations;
- (void)migrateToVersion1;
- (void)migrateToVersion2;
- (void)migrateToVersion3;

@end
