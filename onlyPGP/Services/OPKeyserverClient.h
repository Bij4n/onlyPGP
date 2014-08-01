//
//  OPKeyserverClient.h
//  onlyPGP
//
//  Created 2014. HKP keyserver client using AFNetworking 2.x.
//

#import <Foundation/Foundation.h>

@class AFHTTPRequestOperationManager;

typedef void(^OPKeyserverSearchCompletion)(NSArray *results, NSError *error);
typedef void(^OPKeyserverFetchCompletion)(NSString *armoredKey, NSError *error);

@interface OPKeyserverClient : NSObject

+ (OPKeyserverClient *)sharedClient;

@property (nonatomic, strong) NSString *keyserverURL;
@property (nonatomic, strong) AFHTTPRequestOperationManager *manager;

- (void)searchForQuery:(NSString *)query completion:(OPKeyserverSearchCompletion)completion;
- (void)fetchKeyWithID:(NSString *)keyID completion:(OPKeyserverFetchCompletion)completion;
- (void)uploadKey:(NSString *)armoredKey completion:(void(^)(BOOL success, NSError *error))completion;

@end
