//
//  OPExportViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPExportViewController.h"
#import "OPKey.h"
#import "OPPGPService.h"
#import "UIColor+OPAdditions.h"

@interface OPExportViewController ()

@property (nonatomic, strong) NSString *armoredKeyText;

@end

@implementation OPExportViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (self.exportSecret) {
        self.title = @"Export Secret Key";
    } else {
        self.title = @"Export Public Key";
    }

    // Load armored key text
    NSError *error = nil;
    if (self.exportSecret) {
        self.armoredKeyText = [[OPPGPService sharedService] exportArmoredSecretKeyForKeyID:self.key.keyID error:&error];
    } else {
        self.armoredKeyText = [[OPPGPService sharedService] exportArmoredPublicKeyForKeyID:self.key.keyID error:&error];
    }

    if (error || !self.armoredKeyText) {
        self.armoredKeyText = @"Error: Could not export key.";
    }

    // Configure text view
    self.armoredTextView.text = self.armoredKeyText;
    self.armoredTextView.font = [UIFont fontWithName:@"Courier" size:11.0];
    self.armoredTextView.editable = NO;
    self.armoredTextView.dataDetectorTypes = UIDataDetectorTypeNone;
    self.armoredTextView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.armoredTextView.layer.borderWidth = 0.5;
    self.armoredTextView.layer.cornerRadius = 4.0;
    self.armoredTextView.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1.0];

    // Warning label
    if (self.exportSecret) {
        self.warningLabel.text = @"WARNING: This is your SECRET key. Never share it.";
        self.warningLabel.textColor = [UIColor whiteColor];
        self.warningLabel.backgroundColor = [UIColor op_redColor];
        self.warningLabel.textAlignment = NSTextAlignmentCenter;
        self.warningLabel.font = [UIFont boldSystemFontOfSize:13.0];
        self.warningLabel.hidden = NO;
    } else {
        self.warningLabel.hidden = YES;
    }

    // Buttons
    [self.copyButton setTitle:@"Copy to Clipboard" forState:UIControlStateNormal];
    [self.copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.copyButton.backgroundColor = [UIColor op_tintColor];
    self.copyButton.layer.cornerRadius = 4.0;

    [self.shareButton setTitle:@"Share" forState:UIControlStateNormal];
    [self.shareButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.shareButton.backgroundColor = [UIColor op_tintColor];
    self.shareButton.layer.cornerRadius = 4.0;

    [self.saveToFileButton setTitle:@"Save to File" forState:UIControlStateNormal];
    [self.saveToFileButton setTitleColor:[UIColor op_tintColor] forState:UIControlStateNormal];
    self.saveToFileButton.layer.borderColor = [[UIColor op_tintColor] CGColor];
    self.saveToFileButton.layer.borderWidth = 1.0;
    self.saveToFileButton.layer.cornerRadius = 4.0;
}

#pragma mark - IBActions

- (IBAction)copyTapped:(id)sender
{
    [[UIPasteboard generalPasteboard] setString:self.armoredKeyText];

    NSString *originalTitle = [self.copyButton titleForState:UIControlStateNormal];
    [self.copyButton setTitle:@"Copied!" forState:UIControlStateNormal];
    self.copyButton.enabled = NO;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.copyButton setTitle:originalTitle forState:UIControlStateNormal];
        self.copyButton.enabled = YES;
    });
}

- (IBAction)shareTapped:(id)sender
{
    NSArray *items = @[self.armoredKeyText];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    activityVC.excludedActivityTypes = @[UIActivityTypePostToFacebook, UIActivityTypePostToTwitter,
                                         UIActivityTypePostToWeibo, UIActivityTypeAssignToContact,
                                         UIActivityTypeSaveToCameraRoll];
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (IBAction)saveToFileTapped:(id)sender
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths firstObject];

    NSString *keyType = self.exportSecret ? @"secret" : @"public";
    NSString *shortID = self.key.shortKeyID ? self.key.shortKeyID : @"unknown";
    NSString *filename = [NSString stringWithFormat:@"%@_%@.asc", shortID, keyType];
    NSString *filePath = [documentsDir stringByAppendingPathComponent:filename];

    // Check if file already exists
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSString *timestamp = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
        filename = [NSString stringWithFormat:@"%@_%@_%@.asc", shortID, keyType, timestamp];
        filePath = [documentsDir stringByAppendingPathComponent:filename];
    }

    NSError *error = nil;
    BOOL success = [self.armoredKeyText writeToFile:filePath
                                         atomically:YES
                                           encoding:NSUTF8StringEncoding
                                              error:&error];

    if (success) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Saved"
                                                        message:[NSString stringWithFormat:@"Key saved as %@\n\nUse iTunes File Sharing to access the file.", filename]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        [alert show];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Save Failed"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        [alert show];
    }
}

@end
// onlypgp-wip
