//
//  OPKeyGenViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OPKeyGenViewController : UIViewController <UITextFieldDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) IBOutlet UITextField *nameField;
@property (nonatomic, strong) IBOutlet UITextField *emailField;
@property (nonatomic, strong) IBOutlet UISegmentedControl *keySizeControl;
@property (nonatomic, strong) IBOutlet UITextField *passphraseField;
@property (nonatomic, strong) IBOutlet UITextField *confirmPassphraseField;
@property (nonatomic, strong) IBOutlet UIButton *generateButton;

- (IBAction)generateTapped:(id)sender;
- (IBAction)keySizeChanged:(id)sender;

@end
