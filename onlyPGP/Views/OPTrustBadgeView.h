//
//  OPTrustBadgeView.h
//  onlyPGP
//
//  Created 2014. ARC enabled.
//

#import <UIKit/UIKit.h>
#import "OPKey.h"

@interface OPTrustBadgeView : UIView

@property (nonatomic, assign, readonly) OPTrustLevel trustLevel;
@property (nonatomic, copy, readonly)   NSString *trustString;

- (void)setTrustLevel:(OPTrustLevel)level;

@end
