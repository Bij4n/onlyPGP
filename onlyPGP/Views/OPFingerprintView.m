//
//  OPFingerprintView.m
//  onlyPGP
//
//  Created 2014. ARC enabled.
//

#import "OPFingerprintView.h"
#import "UIColor+OPTheme.h"

static const CGFloat kOPFingerprintFontSize   = 13.0f;
static const CGFloat kOPFingerprintPadding     = 10.0f;
static const CGFloat kOPFingerprintLineSpacing = 4.0f;
static const CGFloat kOPFingerprintCornerRadius = 6.0f;

@interface OPFingerprintView ()

@property (nonatomic, strong) UIView  *backgroundContainer;
@property (nonatomic, strong) UILabel *topLineLabel;
@property (nonatomic, strong) UILabel *bottomLineLabel;

@end

@implementation OPFingerprintView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews
{
    /* Background rounded rect */
    self.backgroundContainer = [[UIView alloc] initWithFrame:self.bounds];
    self.backgroundContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundContainer.backgroundColor = [UIColor colorWithWhite:0.94f alpha:1.0f];
    self.backgroundContainer.layer.cornerRadius = kOPFingerprintCornerRadius;
    self.backgroundContainer.clipsToBounds = YES;
    [self addSubview:self.backgroundContainer];

    UIFont *monoFont = [UIFont fontWithName:@"Courier" size:kOPFingerprintFontSize];
    if (!monoFont) {
        monoFont = [UIFont systemFontOfSize:kOPFingerprintFontSize];
    }

    /* Top line label */
    self.topLineLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.topLineLabel.font = monoFont;
    self.topLineLabel.textColor = [UIColor op_darkTextColor];
    self.topLineLabel.textAlignment = NSTextAlignmentCenter;
    self.topLineLabel.backgroundColor = [UIColor clearColor];
    [self.backgroundContainer addSubview:self.topLineLabel];

    /* Bottom line label */
    self.bottomLineLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bottomLineLabel.font = monoFont;
    self.bottomLineLabel.textColor = [UIColor op_darkTextColor];
    self.bottomLineLabel.textAlignment = NSTextAlignmentCenter;
    self.bottomLineLabel.backgroundColor = [UIColor clearColor];
    [self.backgroundContainer addSubview:self.bottomLineLabel];

    /* Tap to copy */
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self addGestureRecognizer:tap];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.backgroundContainer.frame = self.bounds;

    CGFloat lineHeight = kOPFingerprintFontSize + 2.0f;
    CGFloat totalHeight = lineHeight * 2.0f + kOPFingerprintLineSpacing;
    CGFloat topY = (CGRectGetHeight(self.bounds) - totalHeight) / 2.0f;

    self.topLineLabel.frame = CGRectMake(kOPFingerprintPadding, topY,
                                         CGRectGetWidth(self.bounds) - kOPFingerprintPadding * 2.0f,
                                         lineHeight);

    self.bottomLineLabel.frame = CGRectMake(kOPFingerprintPadding, topY + lineHeight + kOPFingerprintLineSpacing,
                                            CGRectGetWidth(self.bounds) - kOPFingerprintPadding * 2.0f,
                                            lineHeight);
}

#pragma mark - Property

- (void)setFingerprint:(NSString *)fingerprint
{
    _fingerprint = [fingerprint copy];
    [self updateLabels];
}

#pragma mark - Formatting

- (void)updateLabels
{
    if (self.fingerprint.length == 0) {
        self.topLineLabel.text = @"";
        self.bottomLineLabel.text = @"";
        return;
    }

    /* Strip all non-hex characters and uppercase */
    NSString *hex = [self hexOnlyString:self.fingerprint];

    /* Format into groups of 4 characters separated by spaces */
    NSMutableArray *groups = [NSMutableArray array];
    for (NSUInteger i = 0; i < hex.length; i += 4) {
        NSUInteger len = MIN((NSUInteger)4, hex.length - i);
        [groups addObject:[hex substringWithRange:NSMakeRange(i, len)]];
    }

    /* Split into two lines of 5 groups each (for a 40-char fingerprint) */
    NSUInteger half = (groups.count + 1) / 2;
    if (half > groups.count) {
        half = groups.count;
    }

    NSArray *topGroups = [groups subarrayWithRange:NSMakeRange(0, half)];
    NSArray *bottomGroups = (half < groups.count)
        ? [groups subarrayWithRange:NSMakeRange(half, groups.count - half)]
        : @[];

    self.topLineLabel.text = [topGroups componentsJoinedByString:@" "];
    self.bottomLineLabel.text = [bottomGroups componentsJoinedByString:@" "];
}

- (NSString *)hexOnlyString:(NSString *)input
{
    NSString *upper = [input uppercaseString];
    NSMutableString *result = [NSMutableString string];
    NSCharacterSet *hexChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];

    for (NSUInteger i = 0; i < upper.length; i++) {
        unichar c = [upper characterAtIndex:i];
        if ([hexChars characterIsMember:c]) {
            [result appendFormat:@"%C", c];
        }
    }
    return [result copy];
}

#pragma mark - Tap to Copy

- (void)handleTap:(UITapGestureRecognizer *)recognizer
{
    if (self.fingerprint.length == 0) {
        return;
    }

    [[UIPasteboard generalPasteboard] setString:self.fingerprint];

    /* Flash the background to indicate copy */
    UIColor *originalColor = self.backgroundContainer.backgroundColor;
    [UIView animateWithDuration:0.15 animations:^{
        self.backgroundContainer.backgroundColor = [UIColor colorWithWhite:0.80f alpha:1.0f];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 animations:^{
            self.backgroundContainer.backgroundColor = originalColor;
        }];
    }];
}

#pragma mark - Sizing

- (CGSize)intrinsicContentSize
{
    CGFloat lineHeight = kOPFingerprintFontSize + 2.0f;
    CGFloat height = kOPFingerprintPadding * 2.0f + lineHeight * 2.0f + kOPFingerprintLineSpacing;
    return CGSizeMake(280.0f, height);
}

@end
// onlypgp-wip
