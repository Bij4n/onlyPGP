//
//  OPImportViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPImportViewController.h"
#import "OPPGPService.h"
#import "OPKeyStore.h"
#import "NSString+OPAdditions.h"
#import "UIColor+OPAdditions.h"

static const NSInteger kFilePickerActionSheetTag = 100;
static const NSInteger kImportSuccessAlertTag = 200;

@interface OPImportViewController ()

@property (nonatomic, strong) NSArray *ascFiles;

@end

@implementation OPImportViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Import Key";

    self.armoredTextView.delegate = self;
    self.armoredTextView.font = [UIFont fontWithName:@"Courier" size:13.0];
    self.armoredTextView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.armoredTextView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.armoredTextView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.armoredTextView.layer.borderWidth = 0.5;
    self.armoredTextView.layer.cornerRadius = 4.0;

    self.placeholderLabel.text = @"Paste armored PGP key here...";
    self.placeholderLabel.textColor = [UIColor lightGrayColor];
    self.placeholderLabel.font = [UIFont systemFontOfSize:15.0];
    self.placeholderLabel.hidden = NO;

    [self.importButton setTitle:@"Import" forState:UIControlStateNormal];
    [self.importButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.importButton.backgroundColor = [UIColor op_tintColor];
    self.importButton.layer.cornerRadius = 4.0;

    [self.importFromFileButton setTitle:@"Import from File" forState:UIControlStateNormal];
    [self.importFromFileButton setTitleColor:[UIColor op_tintColor] forState:UIControlStateNormal];

    // Check clipboard for PGP data
    NSString *clipboardContent = [[UIPasteboard generalPasteboard] string];
    if (clipboardContent && [clipboardContent op_isArmoredPGPBlock]) {
        self.armoredTextView.text = clipboardContent;
        self.placeholderLabel.hidden = YES;
    }

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)dismissKeyboard
{
    [self.armoredTextView resignFirstResponder];
}

#pragma mark - IBActions

- (IBAction)importTapped:(id)sender
{
    [self dismissKeyboard];

    NSString *armoredText = [self.armoredTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([armoredText length] == 0) {
        [self showAlertWithTitle:@"Error" message:@"Please paste an armored PGP key."];
        return;
    }

    // Try to extract armored block if the text contains extra content
    NSString *extractedBlock = [armoredText op_extractArmoredBlock];
    if (extractedBlock) {
        armoredText = extractedBlock;
    }

    if (![armoredText op_isArmoredPGPBlock]) {
        [self showAlertWithTitle:@"Invalid Key"
                         message:@"The text does not appear to be a valid armored PGP key block."];
        return;
    }

    [self importArmoredKey:armoredText];
}

- (IBAction)importFromFileTapped:(id)sender
{
    [self dismissKeyboard];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths firstObject];

    NSError *error = nil;
    NSArray *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDir error:&error];

    if (error) {
        [self showAlertWithTitle:@"Error" message:@"Could not access Documents directory."];
        return;
    }

    NSMutableArray *ascFiles = [NSMutableArray array];
    for (NSString *file in allFiles) {
        NSString *extension = [[file pathExtension] lowercaseString];
        if ([extension isEqualToString:@"asc"] || [extension isEqualToString:@"gpg"] || [extension isEqualToString:@"pgp"] || [extension isEqualToString:@"key"]) {
            [ascFiles addObject:file];
        }
    }

    if ([ascFiles count] == 0) {
        [self showAlertWithTitle:@"No Key Files Found"
                         message:@"No .asc, .gpg, .pgp, or .key files found in the Documents directory. Use iTunes File Sharing to add key files."];
        return;
    }

    self.ascFiles = [ascFiles copy];

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Select Key File"
                                                      delegate:self
                                             cancelButtonTitle:nil
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:nil];
    sheet.tag = kFilePickerActionSheetTag;

    for (NSString *file in self.ascFiles) {
        [sheet addButtonWithTitle:file];
    }

    NSInteger cancelIndex = [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = cancelIndex;

    [sheet showInView:self.view];
}

#pragma mark - Import Logic

- (void)importArmoredKey:(NSString *)armoredText
{
    NSError *error = nil;
    OPKey *importedKey = [[OPPGPService sharedService] importKeyFromArmoredString:armoredText error:&error];

    if (error || !importedKey) {
        NSString *message = [error localizedDescription];
        if (!message) {
            message = @"The key could not be imported. Please check the format.";
        }
        [self showAlertWithTitle:@"Import Failed" message:message];
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"OPKeyringDidChangeNotification" object:nil];

    NSString *primaryName = importedKey.primaryUserID ? importedKey.primaryUserID : importedKey.shortKeyID;
    NSString *message = [NSString stringWithFormat:@"Successfully imported key for %@.", primaryName];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Import Successful"
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil];
    alert.tag = kImportSuccessAlertTag;
    [alert show];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == kFilePickerActionSheetTag) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;

        if (buttonIndex < (NSInteger)[self.ascFiles count]) {
            NSString *filename = self.ascFiles[buttonIndex];
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDir = [paths firstObject];
            NSString *filePath = [documentsDir stringByAppendingPathComponent:filename];

            NSError *readError = nil;
            NSString *fileContent = [NSString stringWithContentsOfFile:filePath
                                                             encoding:NSUTF8StringEncoding
                                                                error:&readError];

            if (readError || !fileContent) {
                [self showAlertWithTitle:@"Read Error"
                                 message:[NSString stringWithFormat:@"Could not read file: %@", filename]];
                return;
            }

            self.armoredTextView.text = fileContent;
            self.placeholderLabel.hidden = YES;

            if ([fileContent op_isArmoredPGPBlock]) {
                [self importArmoredKey:fileContent];
            } else {
                NSString *extracted = [fileContent op_extractArmoredBlock];
                if (extracted) {
                    [self importArmoredKey:extracted];
                } else {
                    [self showAlertWithTitle:@"Invalid File"
                                     message:@"The file does not contain a valid armored PGP key."];
                }
            }
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kImportSuccessAlertTag) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    self.placeholderLabel.hidden = ([textView.text length] > 0);
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if ([textView.text length] > 0) {
        self.placeholderLabel.hidden = YES;
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if ([textView.text length] == 0) {
        self.placeholderLabel.hidden = NO;
    }
}

#pragma mark - Helpers

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil];
    [alert show];
}

@end
