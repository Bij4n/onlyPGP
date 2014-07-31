//
//  UIColor+OPTheme.m
//  onlyPGP
//
//  Created 2014. iOS 7 flat design theme colors.
//

#import "UIColor+OPTheme.h"

@implementation UIColor (OPTheme)

+ (UIColor *)op_tintColor
{
    // iOS 7-style blue tint: #007AFF
    return [UIColor colorWithRed:0.0f/255.0f green:122.0f/255.0f blue:255.0f/255.0f alpha:1.0f];
}

+ (UIColor *)op_greenColor
{
    // Verified/trusted green: #4CD964
    return [UIColor colorWithRed:76.0f/255.0f green:217.0f/255.0f blue:100.0f/255.0f alpha:1.0f];
}

+ (UIColor *)op_redColor
{
    // Expired/revoked red: #FF3B30
    return [UIColor colorWithRed:255.0f/255.0f green:59.0f/255.0f blue:48.0f/255.0f alpha:1.0f];
}

+ (UIColor *)op_orangeColor
{
    // Marginal trust orange: #FF9500
    return [UIColor colorWithRed:255.0f/255.0f green:149.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
}

+ (UIColor *)op_grayColor
{
    // Unknown trust gray: #8E8E93
    return [UIColor colorWithRed:142.0f/255.0f green:142.0f/255.0f blue:147.0f/255.0f alpha:1.0f];
}

+ (UIColor *)op_darkTextColor
{
    // Dark text: #1C1C1E
    return [UIColor colorWithRed:28.0f/255.0f green:28.0f/255.0f blue:30.0f/255.0f alpha:1.0f];
}

+ (UIColor *)op_lightBackgroundColor
{
    // Light grouped table background: #F2F2F7
    return [UIColor colorWithRed:242.0f/255.0f green:242.0f/255.0f blue:247.0f/255.0f alpha:1.0f];
}

+ (UIColor *)op_separatorColor
{
    // Table separator: #C6C6C8
    return [UIColor colorWithRed:198.0f/255.0f green:198.0f/255.0f blue:200.0f/255.0f alpha:1.0f];
}

@end
// onlypgp-wip
