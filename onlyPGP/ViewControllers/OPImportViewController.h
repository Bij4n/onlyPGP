//
//  OPImportViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OPImportViewController : UIViewController <UITextViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UITextView *armoredTextView;
@property (nonatomic, strong) IBOutlet UIButton *importButton;
@property (nonatomic, strong) IBOutlet UIButton *importFromFileButton;
@property (nonatomic, strong) IBOutlet UILabel *placeholderLabel;

- (IBAction)importTapped:(id)sender;
- (IBAction)importFromFileTapped:(id)sender;

@end
