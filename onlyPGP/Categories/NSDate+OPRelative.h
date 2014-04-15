//
//  NSDate+OPRelative.h
//  onlyPGP
//
//  Created 2014. Relative date formatting.
//

#import <Foundation/Foundation.h>

@interface NSDate (OPRelative)

- (NSString *)op_relativeString;
- (NSString *)op_shortDateString;
- (BOOL)op_isPast;

@end
