//
//  OPKeyserverClient.m
//  onlyPGP
//
//  Created 2014. HKP keyserver client using AFNetworking 2.x.
//

#import "OPKeyserverClient.h"
#import <AFNetworking/AFNetworking.h>

static NSString * const kOPKeyserverClientErrorDomain = @"com.onlypgp.keyserverclient";
static NSString * const kOPKeyserverDefaultURL = @"http://pool.sks-keyservers.net";
static const NSTimeInterval kOPKeyserverTimeout = 15.0;

@interface OPKeyserverClient ()

@end

@implementation OPKeyserverClient

#pragma mark - Singleton

+ (OPKeyserverClient *)sharedClient
{
    static OPKeyserverClient *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OPKeyserverClient alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _keyserverURL = kOPKeyserverDefaultURL;
        [self setupManager];
    }
    return self;
}

- (void)setupManager
{
    _manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:_keyserverURL]];

    // HKP responses are plain text, not JSON
    _manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    _manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:
                                                          @"text/plain",
                                                          @"text/html",
                                                          @"application/pgp-keys",
                                                          @"application/x-pks-lookup",
                                                          nil];

    // Set reasonable timeout
    _manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    [_manager.requestSerializer setTimeoutInterval:kOPKeyserverTimeout];
}

- (void)setKeyserverURL:(NSString *)keyserverURL
{
    if (keyserverURL && [keyserverURL length] > 0) {
        // Strip trailing slash
        if ([keyserverURL hasSuffix:@"/"]) {
            keyserverURL = [keyserverURL substringToIndex:[keyserverURL length] - 1];
        }
        _keyserverURL = keyserverURL;
        [self setupManager];
    }
}

#pragma mark - Search

- (void)searchForQuery:(NSString *)query completion:(OPKeyserverSearchCompletion)completion
{
    if (!query || [query length] == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                 code:100
                                             userInfo:@{NSLocalizedDescriptionKey: @"Search query is empty."}];
            completion(nil, error);
        }
        return;
    }

    // HKP search: GET /pks/lookup?op=index&search={query}&options=mr
    NSString *urlString = [NSString stringWithFormat:@"%@/pks/lookup", _keyserverURL];

    NSDictionary *parameters = @{
        @"op": @"index",
        @"search": query,
        @"options": @"mr"
    };

    [_manager GET:urlString
       parameters:parameters
          success:^(AFHTTPRequestOperation *operation, id responseObject) {
              NSString *responseString = nil;
              if ([responseObject isKindOfClass:[NSData class]]) {
                  responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
              } else if ([responseObject isKindOfClass:[NSString class]]) {
                  responseString = responseObject;
              }

              if (!responseString || [responseString length] == 0) {
                  if (completion) {
                      completion(@[], nil);
                  }
                  return;
              }

              NSArray *results = [self parseHKPIndexResponse:responseString];

              if (completion) {
                  completion(results, nil);
              }
          }
          failure:^(AFHTTPRequestOperation *operation, NSError *error) {
              NSLog(@"OPKeyserverClient: Search failed: %@", error.localizedDescription);

              // Check for specific HTTP status codes
              NSInteger statusCode = operation.response.statusCode;
              NSError *keyserverError = nil;

              if (statusCode == 404) {
                  // No results found -- not an error, just empty
                  if (completion) {
                      completion(@[], nil);
                  }
                  return;
              } else if (statusCode == 429) {
                  keyserverError = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                       code:429
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Too many requests. Please try again later."}];
              } else if (statusCode >= 500) {
                  keyserverError = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                       code:statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Keyserver is temporarily unavailable. Please try again later.",
                                                              NSUnderlyingErrorKey: error}];
              } else {
                  keyserverError = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                       code:error.code
                                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Search failed: %@", error.localizedDescription],
                                                              NSUnderlyingErrorKey: error}];
              }

              if (completion) {
                  completion(nil, keyserverError);
              }
          }];
}

#pragma mark - Fetch

