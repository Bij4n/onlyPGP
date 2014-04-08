//
//  OPUserID.h
//  onlyPGP
//
//  Created 2014. OpenPGP User ID model.
//

#import <Foundation/Foundation.h>

@interface OPUserID : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *comment;
@property (nonatomic, copy) NSString *userIDString;
@property (nonatomic, assign) BOOL isPrimary;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, copy) NSString *parentKeyID;

- (instancetype)initWithUserIDString:(NSString *)userIDString;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)toDictionary;

@end
