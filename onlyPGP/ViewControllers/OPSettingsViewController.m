//
//  OPSettingsViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPSettingsViewController.h"
#import "OPKey.h"
#import "OPKeyStore.h"
#import "OPKeyserverClient.h"
#import "OPPassphraseCache.h"
#import "UIColor+OPTheme.h"
#import "MBProgressHUD.h"

static NSString * const kDefaultSigningKeyIDKey = @"defaultSigningKeyID";
static NSString * const kPassphraseCacheTimeoutKey = @"passphraseCacheTimeout";
static NSString * const kKeyserverURLKey = @"keyserverURL";
static NSString * const kDefaultKeyserverURL = @"pool.sks-keyservers.net";

static const NSInteger kSectionDefaultKey = 0;
static const NSInteger kSectionSecurity = 1;
static const NSInteger kSectionKeyserver = 2;
static const NSInteger kSectionData = 3;
static const NSInteger kSectionAbout = 4;
static const NSInteger kSectionCount = 5;

static const NSInteger kDefaultKeyActionSheetTag = 500;
static const NSInteger kTimeoutActionSheetTag = 501;
static const NSInteger kKeyserverAlertTag = 502;
static const NSInteger kWipeAlertTag = 503;

@interface OPSettingsViewController ()

@property (nonatomic, strong) NSString *defaultSigningKeyID;
@property (nonatomic, assign) NSTimeInterval cacheTimeout;
@property (nonatomic, strong) NSString *keyserverURL;
@property (nonatomic, strong) NSArray *secretKeys;
@property (nonatomic, strong) NSArray *timeoutOptions;
@property (nonatomic, strong) NSArray *timeoutLabels;

@end

@implementation OPSettingsViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Settings";

    self.timeoutOptions = @[@(0), @(60), @(300), @(900), @(1800), @(3600)];
    self.timeoutLabels = @[@"Never", @"1 minute", @"5 minutes", @"15 minutes", @"30 minutes", @"1 hour"];

    [self loadSettings];

    self.secretKeys = [[OPKeyStore sharedStore] allSecretKeys];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyringDidChange:)
                                                 name:@"OPKeyringDidChangeNotification"
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.secretKeys = [[OPKeyStore sharedStore] allSecretKeys];
    [self.tableView reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Settings Persistence

- (void)loadSettings
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    self.defaultSigningKeyID = [defaults objectForKey:kDefaultSigningKeyIDKey];

    NSNumber *timeoutNumber = [defaults objectForKey:kPassphraseCacheTimeoutKey];
    if (timeoutNumber) {
        self.cacheTimeout = [timeoutNumber doubleValue];
    } else {
        self.cacheTimeout = 300; // default 5 minutes
    }

    self.keyserverURL = [defaults objectForKey:kKeyserverURLKey];
    if (!self.keyserverURL || [self.keyserverURL length] == 0) {
        self.keyserverURL = kDefaultKeyserverURL;
    }
}

- (void)saveSettings
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (self.defaultSigningKeyID) {
        [defaults setObject:self.defaultSigningKeyID forKey:kDefaultSigningKeyIDKey];
    } else {
        [defaults removeObjectForKey:kDefaultSigningKeyIDKey];
    }

    [defaults setObject:@(self.cacheTimeout) forKey:kPassphraseCacheTimeoutKey];
    [defaults setObject:self.keyserverURL forKey:kKeyserverURLKey];

    [defaults synchronize];
}

#pragma mark - Notifications

- (void)keyringDidChange:(NSNotification *)notification
{
    self.secretKeys = [[OPKeyStore sharedStore] allSecretKeys];
    [self.tableView reloadData];
}

#pragma mark - Helpers

- (NSString *)currentTimeoutLabel
{
    for (NSUInteger i = 0; i < [self.timeoutOptions count]; i++) {
        NSTimeInterval option = [self.timeoutOptions[i] doubleValue];
        if (fabs(option - self.cacheTimeout) < 1.0) {
            return self.timeoutLabels[i];
        }
    }
    return [NSString stringWithFormat:@"%.0f seconds", self.cacheTimeout];
}

- (NSString *)defaultSigningKeyName
{
    if (!self.defaultSigningKeyID) {
        return @"None";
    }

    OPKey *key = [[OPKeyStore sharedStore] keyWithKeyID:self.defaultSigningKeyID];
    if (key) {
        return key.primaryUserID ?: key.shortKeyID ?: self.defaultSigningKeyID;
    }
    return self.defaultSigningKeyID;
}

