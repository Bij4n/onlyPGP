//
//  OPKeyCell.m
//  onlyPGP
//
//  Created 2014. ARC enabled.
//

#import "OPKeyCell.h"
#import "OPKey.h"
#import "UIColor+OPTheme.h"

@implementation OPKeyCell

- (void)awakeFromNib
{
    [super awakeFromNib];

    self.trustBadge.layer.cornerRadius = 5.0f;
    self.trustBadge.clipsToBounds = YES;

    self.nameLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    self.nameLabel.textColor = [UIColor op_darkTextColor];

    self.emailLabel.font = [UIFont systemFontOfSize:13.0f];
    self.emailLabel.textColor = [UIColor grayColor];

    self.keyInfoLabel.font = [UIFont systemFontOfSize:11.0f];
    self.keyInfoLabel.textColor = [UIColor op_grayColor];
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.nameLabel.text = nil;
    self.nameLabel.textColor = [UIColor op_darkTextColor];
    self.nameLabel.attributedText = nil;
    self.emailLabel.text = nil;
    self.keyInfoLabel.text = nil;
    self.trustBadge.backgroundColor = [UIColor op_grayColor];
    self.lockIcon.hidden = YES;
}

- (void)configureWithKey:(OPKey *)key
{
    /* --- Parse name and email from primaryUserID --- */
    NSString *name = nil;
    NSString *email = nil;

    if (key.primaryUserID.length > 0) {
        [self parseName:&name email:&email fromUserID:key.primaryUserID];
    }

    if (name.length == 0) {
        name = @"Unknown";
    }

    if (email.length == 0) {
        email = key.shortKeyID ? key.shortKeyID : @"";
    }

    /* --- Name label (strikethrough / gray when expired or revoked) --- */
    if (key.isExpired || key.isRevoked) {
        NSDictionary *attrs = @{
            NSStrikethroughStyleAttributeName : @(NSUnderlineStyleSingle),
            NSForegroundColorAttributeName    : [UIColor op_grayColor],
            NSFontAttributeName               : [UIFont boldSystemFontOfSize:16.0f]
        };
        self.nameLabel.attributedText = [[NSAttributedString alloc] initWithString:name attributes:attrs];
    } else {
        self.nameLabel.text = name;
        self.nameLabel.textColor = [UIColor op_darkTextColor];
    }

    /* --- Email label --- */
    self.emailLabel.text = email;

    /* --- Key info label: "RSA 4096 · 0xABCD1234" --- */
    NSString *algo = key.algorithmName ? key.algorithmName : @"Unknown";
    NSString *size = key.keySize ? [NSString stringWithFormat:@"%@", key.keySize] : @"?";
    NSString *shortID = key.shortKeyID ? key.shortKeyID : @"????????";
    self.keyInfoLabel.text = [NSString stringWithFormat:@"%@ %@ \u00B7 0x%@", algo, size, shortID];

    /* --- Trust badge color --- */
    self.trustBadge.backgroundColor = [self colorForTrustLevel:key.ownerTrust isRevoked:key.isRevoked];

    /* --- Lock icon --- */
    self.lockIcon.hidden = !key.isSecretKey;
}

#pragma mark - Private

- (void)parseName:(NSString **)outName email:(NSString **)outEmail fromUserID:(NSString *)userID
{
    /*
     * Typical PGP User ID format: "John Doe <john@example.com>"
     * May also be just "john@example.com" or "John Doe (comment) <john@example.com>"
     */
    NSRange angleBracketOpen = [userID rangeOfString:@"<"];
    NSRange angleBracketClose = [userID rangeOfString:@">" options:NSBackwardsSearch];

    if (angleBracketOpen.location != NSNotFound && angleBracketClose.location != NSNotFound &&
        angleBracketClose.location > angleBracketOpen.location) {

        NSUInteger emailStart = angleBracketOpen.location + 1;
        NSUInteger emailLength = angleBracketClose.location - emailStart;
        *outEmail = [userID substringWithRange:NSMakeRange(emailStart, emailLength)];

        if (angleBracketOpen.location > 0) {
            NSString *namePart = [userID substringToIndex:angleBracketOpen.location];
            namePart = [namePart stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (namePart.length > 0) {
                *outName = namePart;
            }
        }
    } else {
        /* No angle brackets — treat entire string as the name */
        *outName = [userID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
}

- (UIColor *)colorForTrustLevel:(OPTrustLevel)level isRevoked:(BOOL)revoked
{
    if (revoked) {
        return [UIColor op_redColor];
    }

    switch (level) {
        case OPTrustLevelFull:
        case OPTrustLevelUltimate:
            return [UIColor op_greenColor];
        case OPTrustLevelMarginal:
            return [UIColor op_orangeColor];
        case OPTrustLevelNone:
            return [UIColor op_redColor];
        case OPTrustLevelUnknown:
        default:
            return [UIColor op_grayColor];
    }
}

@end
// onlypgp-wip
