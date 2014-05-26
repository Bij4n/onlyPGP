//
//  OPQRDisplayViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>

@class OPKey;

@interface OPQRDisplayViewController : UIViewController

@property (nonatomic, strong) OPKey *key;

@property (nonatomic, strong) IBOutlet UIImageView *qrImageView;
@property (nonatomic, strong) IBOutlet UILabel *pageLabel;
@property (nonatomic, strong) IBOutlet UIButton *previousButton;
@property (nonatomic, strong) IBOutlet UIButton *nextButton;
@property (nonatomic, strong) IBOutlet UISwitch *autoAdvanceSwitch;
@property (nonatomic, strong) IBOutlet UILabel *autoAdvanceLabel;

- (IBAction)previousTapped:(id)sender;
- (IBAction)nextTapped:(id)sender;
- (IBAction)autoAdvanceToggled:(id)sender;

@end
