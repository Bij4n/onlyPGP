//
//  OPQRScanViewController.h
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZBarSDK.h"

@interface OPQRScanViewController : UIViewController <ZBarReaderViewDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UIView *cameraContainerView;
@property (nonatomic, strong) IBOutlet UILabel *statusLabel;
@property (nonatomic, strong) IBOutlet UIProgressView *progressView;

@end
