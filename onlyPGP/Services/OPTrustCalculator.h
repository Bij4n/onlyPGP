//
//  OPTrustCalculator.h
//  onlyPGP
//
//  Created 2014. Web of trust calculation for PGP keys.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class OPKey;

typedef NS_ENUM(NSInteger, OPTrustLevel) {
    OPTrustLevelUnknown  = 0,
    OPTrustLevelNone     = 1,
    OPTrustLevelMarginal = 2,
    OPTrustLevelFull     = 3,
    OPTrustLevelUltimate = 4
};

@interface OPTrustCalculator : NSObject

+ (OPTrustCalculator *)sharedCalculator;

// Calculate effective trust for a key
- (OPTrustLevel)effectiveTrustForKey:(OPKey *)key;

// Trust based on signatures
- (OPTrustLevel)signatureTrustForKey:(OPKey *)key;

// Check if a key is valid (not expired, not revoked, has valid self-sig)
- (BOOL)isKeyValid:(OPKey *)key;

// Get trust description string
+ (NSString *)trustLevelString:(OPTrustLevel)level;
+ (UIColor *)trustLevelColor:(OPTrustLevel)level;

// Marginal count needed for full trust
@property (nonatomic, assign) NSInteger marginalsNeeded; // default 3
@property (nonatomic, assign) NSInteger completesNeeded; // default 1

@end
