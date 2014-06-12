//
//  OPDecryptViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPDecryptViewController.h"
#import "OPKey.h"
#import "OPKeyStore.h"
#import "OPPGPService.h"
#import "OPPassphraseCache.h"
#import "UIColor+OPTheme.h"
#import "NSString+OPArmor.h"
#import "MBProgressHUD.h"

static const NSInteger kPassphraseAlertTag = 400;

@interface OPDecryptViewController ()

@property (nonatomic, strong) NSString *decryptedText;
@property (nonatomic, strong) NSString *pendingArmoredMessage;
@property (nonatomic, strong) NSArray *secretKeys;
@property (nonatomic, assign) NSInteger currentSecretKeyIndex;

@end

@implementation OPDecryptViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Decrypt";

    self.resultsContainer.hidden = YES;
    self.copyPlaintextButton.hidden = YES;
    self.decryptedText = nil;

    [self configureAppearance];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Paste"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(pasteTapped:)];

    // Keyboard dismiss on tap
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)configureAppearance
{
    self.decryptButton.backgroundColor = [UIColor op_tintColor];
    self.decryptButton.layer.cornerRadius = 6.0;
    [self.decryptButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    self.copyPlaintextButton.tintColor = [UIColor op_tintColor];

    self.inputTextView.layer.borderColor = [[UIColor op_grayColor] CGColor];
    self.inputTextView.layer.borderWidth = 0.5;

    self.plaintextTextView.layer.borderColor = [[UIColor op_grayColor] CGColor];
    self.plaintextTextView.layer.borderWidth = 0.5;
    self.plaintextTextView.editable = NO;

    self.inputTextView.text = @"";
    self.signatureStatusLabel.text = @"";
    self.verificationLabel.text = @"";
}

- (void)dismissKeyboard
{
    [self.view endEditing:YES];
}

#pragma mark - Actions

- (IBAction)pasteTapped:(id)sender
{
    NSString *clipboard = [[UIPasteboard generalPasteboard] string];
    if (clipboard && [clipboard length] > 0) {
        NSString *armoredBlock = [clipboard op_extractArmoredBlock];
        if (armoredBlock) {
            self.inputTextView.text = armoredBlock;
        } else {
            self.inputTextView.text = clipboard;
        }
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Clipboard Empty"
                                                        message:@"No text found on the clipboard."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (IBAction)decryptTapped:(id)sender
{
    [self.inputTextView resignFirstResponder];

    NSString *input = [self.inputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([input length] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Input"
                                                        message:@"Please paste an armored PGP message to decrypt."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    if (![input op_isArmoredMessage] && ![input op_isArmoredPGPBlock]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid Input"
                                                        message:@"The pasted text does not appear to be an armored PGP message."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    self.pendingArmoredMessage = input;
    self.secretKeys = [[OPKeyStore sharedStore] allSecretKeys];

    if ([self.secretKeys count] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Secret Keys"
                                                        message:@"You need a secret key to decrypt messages. Import or generate one first."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    // Try cached passphrases first
    [self attemptDecryptWithCachedPassphrases];
}

- (IBAction)copyPlaintextTapped:(id)sender
{
    if (self.decryptedText) {
        [[UIPasteboard generalPasteboard] setString:self.decryptedText];

        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeText;
        hud.labelText = @"Copied!";
        [hud hide:YES afterDelay:1.0];
    }
}

#pragma mark - Decryption Logic

- (void)attemptDecryptWithCachedPassphrases
{
    // Try each secret key with its cached passphrase
    for (OPKey *secretKey in self.secretKeys) {
        NSString *cached = [[OPPassphraseCache sharedCache] cachedPassphraseForKeyID:secretKey.keyID];
        if (cached) {
            NSError *error = nil;
            NSString *plaintext = [[OPPGPService sharedService] decryptArmoredMessage:self.pendingArmoredMessage
                                                                           passphrase:cached
                                                                                error:&error];
            if (plaintext) {
                [self displayDecryptedResult:plaintext];
                return;
            }
        }
    }

    // No cached passphrase worked, prompt user
    self.currentSecretKeyIndex = 0;
    [self promptForPassphraseAtCurrentIndex];
}

- (void)promptForPassphraseAtCurrentIndex
{
    if (self.currentSecretKeyIndex >= (NSInteger)[self.secretKeys count]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Decryption Failed"
                                                        message:@"Could not decrypt the message with any of your secret keys. The message may not be encrypted to you."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    OPKey *key = self.secretKeys[self.currentSecretKeyIndex];
    NSString *name = key.primaryUserID ?: key.shortKeyID ?: key.keyID;

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Enter Passphrase"
                                                    message:[NSString stringWithFormat:@"Key: %@", name]
                                                   delegate:self
                                          cancelButtonTitle:@"Skip"
                                          otherButtonTitles:@"Decrypt", nil];
    alert.alertViewStyle = UIAlertViewStyleSecureTextInput;
    alert.tag = kPassphraseAlertTag;
    [alert show];
}

- (void)attemptDecryptWithPassphrase:(NSString *)passphrase forKeyAtIndex:(NSInteger)keyIndex
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Decrypting...";

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSString *plaintext = [[OPPGPService sharedService] decryptArmoredMessage:self.pendingArmoredMessage
                                                                       passphrase:passphrase
                                                                            error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];

            if (plaintext) {
                // Cache the working passphrase
                OPKey *key = self.secretKeys[keyIndex];
                [[OPPassphraseCache sharedCache] cachePassphrase:passphrase forKeyID:key.keyID];
                [self displayDecryptedResult:plaintext];
            } else {
                // Try next key
                self.currentSecretKeyIndex++;
                [self promptForPassphraseAtCurrentIndex];
            }
        });
    });
}

- (void)displayDecryptedResult:(NSString *)plaintext
{
    self.decryptedText = plaintext;
    self.resultsContainer.hidden = NO;
    self.copyPlaintextButton.hidden = NO;
    self.plaintextTextView.text = plaintext;

    // Attempt to determine signature info
    // The decrypt result may contain metadata; for now show basic status
    [self updateSignatureDisplay];
}

- (void)updateSignatureDisplay
{
    // Check if the decrypted text has signature metadata
    // In a full implementation, OPPGPService would return signature info alongside plaintext
    // For now, show a basic indicator
    self.signatureStatusLabel.text = @"Decryption successful";
    self.signatureStatusLabel.textColor = [UIColor op_greenColor];
    self.verificationLabel.text = @"Message decrypted successfully";
    self.verificationLabel.textColor = [UIColor op_grayColor];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kPassphraseAlertTag) {
        if (buttonIndex == 0) {
            // Skip - try next key
            self.currentSecretKeyIndex++;
            [self promptForPassphraseAtCurrentIndex];
        } else if (buttonIndex == 1) {
            // Decrypt
            NSString *passphrase = [alertView textFieldAtIndex:0].text;
            [self attemptDecryptWithPassphrase:passphrase forKeyAtIndex:self.currentSecretKeyIndex];
        }
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    if (textView == self.inputTextView) {
        // Hide results when input changes
        self.resultsContainer.hidden = YES;
        self.copyPlaintextButton.hidden = YES;
        self.decryptedText = nil;
    }
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
