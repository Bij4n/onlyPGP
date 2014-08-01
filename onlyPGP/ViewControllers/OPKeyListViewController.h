//
//  OPKeyListViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OPKeyListViewController : UITableViewController <UISearchBarDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) IBOutlet UILabel *emptyStateLabel;

@end
