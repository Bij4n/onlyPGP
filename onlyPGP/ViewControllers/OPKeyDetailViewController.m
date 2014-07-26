//
//  OPKeyDetailViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPKeyDetailViewController.h"
#import "OPExportViewController.h"
#import "OPQRDisplayViewController.h"
#import "OPKey.h"
#import "OPUserID.h"
#import "OPSubkey.h"
#import "OPSignature.h"
#import "OPKeyStore.h"
#import "OPPGPService.h"
#import "OPTrustCalculator.h"
#import "UIColor+OPAdditions.h"
#import "NSDate+OPAdditions.h"

enum {
    kSectionKeyInfo = 0,
    kSectionUserIDs,
    kSectionSubkeys,
    kSectionSignatures,
    kSectionTrust,
    kSectionActions,
    kSectionCount
};

enum {
    kKeyInfoFingerprint = 0,
    kKeyInfoAlgorithm,
    kKeyInfoCreated,
    kKeyInfoExpires,
    kKeyInfoStatus,
    kKeyInfoRowCount
};

enum {
    kActionExportPublic = 0,
    kActionExportSecret,
    kActionShareQR,
    kActionDelete
};

static NSString * const kCellIdentifier = @"OPDetailCell";
static const NSInteger kDeleteAlertTag = 100;
static const NSInteger kTrustActionSheetTag = 200;

@interface OPKeyDetailViewController ()

@end

@implementation OPKeyDetailViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = self.key.shortKeyID;

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellIdentifier];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyringDidChange:)
                                                 name:@"OPKeyringDidChangeNotification"
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyringDidChange:(NSNotification *)notification
{
    OPKey *refreshed = [[OPKeyStore sharedStore] keyWithKeyID:self.key.keyID];
    if (refreshed) {
        self.key = refreshed;
        [self.tableView reloadData];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Helpers

- (NSString *)formattedFingerprint
{
    NSString *fp = self.key.fingerprint;
    if (!fp) return @"";

    NSMutableString *formatted = [NSMutableString string];
    for (NSUInteger i = 0; i < [fp length]; i++) {
        if (i > 0 && i % 4 == 0) {
            [formatted appendString:@" "];
        }
        [formatted appendFormat:@"%C", [fp characterAtIndex:i]];
    }
    return [formatted copy];
}

- (NSString *)statusString
{
    if (self.key.isRevoked) {
        return @"Revoked";
    }
    if (self.key.isExpired) {
        return @"Expired";
    }
    return @"Valid";
}

- (UIColor *)statusColor
{
    if (self.key.isRevoked || self.key.isExpired) {
        return [UIColor op_redColor];
    }
    return [UIColor op_greenColor];
}

- (NSInteger)numberOfActionRows
{
    NSInteger count = 2; // Export Public + Delete
    if (self.key.isSecretKey) {
        count++; // Export Secret
    }
    count++; // Share via QR
    return count;
}

- (NSInteger)actionIndexForRow:(NSInteger)row
{
    // Export Public is always 0
    if (row == 0) return kActionExportPublic;

    NSInteger currentRow = 1;

    if (self.key.isSecretKey) {
        if (row == currentRow) return kActionExportSecret;
        currentRow++;
    }

    if (row == currentRow) return kActionShareQR;
    currentRow++;

    if (row == currentRow) return kActionDelete;

    return -1;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case kSectionKeyInfo:     return @"Key Info";
        case kSectionUserIDs:     return @"User IDs";
        case kSectionSubkeys:     return @"Subkeys";
        case kSectionSignatures:  return @"Signatures";
        case kSectionTrust:       return @"Trust";
        case kSectionActions:     return @"Actions";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kSectionKeyInfo:
            return kKeyInfoRowCount;
        case kSectionUserIDs:
            return [self.key.userIDs count];
        case kSectionSubkeys:
            return [self.key.subkeys count];
        case kSectionSignatures:
            return [self.key.signatures count];
        case kSectionTrust:
            return 2; // current level + change button
        case kSectionActions:
            return [self numberOfActionRows];
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellIdentifier];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont systemFontOfSize:14.0];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14.0];

    switch (indexPath.section) {
        case kSectionKeyInfo:
            [self configureKeyInfoCell:cell atRow:indexPath.row];
            break;
        case kSectionUserIDs:
            [self configureUserIDCell:cell atRow:indexPath.row];
            break;
        case kSectionSubkeys:
            [self configureSubkeyCell:cell atRow:indexPath.row];
            break;
        case kSectionSignatures:
            [self configureSignatureCell:cell atRow:indexPath.row];
            break;
        case kSectionTrust:
            [self configureTrustCell:cell atRow:indexPath.row];
            break;
        case kSectionActions:
            [self configureActionCell:cell atRow:indexPath.row];
            break;
        default:
            break;
    }

    return cell;
}

