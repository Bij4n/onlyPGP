//
//  OPKeyserverSearchViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OPKeyserverSearchViewController : UIViewController <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UILabel *noResultsLabel;

@end
