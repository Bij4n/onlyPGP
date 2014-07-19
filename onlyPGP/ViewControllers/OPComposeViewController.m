//
//  OPComposeViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPComposeViewController.h"
#import "OPKey.h"
#import "OPKeyStore.h"
#import "OPPGPService.h"
#import "OPPassphraseCache.h"
#import "UIColor+OPTheme.h"
#import "MBProgressHUD.h"

static const NSInteger kPassphraseAlertTag = 200;
static const NSInteger kSigningKeyActionSheetTag = 300;

#pragma mark - OPRecipientPickerViewController

@interface OPRecipientPickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSArray *allPublicKeys;
@property (nonatomic, strong) NSMutableSet *selectedKeyIDs;
@property (nonatomic, copy) void (^completionBlock)(NSArray *selectedKeyIDs);

@end

@implementation OPRecipientPickerViewController
{
    UITableView *_pickerTableView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Select Recipients";
    self.view.backgroundColor = [UIColor whiteColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(doneTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                         target:self
                                                                                         action:@selector(cancelTapped)];

    _pickerTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _pickerTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _pickerTableView.dataSource = self;
    _pickerTableView.delegate = self;
    _pickerTableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_pickerTableView];

    self.allPublicKeys = [[OPKeyStore sharedStore] allPublicKeys];

    if (!self.selectedKeyIDs) {
        self.selectedKeyIDs = [NSMutableSet set];
    }
}

