//
//  AppDelegate.m
//  onlyPGP
//
//  Created in 2014.
//  Copyright (c) 2014 onlyPGP contributors. All rights reserved.
//

#import "AppDelegate.h"
#import "OPKeyListViewController.h"
#import "OPKeyStore.h"
#import "OPPGPService.h"
#import "UIColor+OPAdditions.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Set up the key list as root view controller
    OPKeyListViewController *keyListVC = [[OPKeyListViewController alloc] initWithStyle:UITableViewStylePlain];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:keyListVC];
    self.navigationController.navigationBar.tintColor = [UIColor op_tintColor];

    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];

    // Initialize database
    [[OPKeyStore sharedStore] setupDatabase];

    // Load existing keys into PGP service
    [[OPPGPService sharedService] loadKeysFromStore];

    // iTunes File Sharing is enabled via UIFileSharingEnabled in Info.plist.
    // Users can transfer .asc key files through iTunes.

    // Register for memory warnings to clear passphrase cache
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveMemoryWarning:)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];

    return YES;
}

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    [[OPPGPService sharedService] clearPassphraseCache];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Clear sensitive passphrase data from memory when backgrounded
    [[OPPGPService sharedService] clearPassphraseCache];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Close the database cleanly
    [[OPKeyStore sharedStore] closeDatabase];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
// onlypgp-wip