- (NSString *)appVersionString
{
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [info objectForKey:@"CFBundleVersion"];

    if (version && build) {
        return [NSString stringWithFormat:@"%@ (%@)", version, build];
    } else if (version) {
        return version;
    }
    return @"1.0";
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kSectionDefaultKey: return 1;
        case kSectionSecurity:   return 2;
        case kSectionKeyserver:  return 1;
        case kSectionData:       return 1;
        case kSectionAbout:      return 1;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case kSectionDefaultKey: return @"Default Key";
        case kSectionSecurity:   return @"Security";
        case kSectionKeyserver:  return @"Keyserver";
        case kSectionData:       return @"Data";
        case kSectionAbout:      return @"About";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
    }

    cell.textLabel.textColor = [UIColor darkTextColor];
    cell.detailTextLabel.textColor = [UIColor op_grayColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    switch (indexPath.section) {
        case kSectionDefaultKey: {
            cell.textLabel.text = @"Signing Key";
            cell.detailTextLabel.text = [self defaultSigningKeyName];
            break;
        }
        case kSectionSecurity: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Cache Timeout";
                cell.detailTextLabel.text = [self currentTimeoutLabel];
            } else {
                cell.textLabel.text = @"Clear Passphrase Cache";
                cell.textLabel.textColor = [UIColor op_orangeColor];
                cell.detailTextLabel.text = @"";
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            break;
        }
        case kSectionKeyserver: {
            cell.textLabel.text = @"Server URL";
            cell.detailTextLabel.text = self.keyserverURL;
            break;
        }
        case kSectionData: {
            cell.textLabel.text = @"Wipe All Keys";
            cell.textLabel.textColor = [UIColor op_redColor];
            cell.detailTextLabel.text = @"";
            cell.accessoryType = UITableViewCellAccessoryNone;
            break;
        }
        case kSectionAbout: {
            cell.textLabel.text = @"onlyPGP";
            cell.detailTextLabel.text = [self appVersionString];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch (indexPath.section) {
        case kSectionDefaultKey: {
            [self showDefaultKeyPicker];
            break;
        }
        case kSectionSecurity: {
            if (indexPath.row == 0) {
                [self showTimeoutPicker];
            } else {
                [self clearPassphraseCache];
            }
            break;
        }
        case kSectionKeyserver: {
            [self showKeyserverURLEditor];
            break;
        }
        case kSectionData: {
            [self confirmWipeAllKeys];
            break;
        }
        case kSectionAbout: {
            break;
        }
    }
}

#pragma mark - Section Actions

- (void)showDefaultKeyPicker
{
    self.secretKeys = [[OPKeyStore sharedStore] allSecretKeys];

    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Default Signing Key"
                                                      delegate:self
                                             cancelButtonTitle:nil
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:nil];
    sheet.tag = kDefaultKeyActionSheetTag;

    [sheet addButtonWithTitle:@"None"];

    for (OPKey *key in self.secretKeys) {
        NSString *title = key.primaryUserID ?: key.shortKeyID ?: key.keyID;
        [sheet addButtonWithTitle:title];
    }

    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = [self.secretKeys count] + 1;

    [sheet showInView:self.view];
}

- (void)showTimeoutPicker
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Passphrase Cache Timeout"
                                                      delegate:self
                                             cancelButtonTitle:nil
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:nil];
    sheet.tag = kTimeoutActionSheetTag;

    for (NSString *label in self.timeoutLabels) {
        [sheet addButtonWithTitle:label];
    }

    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = [self.timeoutLabels count];

    [sheet showInView:self.view];
}

- (void)clearPassphraseCache
{
    [[OPPassphraseCache sharedCache] removeAllPassphrases];

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Cache Cleared";
    [hud hide:YES afterDelay:1.5];
}

- (void)showKeyserverURLEditor
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Keyserver URL"
                                                    message:@"Enter the HKP keyserver hostname:"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = kKeyserverAlertTag;

    UITextField *textField = [alert textFieldAtIndex:0];
    textField.text = self.keyserverURL;
    textField.placeholder = kDefaultKeyserverURL;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.keyboardType = UIKeyboardTypeURL;

    [alert show];
}

- (void)confirmWipeAllKeys
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Wipe All Keys"
                                                    message:@"This will permanently delete ALL keys from this device. This cannot be undone. Are you sure?"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Wipe All", nil];
    alert.tag = kWipeAlertTag;
    [alert show];
}

- (void)performWipeAllKeys
{
    [[OPKeyStore sharedStore] deleteAllKeys];
    [[OPPassphraseCache sharedCache] removeAllPassphrases];

    self.defaultSigningKeyID = nil;
    [self saveSettings];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"OPKeyringDidChangeNotification" object:nil];

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"All Keys Wiped";
    [hud hide:YES afterDelay:2.0];

    self.secretKeys = @[];
    [self.tableView reloadData];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }

    if (actionSheet.tag == kDefaultKeyActionSheetTag) {
        if (buttonIndex == 0) {
            self.defaultSigningKeyID = nil;
        } else {
            NSInteger keyIndex = buttonIndex - 1;
            if (keyIndex >= 0 && keyIndex < (NSInteger)[self.secretKeys count]) {
                OPKey *key = self.secretKeys[keyIndex];
                self.defaultSigningKeyID = key.keyID;
            }
        }
        [self saveSettings];
        [self.tableView reloadData];
    }
    else if (actionSheet.tag == kTimeoutActionSheetTag) {
        if (buttonIndex >= 0 && buttonIndex < (NSInteger)[self.timeoutOptions count]) {
            self.cacheTimeout = [self.timeoutOptions[buttonIndex] doubleValue];
            [self saveSettings];
            [self.tableView reloadData];
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kKeyserverAlertTag && buttonIndex == 1) {
        NSString *url = [[alertView textFieldAtIndex:0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([url length] > 0) {
            self.keyserverURL = url;
        } else {
            self.keyserverURL = kDefaultKeyserverURL;
        }
        [self saveSettings];
        [self.tableView reloadData];
    }
    else if (alertView.tag == kWipeAlertTag && buttonIndex == 1) {
        [self performWipeAllKeys];
    }
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
// onlypgp-wip
