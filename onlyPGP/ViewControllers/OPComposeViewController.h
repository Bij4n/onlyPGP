//
//  OPComposeViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OPComposeViewController : UIViewController <UITextViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UITextView *messageTextView;
@property (nonatomic, strong) IBOutlet UIButton *recipientsButton;
@property (nonatomic, strong) IBOutlet UILabel *recipientsLabel;
@property (nonatomic, strong) IBOutlet UIButton *signAsButton;
@property (nonatomic, strong) IBOutlet UILabel *signAsLabel;
@property (nonatomic, strong) IBOutlet UIButton *encryptButton;

- (IBAction)selectRecipientsTapped:(id)sender;
- (IBAction)selectSigningKeyTapped:(id)sender;
- (IBAction)encryptAndSendTapped:(id)sender;

@end
