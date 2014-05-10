//
//  OPKeyDetailViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>

@class OPKey;

@interface OPKeyDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) OPKey *key;
@property (nonatomic, strong) IBOutlet UITableView *tableView;

@end
