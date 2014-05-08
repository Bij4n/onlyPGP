//
//  OPTrustBadgeView.m
//  onlyPGP
//
//  Created 2014. ARC enabled.
//

#import "OPTrustBadgeView.h"
#import "UIColor+OPTheme.h"

static const CGFloat kOPTrustCircleSize   = 12.0f;
static const CGFloat kOPTrustCircleMargin = 6.0f;
static const CGFloat kOPTrustFontSize     = 13.0f;

@interface OPTrustBadgeView ()

@property (nonatomic, strong) UIView  *circleView;
@property (nonatomic, strong) UILabel *trustLabel;
@property (nonatomic, assign, readwrite) OPTrustLevel trustLevel;
@property (nonatomic, copy, readwrite)   NSString *trustString;

@end

@implementation OPTrustBadgeView

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
    self.backgroundColor = [UIColor clearColor];

    /* Colored circle */
    self.circleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kOPTrustCircleSize, kOPTrustCircleSize)];
    self.circleView.layer.cornerRadius = kOPTrustCircleSize / 2.0f;
    self.circleView.clipsToBounds = YES;
    self.circleView.backgroundColor = [UIColor op_grayColor];
    [self addSubview:self.circleView];

    /* Trust label */
    self.trustLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.trustLabel.font = [UIFont systemFontOfSize:kOPTrustFontSize];
    self.trustLabel.textColor = [UIColor op_darkTextColor];
    self.trustLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:self.trustLabel];

    /* Default state */
    _trustLevel = OPTrustLevelUnknown;
    _trustString = @"Unknown";
    self.trustLabel.text = _trustString;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat midY = CGRectGetHeight(self.bounds) / 2.0f;

    self.circleView.frame = CGRectMake(0,
                                       midY - kOPTrustCircleSize / 2.0f,
                                       kOPTrustCircleSize,
                                       kOPTrustCircleSize);

    CGFloat labelX = kOPTrustCircleSize + kOPTrustCircleMargin;
    CGFloat labelWidth = CGRectGetWidth(self.bounds) - labelX;
    if (labelWidth < 0) labelWidth = 0;

    self.trustLabel.frame = CGRectMake(labelX,
                                       0,
                                       labelWidth,
                                       CGRectGetHeight(self.bounds));
}

#pragma mark - Public

- (void)setTrustLevel:(OPTrustLevel)level
{
    _trustLevel = level;

    UIColor *color = nil;
    NSString *text = nil;

    switch (level) {
        case OPTrustLevelUltimate:
            color = [UIColor op_greenColor];
            text = @"Ultimate";
            break;
        case OPTrustLevelFull:
            color = [UIColor op_greenColor];
            text = @"Full";
            break;
        case OPTrustLevelMarginal:
            color = [UIColor op_orangeColor];
            text = @"Marginal";
            break;
        case OPTrustLevelNone:
            color = [UIColor op_redColor];
            text = @"None";
            break;
        case OPTrustLevelUnknown:
        default:
            color = [UIColor op_grayColor];
            text = @"Unknown";
            break;
    }

    self.circleView.backgroundColor = color;
    self.trustLabel.text = text;
    self.trustLabel.textColor = color;
    _trustString = text;

    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

#pragma mark - Sizing

- (CGSize)intrinsicContentSize
{
    CGSize labelSize = [self.trustLabel.text sizeWithAttributes:@{
        NSFontAttributeName : self.trustLabel.font
    }];

    CGFloat width = kOPTrustCircleSize + kOPTrustCircleMargin + ceilf((float)labelSize.width);
    CGFloat height = MAX(kOPTrustCircleSize, ceilf((float)labelSize.height));

    return CGSizeMake(width, height);
}

@end