- (void)fetchKeyWithID:(NSString *)keyID completion:(OPKeyserverFetchCompletion)completion
{
    if (!keyID || [keyID length] == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                 code:200
                                             userInfo:@{NSLocalizedDescriptionKey: @"Key ID is empty."}];
            completion(nil, error);
        }
        return;
    }

    // Normalize the key ID -- ensure it has the 0x prefix for HKP
    NSString *normalizedKeyID = [keyID uppercaseString];
    normalizedKeyID = [normalizedKeyID stringByReplacingOccurrencesOfString:@"0X" withString:@""];
    NSString *searchKeyID = [NSString stringWithFormat:@"0x%@", normalizedKeyID];

    // HKP fetch: GET /pks/lookup?op=get&search=0x{keyID}&options=mr
    NSString *urlString = [NSString stringWithFormat:@"%@/pks/lookup", _keyserverURL];

    NSDictionary *parameters = @{
        @"op": @"get",
        @"search": searchKeyID,
        @"options": @"mr"
    };

    [_manager GET:urlString
       parameters:parameters
          success:^(AFHTTPRequestOperation *operation, id responseObject) {
              NSString *responseString = nil;
              if ([responseObject isKindOfClass:[NSData class]]) {
                  responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
              } else if ([responseObject isKindOfClass:[NSString class]]) {
                  responseString = responseObject;
              }

              if (!responseString || [responseString length] == 0) {
                  if (completion) {
                      NSError *error = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                           code:201
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Empty response from keyserver."}];
                      completion(nil, error);
                  }
                  return;
              }

              // Validate that the response contains a PGP public key block
              NSString *armoredKey = [self extractArmoredKeyFromResponse:responseString];

              if (!armoredKey) {
                  if (completion) {
                      NSError *error = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                           code:202
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Response does not contain a valid PGP key."}];
                      completion(nil, error);
                  }
                  return;
              }

              if (completion) {
                  completion(armoredKey, nil);
              }
          }
          failure:^(AFHTTPRequestOperation *operation, NSError *error) {
              NSLog(@"OPKeyserverClient: Fetch failed for key %@: %@", keyID, error.localizedDescription);

              NSInteger statusCode = operation.response.statusCode;
              NSError *keyserverError = nil;

              if (statusCode == 404) {
                  keyserverError = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                       code:404
                                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Key %@ not found on keyserver.", keyID]}];
              } else if (statusCode >= 500) {
                  keyserverError = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                       code:statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Keyserver is temporarily unavailable.",
                                                              NSUnderlyingErrorKey: error}];
              } else {
                  keyserverError = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                       code:error.code
                                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to fetch key: %@", error.localizedDescription],
                                                              NSUnderlyingErrorKey: error}];
              }

              if (completion) {
                  completion(nil, keyserverError);
              }
          }];
}

#pragma mark - Upload

- (void)uploadKey:(NSString *)armoredKey completion:(void(^)(BOOL success, NSError *error))completion
{
    if (!armoredKey || [armoredKey length] == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                 code:300
                                             userInfo:@{NSLocalizedDescriptionKey: @"Armored key is empty."}];
            completion(NO, error);
        }
        return;
    }

    // Validate it looks like a PGP key
    if ([armoredKey rangeOfString:@"-----BEGIN PGP PUBLIC KEY BLOCK-----"].location == NSNotFound) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                 code:301
                                             userInfo:@{NSLocalizedDescriptionKey: @"The provided text does not appear to be a valid PGP public key."}];
            completion(NO, error);
        }
        return;
    }

    // HKP upload: POST /pks/add with body keytext={url-encoded-armored-key}
    NSString *urlString = [NSString stringWithFormat:@"%@/pks/add", _keyserverURL];

    // The keytext parameter must be URL-form-encoded in the POST body
    NSDictionary *parameters = @{
        @"keytext": armoredKey
    };

    // Use a request serializer that encodes as form data
    _manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    [_manager.requestSerializer setTimeoutInterval:kOPKeyserverTimeout];
    [_manager.requestSerializer setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    [_manager POST:urlString
        parameters:parameters
           success:^(AFHTTPRequestOperation *operation, id responseObject) {
               NSLog(@"OPKeyserverClient: Key uploaded successfully.");

               if (completion) {
                   completion(YES, nil);
               }
           }
           failure:^(AFHTTPRequestOperation *operation, NSError *error) {
               NSLog(@"OPKeyserverClient: Upload failed: %@", error.localizedDescription);

               NSInteger statusCode = operation.response.statusCode;
               NSError *keyserverError = nil;

               if (statusCode >= 500) {
                   keyserverError = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                        code:statusCode
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Keyserver rejected the key upload. Please try again later.",
                                                               NSUnderlyingErrorKey: error}];
               } else if (statusCode == 400) {
                   keyserverError = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                        code:400
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Keyserver rejected the key. The key data may be malformed."}];
               } else {
                   keyserverError = [NSError errorWithDomain:kOPKeyserverClientErrorDomain
                                                        code:error.code
                                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Key upload failed: %@", error.localizedDescription],
                                                               NSUnderlyingErrorKey: error}];
               }

               if (completion) {
                   completion(NO, keyserverError);
               }
           }];
}

#pragma mark - HKP Response Parsing

