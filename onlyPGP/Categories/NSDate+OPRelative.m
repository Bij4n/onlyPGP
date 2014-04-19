//
//  NSDate+OPRelative.m
//  onlyPGP
//
//  Created 2014. Relative date formatting.
//

#import "NSDate+OPRelative.h"

@implementation NSDate (OPRelative)

- (NSString *)op_relativeString
{
    NSTimeInterval interval = -[self timeIntervalSinceNow];

    // Future dates
    if (interval < 0) {
        NSTimeInterval futureInterval = -interval;
        if (futureInterval < 60) {
            return @"just now";
        } else if (futureInterval < 3600) {
            NSInteger minutes = (NSInteger)(futureInterval / 60.0);
            if (minutes == 1) return @"in 1 minute";
            return [NSString stringWithFormat:@"in %ld minutes", (long)minutes];
        } else if (futureInterval < 86400) {
            NSInteger hours = (NSInteger)(futureInterval / 3600.0);
            if (hours == 1) return @"in 1 hour";
            return [NSString stringWithFormat:@"in %ld hours", (long)hours];
        } else if (futureInterval < 86400 * 2) {
            return @"tomorrow";
        } else if (futureInterval < 86400 * 7) {
            NSInteger days = (NSInteger)(futureInterval / 86400.0);
            return [NSString stringWithFormat:@"in %ld days", (long)days];
        }
        return [self op_shortDateString];
    }

    // Past dates
    if (interval < 60) {
        return @"just now";
    } else if (interval < 3600) {
        NSInteger minutes = (NSInteger)(interval / 60.0);
        if (minutes == 1) return @"1 minute ago";
        return [NSString stringWithFormat:@"%ld minutes ago", (long)minutes];
    } else if (interval < 86400) {
        NSInteger hours = (NSInteger)(interval / 3600.0);
        if (hours == 1) return @"1 hour ago";
        return [NSString stringWithFormat:@"%ld hours ago", (long)hours];
    } else if (interval < 86400 * 2) {
        return @"yesterday";
    } else if (interval < 86400 * 7) {
        NSInteger days = (NSInteger)(interval / 86400.0);
        return [NSString stringWithFormat:@"%ld days ago", (long)days];
    } else if (interval < 86400 * 14) {
        return @"1 week ago";
    } else if (interval < 86400 * 30) {
        NSInteger weeks = (NSInteger)(interval / (86400.0 * 7));
        return [NSString stringWithFormat:@"%ld weeks ago", (long)weeks];
    }

    // Older than ~30 days — show the formatted date
    return [self op_shortDateString];
}

- (NSString *)op_shortDateString
{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MMM d, yyyy"];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    });

    return [formatter stringFromDate:self];
}

- (BOOL)op_isPast
{
    return [self compare:[NSDate date]] == NSOrderedAscending;
}

@end
// onlypgp-wip
