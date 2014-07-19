//
//  OPKeyListViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPKeyListViewController.h"
#import "OPKeyDetailViewController.h"
#import "OPKeyGenViewController.h"
#import "OPImportViewController.h"
#import "OPKeyserverSearchViewController.h"
#import "OPOnboardingViewController.h"
#import "OPKey.h"
#import "OPUserID.h"
#import "OPKeyStore.h"
#import "OPTrustCalculator.h"
#import "UIColor+OPAdditions.h"
#import "NSDate+OPAdditions.h"

static NSString * const kCellIdentifier = @"OPKeyCell";
static NSString * const kHasCompletedOnboarding = @"hasCompletedOnboarding";

enum {
    kActionSheetGenerateKey = 0,
    kActionSheetImportClipboard,
    kActionSheetSearchKeyserver
};

@interface OPKeyListViewController ()

@property (nonatomic, strong) NSArray *keys;
@property (nonatomic, strong) NSArray *filteredKeys;
@property (nonatomic, assign) BOOL isSearching;

@end

@implementation OPKeyListViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"onlyPGP";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                          target:self
                                                                                          action:@selector(addButtonTapped:)];

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellIdentifier];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshKeyring:) forControlEvents:UIControlEventValueChanged];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search keys...";
    self.tableView.tableHeaderView = self.searchBar;

    self.emptyStateLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 280, 100)];
    self.emptyStateLabel.text = @"No keys yet.\nTap + to get started.";
    self.emptyStateLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyStateLabel.numberOfLines = 0;
    self.emptyStateLabel.font = [UIFont systemFontOfSize:17.0];
    self.emptyStateLabel.textColor = [UIColor grayColor];
    self.emptyStateLabel.hidden = YES;
    self.emptyStateLabel.center = self.tableView.center;
    self.emptyStateLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
                                          | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

    self.isSearching = NO;
    self.filteredKeys = @[];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyringDidChange:)
                                                 name:@"OPKeyringDidChangeNotification"
                                               object:nil];

    [self reloadKeys];

    BOOL hasCompleted = [[NSUserDefaults standardUserDefaults] boolForKey:kHasCompletedOnboarding];
    if (!hasCompleted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OPOnboardingViewController *onboarding = [[OPOnboardingViewController alloc] initWithNibName:@"OPOnboardingViewController" bundle:nil];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:onboarding];
            [self presentViewController:nav animated:YES completion:nil];
        });
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadKeys];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Data

- (void)reloadKeys
{
    self.keys = [[OPKeyStore sharedStore] allKeys];
    [self updateEmptyState];
    [self.tableView reloadData];
}

- (void)updateEmptyState
{
    if ([self.keys count] == 0 && !self.isSearching) {
        self.emptyStateLabel.hidden = NO;
        self.tableView.backgroundView = self.emptyStateLabel;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    } else {
        self.emptyStateLabel.hidden = YES;
        self.tableView.backgroundView = nil;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
}

- (NSArray *)currentKeys
{
    if (self.isSearching) {
        return self.filteredKeys;
    }
    return self.keys;
}

#pragma mark - Actions

- (void)addButtonTapped:(id)sender
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Add Key"
                                                      delegate:self
                                             cancelButtonTitle:@"Cancel"
                                        destructiveButtonTitle:nil
                                             otherButtonTitles:@"Generate Key", @"Import from Clipboard", @"Search Keyserver", nil];
    [sheet showInView:self.view];
}

