//
//  OPKeyserverSearchViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPKeyserverSearchViewController.h"
#import "OPKey.h"
#import "OPKeyStore.h"
#import "OPKeyserverClient.h"
#import "OPPGPService.h"
#import "UIColor+OPTheme.h"
#import "MBProgressHUD.h"
#import "Reachability.h"

static NSString * const kSearchResultCellIdentifier = @"SearchResultCell";

@interface OPKeyserverSearchViewController ()

@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) BOOL hasSearched;
@property (nonatomic, strong) OPKey *selectedKey;

@end

@implementation OPKeyserverSearchViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Search Keyservers";

    self.searchResults = @[];
    self.isSearching = NO;
    self.hasSearched = NO;

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kSearchResultCellIdentifier];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

    self.noResultsLabel.hidden = YES;

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                         target:self
                                                                                         action:@selector(cancelTapped)];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.searchBar becomeFirstResponder];
}

#pragma mark - Actions

- (void)cancelTapped
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Network Check

- (BOOL)isNetworkAvailable
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus status = [reachability currentReachabilityStatus];
    return (status != NotReachable);
}

#pragma mark - Search

- (void)performSearchWithQuery:(NSString *)query
{
    if ([query length] == 0) {
        return;
    }

    if (![self isNetworkAvailable]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Connection"
                                                        message:@"An internet connection is required to search keyservers."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    self.isSearching = YES;
    self.noResultsLabel.hidden = YES;

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Searching...";

    __weak typeof(self) weakSelf = self;
    [[OPKeyserverClient sharedClient] searchForQuery:query completion:^(NSArray *results, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            [MBProgressHUD hideHUDForView:strongSelf.view animated:YES];
            strongSelf.isSearching = NO;
            strongSelf.hasSearched = YES;

            if (error) {
                strongSelf.searchResults = @[];
                [strongSelf.tableView reloadData];
                [strongSelf showErrorAlertWithMessage:[error localizedDescription]];
                [strongSelf updateNoResultsLabel];
                return;
            }

            strongSelf.searchResults = results ?: @[];
            [strongSelf.tableView reloadData];
            [strongSelf updateNoResultsLabel];
        });
    }];
}

- (void)updateNoResultsLabel
{
    BOOL showNoResults = self.hasSearched && [self.searchResults count] == 0 && !self.isSearching;
    self.noResultsLabel.hidden = !showNoResults;
}

- (void)showErrorAlertWithMessage:(NSString *)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Search Error"
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Import Key

- (void)importKeyAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)[self.searchResults count]) {
        return;
    }

    OPKey *resultKey = self.searchResults[index];
    NSString *keyID = resultKey.keyID;

    if (!keyID) {
        return;
    }

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Fetching key...";

    __weak typeof(self) weakSelf = self;
    [[OPKeyserverClient sharedClient] fetchKeyWithID:keyID completion:^(NSString *armoredKey, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            [MBProgressHUD hideHUDForView:strongSelf.view animated:YES];

            if (error) {
                [strongSelf showErrorAlertWithMessage:[NSString stringWithFormat:@"Failed to fetch key: %@", [error localizedDescription]]];
                return;
            }

            if (!armoredKey || [armoredKey length] == 0) {
                [strongSelf showErrorAlertWithMessage:@"Empty key data received from server."];
                return;
            }

            NSError *importError = nil;
            BOOL success = [[OPPGPService sharedService] importKeyFromArmoredString:armoredKey error:&importError];

            if (success) {
                MBProgressHUD *successHUD = [MBProgressHUD showHUDAddedTo:strongSelf.view animated:YES];
                successHUD.mode = MBProgressHUDModeText;
                successHUD.labelText = @"Key Imported!";
                successHUD.detailsLabelText = resultKey.primaryUserID;
                [successHUD hide:YES afterDelay:2.0];

                [[NSNotificationCenter defaultCenter] postNotificationName:@"OPKeyringDidChangeNotification" object:nil];
            } else {
                NSString *msg = importError ? [importError localizedDescription] : @"Unknown error during import.";
                [strongSelf showErrorAlertWithMessage:msg];
            }
        });
    }];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self performSearchWithQuery:query];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    self.searchResults = @[];
    self.hasSearched = NO;
    [self.tableView reloadData];
    [self updateNoResultsLabel];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    searchBar.showsCancelButton = YES;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    searchBar.showsCancelButton = NO;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.searchResults count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kSearchResultCellIdentifier forIndexPath:indexPath];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kSearchResultCellIdentifier];
    }

    // Force subtitle style by recreating if needed
    if (cell.detailTextLabel == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kSearchResultCellIdentifier];
    }

    OPKey *resultKey = self.searchResults[indexPath.row];

    cell.textLabel.text = resultKey.primaryUserID ?: @"Unknown User";
    cell.textLabel.font = [UIFont systemFontOfSize:15.0];
    cell.textLabel.numberOfLines = 1;

    NSString *detailString = [NSString stringWithFormat:@"%@ | %@ %@",
                              resultKey.shortKeyID ?: resultKey.keyID ?: @"????",
                              @(resultKey.keySize),
                              resultKey.algorithmName ?: @""];
    cell.detailTextLabel.text = detailString;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
    cell.detailTextLabel.textColor = [UIColor op_grayColor];

    cell.accessoryType = UITableViewCellAccessoryNone;

    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    OPKey *resultKey = self.searchResults[indexPath.row];
    self.selectedKey = resultKey;

    NSString *message = [NSString stringWithFormat:@"%@\n\nKey ID: %@\nSize: %ld-bit %@",
                         resultKey.primaryUserID ?: @"Unknown User",
                         resultKey.shortKeyID ?: resultKey.keyID ?: @"Unknown",
                         (long)resultKey.keySize,
                         resultKey.algorithmName ?: @""];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Import this key?"
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Import", nil];
    alert.tag = 100;
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 100 && buttonIndex == 1) {
        NSInteger selectedIndex = [self.searchResults indexOfObject:self.selectedKey];
        if (selectedIndex != NSNotFound) {
            [self importKeyAtIndex:selectedIndex];
        }
    }
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
