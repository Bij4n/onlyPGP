//
//  OPKeyCell.h
//  onlyPGP
//
//  Created 2014. ARC enabled.
//

#import <UIKit/UIKit.h>

@class OPKey;

@interface OPKeyCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *nameLabel;
@property (nonatomic, weak) IBOutlet UILabel *emailLabel;
@property (nonatomic, weak) IBOutlet UILabel *keyInfoLabel;
@property (nonatomic, weak) IBOutlet UIView *trustBadge;
@property (nonatomic, weak) IBOutlet UIImageView *lockIcon;

- (void)configureWithKey:(OPKey *)key;

@end
