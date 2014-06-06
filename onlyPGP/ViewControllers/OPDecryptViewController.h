//
//  OPDecryptViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OPDecryptViewController : UIViewController <UITextViewDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UITextView *inputTextView;
@property (nonatomic, strong) IBOutlet UIButton *decryptButton;
@property (nonatomic, strong) IBOutlet UIView *resultsContainer;
@property (nonatomic, strong) IBOutlet UITextView *plaintextTextView;
@property (nonatomic, strong) IBOutlet UILabel *signatureStatusLabel;
@property (nonatomic, strong) IBOutlet UILabel *verificationLabel;
@property (nonatomic, strong) IBOutlet UIButton *copyPlaintextButton;

- (IBAction)decryptTapped:(id)sender;
- (IBAction)copyPlaintextTapped:(id)sender;
- (IBAction)pasteTapped:(id)sender;

@end