- (void)doneTapped
{
    if (self.completionBlock) {
        self.completionBlock([self.selectedKeyIDs allObjects]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancelTapped
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.allPublicKeys count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"RecipientCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    }

    OPKey *key = self.allPublicKeys[indexPath.row];
    cell.textLabel.text = key.primaryUserID ?: @"Unknown";
    cell.textLabel.font = [UIFont systemFontOfSize:15.0];
    cell.detailTextLabel.text = key.shortKeyID ?: key.keyID;
    cell.detailTextLabel.textColor = [UIColor op_grayColor];

    BOOL isSelected = [self.selectedKeyIDs containsObject:key.keyID];
    cell.accessoryType = isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    OPKey *key = self.allPublicKeys[indexPath.row];
    NSString *keyID = key.keyID;

    if ([self.selectedKeyIDs containsObject:keyID]) {
        [self.selectedKeyIDs removeObject:keyID];
    } else {
        [self.selectedKeyIDs addObject:keyID];
    }

    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

@end

#pragma mark - OPComposeViewController

@interface OPComposeViewController ()

@property (nonatomic, strong) NSMutableArray *selectedRecipientKeyIDs;
@property (nonatomic, strong) NSString *signingKeyID;
@property (nonatomic, strong) NSArray *secretKeys;

@end

@implementation OPComposeViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Compose";
    self.selectedRecipientKeyIDs = [NSMutableArray array];
    self.signingKeyID = nil;
    self.secretKeys = [[OPKeyStore sharedStore] allSecretKeys];

    [self configureAppearance];
    [self updateRecipientDisplay];
    [self updateSignAsDisplay];

    // Load default signing key from user defaults
    NSString *defaultKeyID = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultSigningKeyID"];
    if (defaultKeyID) {
        OPKey *defaultKey = [[OPKeyStore sharedStore] keyWithKeyID:defaultKeyID];
        if (defaultKey && defaultKey.isSecretKey) {
            self.signingKeyID = defaultKeyID;
            [self updateSignAsDisplay];
        }
    }

    // Keyboard notifications
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

- (void)configureAppearance
{
    self.encryptButton.backgroundColor = [UIColor op_tintColor];
    self.encryptButton.layer.cornerRadius = 6.0;
    [self.encryptButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    self.messageTextView.layer.borderColor = [[UIColor op_grayColor] CGColor];
    self.messageTextView.layer.borderWidth = 0.5;

    self.recipientsButton.tintColor = [UIColor op_tintColor];
    self.signAsButton.tintColor = [UIColor op_tintColor];
}

#pragma mark - Display Updates

- (void)updateRecipientDisplay
{
    if ([self.selectedRecipientKeyIDs count] == 0) {
        self.recipientsLabel.text = @"No recipients selected";
        self.recipientsLabel.textColor = [UIColor op_grayColor];
        return;
    }

    NSMutableArray *names = [NSMutableArray array];
    for (NSString *keyID in self.selectedRecipientKeyIDs) {
        OPKey *key = [[OPKeyStore sharedStore] keyWithKeyID:keyID];
        if (key) {
            [names addObject:key.primaryUserID ?: key.shortKeyID ?: keyID];
        } else {
            [names addObject:keyID];
        }
    }

    self.recipientsLabel.text = [names componentsJoinedByString:@", "];
    self.recipientsLabel.textColor = [UIColor darkTextColor];
}

- (void)updateSignAsDisplay
{
    if (!self.signingKeyID) {
        self.signAsLabel.text = @"None (unsigned)";
        self.signAsLabel.textColor = [UIColor op_grayColor];
        return;
    }

    OPKey *key = [[OPKeyStore sharedStore] keyWithKeyID:self.signingKeyID];
    if (key) {
        self.signAsLabel.text = key.primaryUserID ?: key.shortKeyID ?: self.signingKeyID;
        self.signAsLabel.textColor = [UIColor darkTextColor];
    } else {
        self.signAsLabel.text = self.signingKeyID;
        self.signAsLabel.textColor = [UIColor op_orangeColor];
    }
}

#pragma mark - Actions

- (IBAction)selectRecipientsTapped:(id)sender
{
    OPRecipientPickerViewController *picker = [[OPRecipientPickerViewController alloc] init];

    NSMutableSet *currentSelection = [NSMutableSet setWithArray:self.selectedRecipientKeyIDs];
    picker.selectedKeyIDs = currentSelection;

    __weak typeof(self) weakSelf = self;
    picker.completionBlock = ^(NSArray *selectedKeyIDs) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [strongSelf.selectedRecipientKeyIDs removeAllObjects];
        [strongSelf.selectedRecipientKeyIDs addObjectsFromArray:selectedKeyIDs];
        [strongSelf updateRecipientDisplay];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:nav animated:YES completion:nil];
}

- (IBAction)selectSigningKeyTapped:(id)sender
{
    self.secretKeys = [[OPKeyStore sharedStore] allSecretKeys];

    if ([self.secretKeys count] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Secret Keys"
                                                        message:@"You have no secret keys for signing. Generate or import one first."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Sign As"
                                                      delegate:self
                                             cancelButtonTitle:nil
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:nil];
    sheet.tag = kSigningKeyActionSheetTag;

    [sheet addButtonWithTitle:@"None (don't sign)"];

    for (OPKey *key in self.secretKeys) {
        NSString *title = key.primaryUserID ?: key.shortKeyID ?: key.keyID;
        [sheet addButtonWithTitle:title];
    }

    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = [self.secretKeys count] + 1;

    [sheet showInView:self.view];
}

- (IBAction)encryptAndSendTapped:(id)sender
{
    // Validate
    if ([self.selectedRecipientKeyIDs count] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Recipients"
                                                        message:@"Please select at least one recipient."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    NSString *messageText = [self.messageTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([messageText length] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Empty Message"
                                                        message:@"Please enter a message to encrypt."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    [self.messageTextView resignFirstResponder];

    // If signing, get passphrase
    if (self.signingKeyID) {
        NSString *cached = [[OPPassphraseCache sharedCache] cachedPassphraseForKeyID:self.signingKeyID];
        if (cached) {
            [self doEncryptWithPassphrase:cached];
        } else {
            [self promptForPassphrase];
        }
    } else {
        [self doEncryptWithPassphrase:nil];
    }
}

- (void)promptForPassphrase
{
    OPKey *signingKey = [[OPKeyStore sharedStore] keyWithKeyID:self.signingKeyID];
    NSString *name = signingKey.primaryUserID ?: self.signingKeyID;

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Passphrase Required"
                                                    message:[NSString stringWithFormat:@"Enter passphrase for:\n%@", name]
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"OK", nil];
    alert.alertViewStyle = UIAlertViewStyleSecureTextInput;
    alert.tag = kPassphraseAlertTag;
    [alert show];
}

- (void)doEncryptWithPassphrase:(NSString *)passphrase
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Encrypting...";

    NSString *messageText = self.messageTextView.text;
    NSArray *recipientIDs = [NSArray arrayWithArray:self.selectedRecipientKeyIDs];
    NSString *signID = self.signingKeyID;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSString *ciphertext = [[OPPGPService sharedService] encryptMessage:messageText
                                                          forRecipientIDs:recipientIDs
                                                               signWithID:signID
                                                               passphrase:passphrase
                                                                    error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];

            if (error || !ciphertext) {
                NSString *msg = error ? [error localizedDescription] : @"Encryption failed.";
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Encryption Error"
                                                                message:msg
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
                return;
            }

            // Cache passphrase on success
            if (passphrase && signID) {
                [[OPPassphraseCache sharedCache] cachePassphrase:passphrase forKeyID:signID];
            }

            // Share the ciphertext
            UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[ciphertext]
                                                                                  applicationActivities:nil];
            [self presentViewController:activity animated:YES completion:nil];
        });
    });
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == kSigningKeyActionSheetTag) {
        if (buttonIndex == actionSheet.cancelButtonIndex) {
            return;
        }

        if (buttonIndex == 0) {
            // None
            self.signingKeyID = nil;
        } else {
            NSInteger keyIndex = buttonIndex - 1;
            if (keyIndex >= 0 && keyIndex < (NSInteger)[self.secretKeys count]) {
                OPKey *key = self.secretKeys[keyIndex];
                self.signingKeyID = key.keyID;
            }
        }

        [self updateSignAsDisplay];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kPassphraseAlertTag) {
        if (buttonIndex == 1) {
            NSString *passphrase = [alertView textFieldAtIndex:0].text;
            [self doEncryptWithPassphrase:passphrase];
        }
    }
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return YES;
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    CGRect keyboardFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];

    CGFloat keyboardHeight = keyboardFrame.size.height;
    CGRect textViewFrame = self.messageTextView.frame;
    CGFloat maxBottom = self.view.bounds.size.height - keyboardHeight - 10;
    CGFloat newHeight = maxBottom - textViewFrame.origin.y;

    if (newHeight < 80) {
        newHeight = 80;
    }

    [UIView animateWithDuration:duration animations:^{
        CGRect frame = self.messageTextView.frame;
        frame.size.height = newHeight;
        self.messageTextView.frame = frame;
        self.encryptButton.hidden = YES;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    CGFloat duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];

    [UIView animateWithDuration:duration animations:^{
        CGRect frame = self.messageTextView.frame;
        frame.size.height = 336;
        self.messageTextView.frame = frame;
        self.encryptButton.hidden = NO;
    }];
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
// onlypgp-wip