- (NSArray *)parseHKPIndexResponse:(NSString *)response
{
    // HKP machine-readable format:
    // info:1:3
    // pub:KEYID:ALGO:KEYSIZE:CREATIONDATE:EXPIRATIONDATE:FLAGS
    // uid:UIDSTRING:CREATIONDATE:EXPIRATIONDATE:FLAGS
    //
    // Lines are separated by \n. Fields within a line are separated by :
    // Timestamps are Unix epoch seconds.
    // Algorithm numbers: 1=RSA, 17=DSA, etc.
    // Flags: r=revoked, d=disabled, e=expired

    NSMutableArray *results = [NSMutableArray array];

    NSArray *lines = [response componentsSeparatedByString:@"\n"];
    NSMutableDictionary *currentEntry = nil;
    NSMutableArray *currentUIDs = nil;

    for (NSString *rawLine in lines) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if ([line length] == 0) {
            continue;
        }

        NSArray *fields = [line componentsSeparatedByString:@":"];

        if ([fields count] == 0) {
            continue;
        }

        NSString *recordType = fields[0];

        if ([recordType isEqualToString:@"info"]) {
            // Info line: info:version:count
            // Just skip it
            continue;
        }

        if ([recordType isEqualToString:@"pub"]) {
            // Save previous entry if any
            if (currentEntry) {
                currentEntry[@"userIDs"] = [NSArray arrayWithArray:currentUIDs];
                [results addObject:[NSDictionary dictionaryWithDictionary:currentEntry]];
            }

            // Start a new entry
            currentEntry = [NSMutableDictionary dictionary];
            currentUIDs = [NSMutableArray array];

            // pub:KEYID:ALGO:KEYSIZE:CREATIONDATE:EXPIRATIONDATE:FLAGS
            if ([fields count] > 1 && [fields[1] length] > 0) {
                currentEntry[@"keyID"] = fields[1];
            }

            if ([fields count] > 2 && [fields[2] length] > 0) {
                NSInteger algoNumber = [fields[2] integerValue];
                currentEntry[@"algorithm"] = [self algorithmNameForNumber:algoNumber];
            } else {
                currentEntry[@"algorithm"] = @"Unknown";
            }

            if ([fields count] > 3 && [fields[3] length] > 0) {
                currentEntry[@"keySize"] = @([fields[3] integerValue]);
            }

            if ([fields count] > 4 && [fields[4] length] > 0) {
                NSTimeInterval timestamp = [fields[4] doubleValue];
                if (timestamp > 0) {
                    currentEntry[@"creationDate"] = [NSDate dateWithTimeIntervalSince1970:timestamp];
                }
            }

            if ([fields count] > 5 && [fields[5] length] > 0) {
                NSTimeInterval timestamp = [fields[5] doubleValue];
                if (timestamp > 0) {
                    currentEntry[@"expirationDate"] = [NSDate dateWithTimeIntervalSince1970:timestamp];
                }
            }

            if ([fields count] > 6 && [fields[6] length] > 0) {
                currentEntry[@"flags"] = fields[6];

                // Parse flag characters
                NSString *flags = fields[6];
                NSMutableArray *flagDescriptions = [NSMutableArray array];
                if ([flags rangeOfString:@"r"].location != NSNotFound) {
                    [flagDescriptions addObject:@"revoked"];
                }
                if ([flags rangeOfString:@"d"].location != NSNotFound) {
                    [flagDescriptions addObject:@"disabled"];
                }
                if ([flags rangeOfString:@"e"].location != NSNotFound) {
                    [flagDescriptions addObject:@"expired"];
                }
                if ([flagDescriptions count] > 0) {
                    currentEntry[@"flagDescriptions"] = flagDescriptions;
                }
            }

            continue;
        }

        if ([recordType isEqualToString:@"uid"]) {
            // uid:UIDSTRING:CREATIONDATE:EXPIRATIONDATE:FLAGS
            if (currentEntry && [fields count] > 1 && [fields[1] length] > 0) {
                // UID strings in HKP are URL-encoded
                NSString *uidString = [fields[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                if (uidString) {
                    [currentUIDs addObject:uidString];
                }
            }
            continue;
        }
    }

    // Don't forget the last entry
    if (currentEntry) {
        currentEntry[@"userIDs"] = [NSArray arrayWithArray:currentUIDs];
        [results addObject:[NSDictionary dictionaryWithDictionary:currentEntry]];
    }

    return [NSArray arrayWithArray:results];
}

- (NSString *)algorithmNameForNumber:(NSInteger)number
{
    switch (number) {
        case 1:  return @"RSA";
        case 2:  return @"RSA (Encrypt Only)";
        case 3:  return @"RSA (Sign Only)";
        case 16: return @"Elgamal";
        case 17: return @"DSA";
        case 18: return @"ECDH";
        case 19: return @"ECDSA";
        case 20: return @"Elgamal (Encrypt/Sign)";
        case 22: return @"EdDSA";
        default: return [NSString stringWithFormat:@"Algorithm %ld", (long)number];
    }
}

- (NSString *)extractArmoredKeyFromResponse:(NSString *)response
{
    // Find the PGP public key block within the response
    // The response may contain HTML wrapping around the key

    NSRange beginRange = [response rangeOfString:@"-----BEGIN PGP PUBLIC KEY BLOCK-----"];
    NSRange endRange = [response rangeOfString:@"-----END PGP PUBLIC KEY BLOCK-----"];

    if (beginRange.location == NSNotFound || endRange.location == NSNotFound) {
        return nil;
    }

    if (endRange.location < beginRange.location) {
        return nil;
    }

    NSUInteger start = beginRange.location;
    NSUInteger end = NSMaxRange(endRange);

    if (end > [response length]) {
        return nil;
    }

    NSString *armoredKey = [response substringWithRange:NSMakeRange(start, end - start)];

    // Basic validation: should contain base64 data between header and checksum
    if ([armoredKey length] < 100) {
        return nil;
    }

    return armoredKey;
}

@end
// onlypgp-wip
