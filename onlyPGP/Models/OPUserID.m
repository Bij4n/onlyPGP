//
//  OPUserID.m
//  onlyPGP
//
//  Created 2014. OpenPGP User ID model.
//

#import "OPUserID.h"

@implementation OPUserID

- (instancetype)init
{
    self = [super init];
    if (self) {
        _isPrimary = NO;
    }
    return self;
}

- (instancetype)initWithUserIDString:(NSString *)userIDString
{
    self = [self init];
    if (self) {
        _userIDString = [userIDString copy];
        [self parseUserIDString:userIDString];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [self init];
    if (self) {
        _name = [dictionary[@"name"] copy];
        _email = [dictionary[@"email"] copy];
        _comment = [dictionary[@"comment"] copy];
        _userIDString = [dictionary[@"user_id_string"] copy];
        _isPrimary = [dictionary[@"is_primary"] boolValue];
        _parentKeyID = [dictionary[@"parent_key_id"] copy];

        id creationVal = dictionary[@"creation_date"];
        if (creationVal && creationVal != [NSNull null]) {
            _creationDate = [NSDate dateWithTimeIntervalSince1970:[creationVal doubleValue]];
        }
    }
    return self;
}

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    if (_name) dict[@"name"] = _name;
    if (_email) dict[@"email"] = _email;
    if (_comment) dict[@"comment"] = _comment;
    if (_userIDString) dict[@"user_id_string"] = _userIDString;
    if (_parentKeyID) dict[@"parent_key_id"] = _parentKeyID;
    dict[@"is_primary"] = @(_isPrimary);

    if (_creationDate) {
        dict[@"creation_date"] = @([_creationDate timeIntervalSince1970]);
    }

    return [NSDictionary dictionaryWithDictionary:dict];
}

#pragma mark - Parsing

- (void)parseUserIDString:(NSString *)uidString
{
    if (!uidString || [uidString length] == 0) {
        return;
    }

    NSString *trimmed = [uidString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // Try to extract email from angle brackets
    NSRange emailOpen = [trimmed rangeOfString:@"<" options:NSBackwardsSearch];
    NSRange emailClose = [trimmed rangeOfString:@">" options:NSBackwardsSearch];

    NSString *extractedEmail = nil;
    NSString *prefix = nil;

    if (emailOpen.location != NSNotFound && emailClose.location != NSNotFound
        && emailClose.location > emailOpen.location) {

        NSRange emailRange = NSMakeRange(emailOpen.location + 1,
                                         emailClose.location - emailOpen.location - 1);
        extractedEmail = [trimmed substringWithRange:emailRange];
        extractedEmail = [extractedEmail stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if (emailOpen.location > 0) {
            prefix = [[trimmed substringToIndex:emailOpen.location]
                       stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
    } else {
        // No angle brackets — could be just a name or just an email
        if ([trimmed rangeOfString:@"@"].location != NSNotFound) {
            extractedEmail = trimmed;
        } else {
            prefix = trimmed;
        }
    }

    _email = extractedEmail;

    // Try to extract comment from parentheses in the prefix
    if (prefix && [prefix length] > 0) {
        NSRange commentOpen = [prefix rangeOfString:@"("];
        NSRange commentClose = [prefix rangeOfString:@")" options:NSBackwardsSearch];

        if (commentOpen.location != NSNotFound && commentClose.location != NSNotFound
            && commentClose.location > commentOpen.location) {

            NSRange commentRange = NSMakeRange(commentOpen.location + 1,
                                               commentClose.location - commentOpen.location - 1);
            _comment = [[prefix substringWithRange:commentRange]
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

            NSString *beforeComment = [[prefix substringToIndex:commentOpen.location]
                                        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSString *afterComment = @"";
            if (commentClose.location + 1 < [prefix length]) {
                afterComment = [[prefix substringFromIndex:commentClose.location + 1]
                                 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }

            _name = beforeComment;
            if ([afterComment length] > 0) {
                _name = [_name stringByAppendingFormat:@" %@", afterComment];
            }
            _name = [_name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        } else {
            _name = prefix;
        }
    }

    // Rebuild the canonical userIDString if we didn't get one
    if (!_userIDString || [_userIDString length] == 0) {
        _userIDString = [self buildUserIDString];
    }
}

- (NSString *)buildUserIDString
{
    NSMutableString *result = [[NSMutableString alloc] init];

    if (_name && [_name length] > 0) {
        [result appendString:_name];
    }

    if (_comment && [_comment length] > 0) {
        if ([result length] > 0) [result appendString:@" "];
        [result appendFormat:@"(%@)", _comment];
    }

    if (_email && [_email length] > 0) {
        if ([result length] > 0) [result appendString:@" "];
        [result appendFormat:@"<%@>", _email];
    }

    return [NSString stringWithString:result];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<OPUserID: %@%@>",
            _userIDString ?: @"(empty)",
            _isPrimary ? @" [primary]" : @""];
}

@end
