//
//  OPExportViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>

@class OPKey;

@interface OPExportViewController : UIViewController

@property (nonatomic, strong) OPKey *key;
@property (nonatomic, assign) BOOL exportSecret;

@property (nonatomic, strong) IBOutlet UITextView *armoredTextView;
@property (nonatomic, strong) IBOutlet UILabel *warningLabel;
@property (nonatomic, strong) IBOutlet UIButton *copyButton;
@property (nonatomic, strong) IBOutlet UIButton *shareButton;
@property (nonatomic, strong) IBOutlet UIButton *saveToFileButton;

- (IBAction)copyTapped:(id)sender;
- (IBAction)shareTapped:(id)sender;
- (IBAction)saveToFileTapped:(id)sender;

@end
