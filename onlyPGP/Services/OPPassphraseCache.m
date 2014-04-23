//
//  OPPassphraseCache.m
//  onlyPGP
//
//  Created 2014. Passphrase caching with keychain persistence and memory timeout.
//

#import "OPPassphraseCache.h"
#import <SSKeychain/SSKeychain.h>

static NSString * const kOPPassphraseCacheServiceName = @"com.onlypgp.passphrases";
static const NSTimeInterval kOPPassphraseCacheDefaultTimeout = 300.0; // 5 minutes
static const NSTimeInterval kOPPassphraseCacheCleanupInterval = 30.0; // Check every 30 seconds

// Keys for cache entry dictionary
static NSString * const kOPCacheEntryPassphrase = @"passphrase";
static NSString * const kOPCacheEntryTimestamp = @"timestamp";

@interface OPPassphraseCache ()

@property (nonatomic, strong) NSMutableDictionary *memoryCache;
@property (nonatomic, strong) NSTimer *cleanupTimer;
@property (nonatomic, strong) NSLock *cacheLock;

@end

@implementation OPPassphraseCache

#pragma mark - Singleton

+ (OPPassphraseCache *)sharedCache
{
    static OPPassphraseCache *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OPPassphraseCache alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cacheTimeout = kOPPassphraseCacheDefaultTimeout;
        _memoryCache = [NSMutableDictionary dictionary];
        _cacheLock = [[NSLock alloc] init];

        // Start the cleanup timer on the main run loop
        [self startCleanupTimer];

        // Clear memory cache when app enters background
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        // Clear memory cache on memory warning
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_cleanupTimer invalidate];
}

#pragma mark - Cleanup Timer

- (void)startCleanupTimer
{
    if (_cleanupTimer) {
        [_cleanupTimer invalidate];
    }

    _cleanupTimer = [NSTimer scheduledTimerWithTimeInterval:kOPPassphraseCacheCleanupInterval
                                                     target:self
                                                   selector:@selector(cleanupExpiredEntries:)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)cleanupExpiredEntries:(NSTimer *)timer
{
    [_cacheLock lock];

    NSDate *now = [NSDate date];
    NSMutableArray *expiredKeys = [NSMutableArray array];

    for (NSString *keyID in _memoryCache) {
        NSDictionary *entry = _memoryCache[keyID];
        NSDate *timestamp = entry[kOPCacheEntryTimestamp];

        if (timestamp) {
            NSTimeInterval age = [now timeIntervalSinceDate:timestamp];
            if (age > _cacheTimeout) {
                [expiredKeys addObject:keyID];
            }
        } else {
            // No timestamp -- consider it expired
            [expiredKeys addObject:keyID];
        }
    }

    for (NSString *keyID in expiredKeys) {
        // Overwrite the passphrase string in memory before removing
        NSMutableDictionary *entry = [_memoryCache[keyID] mutableCopy];
        if (entry) {
            entry[kOPCacheEntryPassphrase] = @"";
        }
        [_memoryCache removeObjectForKey:keyID];
    }

    [_cacheLock unlock];

    if ([expiredKeys count] > 0) {
        NSLog(@"OPPassphraseCache: Cleaned up %lu expired cache entries.", (unsigned long)[expiredKeys count]);
    }
}

#pragma mark - App Lifecycle

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    // Clear memory cache when app backgrounds for security
    [self clearCache];
    NSLog(@"OPPassphraseCache: Memory cache cleared on background.");
}

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    [self clearCache];
    NSLog(@"OPPassphraseCache: Memory cache cleared on memory warning.");
}

#pragma mark - Keychain (Persistent Storage)

- (BOOL)storePassphrase:(NSString *)passphrase forKeyID:(NSString *)keyID
{
    if (!passphrase || !keyID || [keyID length] == 0) {
        NSLog(@"OPPassphraseCache: Cannot store nil passphrase or empty keyID.");
        return NO;
    }

    // Normalize key ID
    NSString *normalizedKeyID = [self normalizeKeyID:keyID];

    NSError *error = nil;
    BOOL success = [SSKeychain setPassword:passphrase
                                forService:kOPPassphraseCacheServiceName
                                   account:normalizedKeyID
                                     error:&error];

    if (!success) {
        NSLog(@"OPPassphraseCache: Failed to store passphrase in keychain for key %@: %@",
              normalizedKeyID, error.localizedDescription);
    } else {
        NSLog(@"OPPassphraseCache: Stored passphrase in keychain for key %@.", normalizedKeyID);
    }

    return success;
}