- (void)configureKeyInfoCell:(UITableViewCell *)cell atRow:(NSInteger)row
{
    switch (row) {
        case kKeyInfoFingerprint:
            cell.textLabel.text = @"Fingerprint";
            cell.detailTextLabel.text = [self formattedFingerprint];
            cell.detailTextLabel.font = [UIFont fontWithName:@"Courier" size:11.0];
            cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
            cell.detailTextLabel.minimumScaleFactor = 0.7;
            break;
        case kKeyInfoAlgorithm:
            cell.textLabel.text = @"Algorithm";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %lu-bit", self.key.algorithmName, (unsigned long)self.key.keySize];
            break;
        case kKeyInfoCreated:
            cell.textLabel.text = @"Created";
            cell.detailTextLabel.text = [self.key.creationDate op_shortDateString];
            break;
        case kKeyInfoExpires:
            cell.textLabel.text = @"Expires";
            cell.detailTextLabel.text = self.key.expirationDate ? [self.key.expirationDate op_shortDateString] : @"Never";
            break;
        case kKeyInfoStatus:
            cell.textLabel.text = @"Status";
            cell.detailTextLabel.text = [self statusString];
            cell.detailTextLabel.textColor = [self statusColor];
            break;
        default:
            break;
    }
}

- (void)configureUserIDCell:(UITableViewCell *)cell atRow:(NSInteger)row
{
    OPUserID *uid = self.key.userIDs[row];
    cell.textLabel.text = uid.userIDString;
    cell.textLabel.font = [UIFont systemFontOfSize:13.0];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.text = nil;

    if (uid.isPrimary) {
        cell.textLabel.font = [UIFont boldSystemFontOfSize:13.0];
    }
}

- (void)configureSubkeyCell:(UITableViewCell *)cell atRow:(NSInteger)row
{
    OPSubkey *subkey = self.key.subkeys[row];

    NSMutableArray *caps = [NSMutableArray array];
    if (subkey.canSign) [caps addObject:@"Sign"];
    if (subkey.canEncrypt) [caps addObject:@"Encrypt"];
    NSString *capsStr = [caps count] > 0 ? [caps componentsJoinedByString:@", "] : @"None";

    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@ %lu", subkey.keyID, subkey.algorithmName, (unsigned long)subkey.keySize];
    cell.textLabel.font = [UIFont systemFontOfSize:12.0];
    cell.detailTextLabel.text = capsStr;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];

    if (subkey.isExpired) {
        cell.textLabel.textColor = [UIColor op_redColor];
    }
}

- (void)configureSignatureCell:(UITableViewCell *)cell atRow:(NSInteger)row
{
    OPSignature *sig = self.key.signatures[row];
    cell.textLabel.text = [NSString stringWithFormat:@"Signer: %@", sig.signerKeyID];
    cell.textLabel.font = [UIFont systemFontOfSize:12.0];

    NSString *dateStr = sig.creationDate ? [sig.creationDate op_shortDateString] : @"Unknown";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", sig.signatureTypeName, dateStr];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11.0];
}

