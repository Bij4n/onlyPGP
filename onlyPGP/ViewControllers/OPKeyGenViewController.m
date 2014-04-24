//
//  OPKeyGenViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPKeyGenViewController.h"
#import "OPKeyGenerator.h"
#import "MBProgressHUD.h"

static const NSInteger kKeySizes[] = {2048, 4096};

@interface OPKeyGenViewController ()

@property (nonatomic, assign) NSUInteger selectedKeySize;
@property (nonatomic, strong) MBProgressHUD *hud;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;

@end

@implementation OPKeyGenViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Generate Key";

    self.selectedKeySize = kKeySizes[0];

    self.nameField.delegate = self;
    self.emailField.delegate = self;
    self.passphraseField.delegate = self;
    self.confirmPassphraseField.delegate = self;

    self.nameField.placeholder = @"Full Name";
    self.nameField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    self.nameField.returnKeyType = UIReturnKeyNext;

    self.emailField.placeholder = @"Email Address";
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.emailField.returnKeyType = UIReturnKeyNext;

    self.passphraseField.placeholder = @"Passphrase (8+ characters)";
    self.passphraseField.secureTextEntry = YES;
    self.passphraseField.returnKeyType = UIReturnKeyNext;

    self.confirmPassphraseField.placeholder = @"Confirm Passphrase";
    self.confirmPassphraseField.secureTextEntry = YES;
    self.confirmPassphraseField.returnKeyType = UIReturnKeyGo;

    [self.keySizeControl setTitle:@"2048" forSegmentAtIndex:0];
    [self.keySizeControl setTitle:@"4096" forSegmentAtIndex:1];
    self.keySizeControl.selectedSegmentIndex = 0;

    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    self.tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.tapGesture];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Keyboard

- (void)dismissKeyboard
{
    [self.view endEditing:YES];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    CGRect keyboardFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];

    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.bottom = keyboardFrame.size.height;

    [UIView animateWithDuration:duration animations:^{
        self.scrollView.contentInset = insets;
        self.scrollView.scrollIndicatorInsets = insets;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    CGFloat duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];

    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.bottom = 0;

    [UIView animateWithDuration:duration animations:^{
        self.scrollView.contentInset = insets;
        self.scrollView.scrollIndicatorInsets = insets;
    }];
}

#pragma mark - IBActions

- (IBAction)keySizeChanged:(id)sender
{
    NSInteger index = self.keySizeControl.selectedSegmentIndex;
    if (index >= 0 && index < 2) {
        self.selectedKeySize = kKeySizes[index];
    }
}

- (IBAction)generateTapped:(id)sender
{
    [self.view endEditing:YES];

    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *email = [self.emailField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *passphrase = self.passphraseField.text;
    NSString *confirmPassphrase = self.confirmPassphraseField.text;

    // Validation
    if ([name length] == 0) {
        [self showAlertWithTitle:@"Error" message:@"Please enter your name."];
        return;
    }

    if ([email length] == 0 || [email rangeOfString:@"@"].location == NSNotFound) {
        [self showAlertWithTitle:@"Error" message:@"Please enter a valid email address."];
        return;
    }

    if ([passphrase length] < 8) {
        [self showAlertWithTitle:@"Error" message:@"Passphrase must be at least 8 characters."];
        return;
    }

    if (![passphrase isEqualToString:confirmPassphrase]) {
        [self showAlertWithTitle:@"Error" message:@"Passphrases do not match."];
        return;
    }

    // Show progress
    self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.hud.mode = MBProgressHUDModeDeterminate;
    self.hud.labelText = @"Generating key pair...";
    self.hud.detailsLabelText = @"This may take a while";

    self.generateButton.enabled = NO;
    self.navigationItem.hidesBackButton = YES;

    __weak typeof(self) weakSelf = self;

    [[OPKeyGenerator sharedGenerator] generateKeyPairWithName:name
                                                        email:email
                                                      keySize:self.selectedKeySize
                                                   passphrase:passphrase
                                                     progress:^(float progress) {
                                                         dispatch_async(dispatch_get_main_queue(), ^{
                                                             weakSelf.hud.progress = progress;

                                                             if (progress < 0.3) {
                                                                 weakSelf.hud.detailsLabelText = @"Generating prime numbers...";
                                                             } else if (progress < 0.7) {
                                                                 weakSelf.hud.detailsLabelText = @"Building key structure...";
                                                             } else {
                                                                 weakSelf.hud.detailsLabelText = @"Finalizing...";
                                                             }
                                                         });
                                                     }
                                                   completion:^(OPKey *generatedKey, NSError *error) {
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           [weakSelf.hud hide:YES];
                                                           weakSelf.generateButton.enabled = YES;
                                                           weakSelf.navigationItem.hidesBackButton = NO;

                                                           if (error) {
                                                               [weakSelf showAlertWithTitle:@"Generation Failed"
                                                                                   message:[error localizedDescription]];
                                                               return;
                                                           }

                                                           [[NSNotificationCenter defaultCenter] postNotificationName:@"OPKeyringDidChangeNotification"
                                                                                                               object:nil];

                                                           MBProgressHUD *successHud = [MBProgressHUD showHUDAddedTo:weakSelf.view animated:YES];
                                                           successHud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"checkmark"]];
                                                           successHud.mode = MBProgressHUDModeCustomView;
                                                           successHud.labelText = @"Key Generated!";
                                                           [successHud hide:YES afterDelay:1.5];

                                                           dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                               [weakSelf.navigationController popViewControllerAnimated:YES];
                                                           });
                                                       });
                                                   }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.nameField) {
        [self.emailField becomeFirstResponder];
    } else if (textField == self.emailField) {
        [self.passphraseField becomeFirstResponder];
    } else if (textField == self.passphraseField) {
        [self.confirmPassphraseField becomeFirstResponder];
    } else if (textField == self.confirmPassphraseField) {
        [self generateTapped:textField];
    }
    return YES;
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
// onlypgp-wip