- (NSString *)passphraseForKeyID:(NSString *)keyID
{
    if (!keyID || [keyID length] == 0) {
        return nil;
    }

    NSString *normalizedKeyID = [self normalizeKeyID:keyID];

    // First check the memory cache (faster and may be more recent)
    NSString *cachedPassphrase = [self cachedPassphraseForKeyID:normalizedKeyID];
    if (cachedPassphrase) {
        return cachedPassphrase;
    }

    // Fall back to keychain
    NSError *error = nil;
    NSString *passphrase = [SSKeychain passwordForService:kOPPassphraseCacheServiceName
                                                  account:normalizedKeyID
                                                    error:&error];

    if (error) {
        // errSecItemNotFound is expected when no passphrase stored; don't log it as error
        if (error.code != errSecItemNotFound) {
            NSLog(@"OPPassphraseCache: Keychain error retrieving passphrase for key %@: %@",
                  normalizedKeyID, error.localizedDescription);
        }
    }

    // If we got a passphrase from keychain, also cache it in memory for quick access
    if (passphrase && [passphrase length] > 0) {
        [self cachePassphrase:passphrase forKeyID:normalizedKeyID];
    }

    return passphrase;
}

- (BOOL)removePassphraseForKeyID:(NSString *)keyID
{
    if (!keyID || [keyID length] == 0) {
        return NO;
    }

    NSString *normalizedKeyID = [self normalizeKeyID:keyID];

    // Remove from memory cache
    [_cacheLock lock];
    [_memoryCache removeObjectForKey:normalizedKeyID];
    [_cacheLock unlock];

    // Remove from keychain
    NSError *error = nil;
    BOOL success = [SSKeychain deletePasswordForService:kOPPassphraseCacheServiceName
                                                account:normalizedKeyID
                                                  error:&error];

    if (!success && error && error.code != errSecItemNotFound) {
        NSLog(@"OPPassphraseCache: Failed to remove passphrase from keychain for key %@: %@",
              normalizedKeyID, error.localizedDescription);
    }

    return success;
}

- (BOOL)removeAllPassphrases
{
    // Clear memory cache first
    [self clearCache];

    // Get all accounts for our service and delete them
    NSArray *accounts = [SSKeychain accountsForService:kOPPassphraseCacheServiceName];
    BOOL allSuccess = YES;

    for (NSDictionary *accountDict in accounts) {
        NSString *account = accountDict[kSSKeychainAccountKey];
        if (account) {
            NSError *error = nil;
            BOOL success = [SSKeychain deletePasswordForService:kOPPassphraseCacheServiceName
                                                        account:account
                                                          error:&error];
            if (!success) {
                NSLog(@"OPPassphraseCache: Failed to delete keychain entry for account %@: %@",
                      account, error.localizedDescription);
                allSuccess = NO;
            }
        }
    }

    NSLog(@"OPPassphraseCache: Removed all passphrases from keychain. Accounts processed: %lu",
          (unsigned long)[accounts count]);

    return allSuccess;
}

#pragma mark - Memory Cache (Temporary)

- (void)cachePassphrase:(NSString *)passphrase forKeyID:(NSString *)keyID
{
    if (!passphrase || !keyID || [keyID length] == 0) {
        return;
    }

    NSString *normalizedKeyID = [self normalizeKeyID:keyID];

    [_cacheLock lock];

    NSDictionary *entry = @{
        kOPCacheEntryPassphrase: [passphrase copy],
        kOPCacheEntryTimestamp: [NSDate date]
    };

    _memoryCache[normalizedKeyID] = entry;

    [_cacheLock unlock];
}

- (NSString *)cachedPassphraseForKeyID:(NSString *)keyID
{
    if (!keyID || [keyID length] == 0) {
        return nil;
    }

    NSString *normalizedKeyID = [self normalizeKeyID:keyID];

    [_cacheLock lock];

    NSDictionary *entry = _memoryCache[normalizedKeyID];

    if (!entry) {
        [_cacheLock unlock];
        return nil;
    }

    // Check if the entry has expired
    NSDate *timestamp = entry[kOPCacheEntryTimestamp];
    if (!timestamp) {
        // No timestamp -- remove the invalid entry
        [_memoryCache removeObjectForKey:normalizedKeyID];
        [_cacheLock unlock];
        return nil;
    }

    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:timestamp];
    if (age > _cacheTimeout) {
        // Entry has expired -- remove it
        [_memoryCache removeObjectForKey:normalizedKeyID];
        [_cacheLock unlock];
        NSLog(@"OPPassphraseCache: Cached passphrase expired for key %@ (age: %.0fs, timeout: %.0fs)",
              normalizedKeyID, age, _cacheTimeout);
        return nil;
    }

    NSString *passphrase = entry[kOPCacheEntryPassphrase];

    [_cacheLock unlock];

    return passphrase;
}

- (void)clearCache
{
    [_cacheLock lock];

    // Overwrite all cached passphrases before removing
    for (NSString *keyID in [_memoryCache allKeys]) {
        NSMutableDictionary *entry = [_memoryCache[keyID] mutableCopy];
        if (entry) {
            entry[kOPCacheEntryPassphrase] = @"";
        }
    }

    [_memoryCache removeAllObjects];

    [_cacheLock unlock];

    NSLog(@"OPPassphraseCache: Memory cache cleared.");
}

#pragma mark - Private Helpers

- (NSString *)normalizeKeyID:(NSString *)keyID
{
    // Normalize key ID: uppercase, strip 0x prefix
    NSString *normalized = [keyID uppercaseString];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"0X" withString:@""];
    return normalized;
}

@end