- (void)configureTrustCell:(UITableViewCell *)cell atRow:(NSInteger)row
{
    OPTrustCalculator *calc = [OPTrustCalculator sharedCalculator];

    if (row == 0) {
        cell.textLabel.text = @"Trust Level";
        cell.detailTextLabel.text = [calc trustLevelString:self.key];
        cell.detailTextLabel.textColor = [calc trustLevelColor:self.key];
    } else {
        cell.textLabel.text = @"Change Trust Level";
        cell.textLabel.textColor = [UIColor op_tintColor];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
}

- (void)configureActionCell:(UITableViewCell *)cell atRow:(NSInteger)row
{
    NSInteger action = [self actionIndexForRow:row];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    switch (action) {
        case kActionExportPublic:
            cell.textLabel.text = @"Export Public Key";
            cell.textLabel.textColor = [UIColor op_tintColor];
            break;
        case kActionExportSecret:
            cell.textLabel.text = @"Export Secret Key";
            cell.textLabel.textColor = [UIColor op_tintColor];
            break;
        case kActionShareQR:
            cell.textLabel.text = @"Share via QR Code";
            cell.textLabel.textColor = [UIColor op_tintColor];
            break;
        case kActionDelete:
            cell.textLabel.text = @"Delete Key";
            cell.textLabel.textColor = [UIColor op_redColor];
            break;
        default:
            break;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == kSectionTrust && indexPath.row == 1) {
        [self showTrustActionSheet];
        return;
    }

    if (indexPath.section == kSectionActions) {
        NSInteger action = [self actionIndexForRow:indexPath.row];
        [self handleAction:action];
    }

    if (indexPath.section == kSectionKeyInfo && indexPath.row == kKeyInfoFingerprint) {
        [[UIPasteboard generalPasteboard] setString:self.key.fingerprint];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Copied"
                                                        message:@"Fingerprint copied to clipboard."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kSectionUserIDs) {
        return 50.0;
    }
    return 44.0;
}

#pragma mark - Actions

- (void)handleAction:(NSInteger)action
{
    switch (action) {
        case kActionExportPublic:
            [self exportPublicKey];
            break;
        case kActionExportSecret:
            [self exportSecretKey];
            break;
        case kActionShareQR:
            [self shareViaQR];
            break;
        case kActionDelete:
            [self confirmDeleteKey];
            break;
        default:
            break;
    }
}

- (void)exportPublicKey
{
    NSError *error = nil;
    NSString *armored = [[OPPGPService sharedService] exportArmoredPublicKeyForKeyID:self.key.keyID error:&error];

    if (error || !armored) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Export Failed"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    OPExportViewController *exportVC = [[OPExportViewController alloc] initWithNibName:@"OPExportViewController" bundle:nil];
    exportVC.key = self.key;
    exportVC.exportSecret = NO;
    [self.navigationController pushViewController:exportVC animated:YES];
}

- (void)exportSecretKey
{
    NSError *error = nil;
    NSString *armored = [[OPPGPService sharedService] exportArmoredSecretKeyForKeyID:self.key.keyID error:&error];

    if (error || !armored) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Export Failed"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    OPExportViewController *exportVC = [[OPExportViewController alloc] initWithNibName:@"OPExportViewController" bundle:nil];
    exportVC.key = self.key;
    exportVC.exportSecret = YES;
    [self.navigationController pushViewController:exportVC animated:YES];
}

- (void)shareViaQR
{
    OPQRDisplayViewController *qrVC = [[OPQRDisplayViewController alloc] initWithNibName:@"OPQRDisplayViewController" bundle:nil];
    qrVC.key = self.key;
    [self.navigationController pushViewController:qrVC animated:YES];
}

- (void)confirmDeleteKey
{
    NSString *message = [NSString stringWithFormat:@"Are you sure you want to delete the key %@? This cannot be undone.", self.key.shortKeyID];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Delete Key"
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                         otherButtonTitles:@"Delete", nil];
    alert.tag = kDeleteAlertTag;
    [alert show];
}

- (void)showTrustActionSheet
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Set Trust Level"
                                                      delegate:self
                                             cancelButtonTitle:@"Cancel"
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:@"Unknown", @"Never Trust", @"Marginally Trusted", @"Fully Trusted", @"Ultimately Trusted", nil];
    sheet.tag = kTrustActionSheetTag;
    [sheet showInView:self.view];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kDeleteAlertTag && buttonIndex == 1) {
        [[OPKeyStore sharedStore] deleteKeyWithKeyID:self.key.keyID];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"OPKeyringDidChangeNotification" object:nil];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == kTrustActionSheetTag) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;

        NSArray *trustValues = @[@"unknown", @"never", @"marginal", @"full", @"ultimate"];
        if (buttonIndex < (NSInteger)[trustValues count]) {
            self.key.ownerTrust = trustValues[buttonIndex];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"OPKeyringDidChangeNotification" object:nil];
            [self.tableView reloadData];
        }
    }
}

@end