- (void)refreshKeyring:(UIRefreshControl *)refreshControl
{
    [self reloadKeys];
    [refreshControl endRefreshing];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }

    switch (buttonIndex) {
        case kActionSheetGenerateKey: {
            OPKeyGenViewController *genVC = [[OPKeyGenViewController alloc] initWithNibName:@"OPKeyGenViewController" bundle:nil];
            [self.navigationController pushViewController:genVC animated:YES];
            break;
        }
        case kActionSheetImportClipboard: {
            OPImportViewController *importVC = [[OPImportViewController alloc] initWithNibName:@"OPImportViewController" bundle:nil];
            [self.navigationController pushViewController:importVC animated:YES];
            break;
        }
        case kActionSheetSearchKeyserver: {
            OPKeyserverSearchViewController *searchVC = [[OPKeyserverSearchViewController alloc] initWithNibName:@"OPKeyserverSearchViewController" bundle:nil];
            [self.navigationController pushViewController:searchVC animated:YES];
            break;
        }
        default:
            break;
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if ([searchText length] == 0) {
        self.isSearching = NO;
        self.filteredKeys = @[];
    } else {
        self.isSearching = YES;
        self.filteredKeys = [[OPKeyStore sharedStore] searchKeysWithQuery:searchText];
    }
    [self updateEmptyState];
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = @"";
    self.isSearching = NO;
    self.filteredKeys = @[];
    [searchBar resignFirstResponder];
    [self updateEmptyState];
    [self.tableView reloadData];
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
    return [[self currentKeys] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];

    OPKey *key = [self currentKeys][indexPath.row];

    for (UIView *sub in cell.contentView.subviews) {
        if (sub.tag >= 100) {
            [sub removeFromSuperview];
        }
    }

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    // Name and email
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 4, 230, 20)];
    nameLabel.tag = 100;
    nameLabel.font = [UIFont boldSystemFontOfSize:15.0];
    nameLabel.textColor = [UIColor blackColor];

    OPUserID *primaryUID = nil;
    for (OPUserID *uid in key.userIDs) {
        if (uid.isPrimary) {
            primaryUID = uid;
            break;
        }
    }
    if (!primaryUID && [key.userIDs count] > 0) {
        primaryUID = key.userIDs[0];
    }

    if (primaryUID) {
        nameLabel.text = primaryUID.name;
    } else {
        nameLabel.text = key.primaryUserID;
    }
    [cell.contentView addSubview:nameLabel];

    // Email
    UILabel *emailLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 24, 230, 16)];
    emailLabel.tag = 101;
    emailLabel.font = [UIFont systemFontOfSize:12.0];
    emailLabel.textColor = [UIColor grayColor];
    emailLabel.text = primaryUID.email ? primaryUID.email : @"";
    [cell.contentView addSubview:emailLabel];

    // Key ID and info
    UILabel *keyInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 42, 230, 14)];
    keyInfoLabel.tag = 102;
    keyInfoLabel.font = [UIFont systemFontOfSize:11.0];
    keyInfoLabel.textColor = [UIColor darkGrayColor];
    keyInfoLabel.text = [NSString stringWithFormat:@"%@ %@ %@", key.shortKeyID, key.algorithmName, @(key.keySize)];
    [cell.contentView addSubview:keyInfoLabel];

    // Trust badge
    UIView *trustBadge = [[UIView alloc] initWithFrame:CGRectMake(10, 16, 20, 20)];
    trustBadge.tag = 103;
    trustBadge.layer.cornerRadius = 10.0;
    trustBadge.layer.masksToBounds = YES;
    UIColor *trustColor = [[OPTrustCalculator sharedCalculator] trustLevelColor:key];
    trustBadge.backgroundColor = trustColor ? trustColor : [UIColor lightGrayColor];
    [cell.contentView addSubview:trustBadge];

    // Lock icon for secret keys
    if (key.isSecretKey) {
        UILabel *lockLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 18, 16, 16)];
        lockLabel.tag = 104;
        lockLabel.text = @"\xF0\x9F\x94\x92";
        lockLabel.font = [UIFont systemFontOfSize:10.0];
        lockLabel.textAlignment = NSTextAlignmentCenter;
        [cell.contentView addSubview:lockLabel];
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 64.0;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        OPKey *key = [self currentKeys][indexPath.row];
        [[OPKeyStore sharedStore] deleteKeyWithKeyID:key.keyID];
        [self reloadKeys];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    OPKey *key = [self currentKeys][indexPath.row];
    OPKeyDetailViewController *detailVC = [[OPKeyDetailViewController alloc] initWithNibName:@"OPKeyDetailViewController" bundle:nil];
    detailVC.key = key;
    [self.navigationController pushViewController:detailVC animated:YES];
}

#pragma mark - Notifications

- (void)keyringDidChange:(NSNotification *)notification
{
    [self reloadKeys];
}

#pragma mark - Scroll to dismiss keyboard

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.searchBar resignFirstResponder];
}

@end
