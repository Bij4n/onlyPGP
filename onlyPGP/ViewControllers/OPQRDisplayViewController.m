//
//  OPQRDisplayViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPQRDisplayViewController.h"
#import "OPKey.h"
#import "OPQRCodeChunker.h"
#import "UIColor+OPTheme.h"

@interface OPQRDisplayViewController ()

@property (nonatomic, strong) NSArray *chunks;
@property (nonatomic, strong) NSArray *qrImages;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) NSTimer *autoAdvanceTimer;

@end

@implementation OPQRDisplayViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Share via QR";

    self.qrImageView.layer.borderColor = [[UIColor op_grayColor] CGColor];
    self.qrImageView.layer.borderWidth = 1.0;

    self.previousButton.tintColor = [UIColor op_tintColor];
    self.nextButton.tintColor = [UIColor op_tintColor];
    self.autoAdvanceSwitch.onTintColor = [UIColor op_tintColor];

    [self generateChunksAndImages];
    [self updateDisplay];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopAutoAdvanceTimer];
}

- (void)dealloc
{
    [self stopAutoAdvanceTimer];
}

#pragma mark - QR Code Generation

- (void)generateChunksAndImages
{
    NSString *armoredKey = self.key.armoredPublicKey;
    if (!armoredKey) {
        self.chunks = @[];
        self.qrImages = @[];
        return;
    }

    self.chunks = [OPQRCodeChunker chunksForArmoredKey:armoredKey maxChunkSize:1000];

    NSMutableArray *images = [NSMutableArray arrayWithCapacity:[self.chunks count]];
    for (NSString *chunk in self.chunks) {
        UIImage *qrImage = [self qrCodeImageForString:chunk size:250.0];
        if (qrImage) {
            [images addObject:qrImage];
        } else {
            [images addObject:[UIImage new]];
        }
    }

    self.qrImages = [NSArray arrayWithArray:images];
    self.currentIndex = 0;
}

- (UIImage *)qrCodeImageForString:(NSString *)string size:(CGFloat)size
{
    NSData *data = [string dataUsingEncoding:NSISOLatin1StringEncoding];
    if (!data) {
        data = [string dataUsingEncoding:NSUTF8StringEncoding];
    }
    if (!data) {
        return nil;
    }

    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:data forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];

    CIImage *ciImage = filter.outputImage;
    if (!ciImage) {
        return nil;
    }

    CGRect extent = ciImage.extent;
    if (CGRectIsEmpty(extent)) {
        return nil;
    }

    CGFloat scale = size / extent.size.width;
    CIImage *scaledImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];

    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:scaledImage fromRect:scaledImage.extent];
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);

    return uiImage;
}

#pragma mark - Display

- (void)updateDisplay
{
    NSInteger total = [self.qrImages count];

    if (total == 0) {
        self.qrImageView.image = nil;
        self.pageLabel.text = @"No QR data";
        self.previousButton.enabled = NO;
        self.nextButton.enabled = NO;
        return;
    }

    self.qrImageView.image = self.qrImages[self.currentIndex];
    self.pageLabel.text = [NSString stringWithFormat:@"Code %ld of %ld",
                           (long)(self.currentIndex + 1), (long)total];

    self.previousButton.enabled = (self.currentIndex > 0);
    self.nextButton.enabled = (self.currentIndex < total - 1);
}

#pragma mark - Actions

- (IBAction)previousTapped:(id)sender
{
    if (self.currentIndex > 0) {
        self.currentIndex--;
        [self updateDisplay];
    }
}

- (IBAction)nextTapped:(id)sender
{
    NSInteger total = [self.qrImages count];
    if (self.currentIndex < total - 1) {
        self.currentIndex++;
        [self updateDisplay];
    }
}

- (IBAction)autoAdvanceToggled:(id)sender
{
    UISwitch *sw = (UISwitch *)sender;
    if (sw.isOn) {
        [self startAutoAdvanceTimer];
    } else {
        [self stopAutoAdvanceTimer];
    }
}

#pragma mark - Auto-Advance Timer

- (void)startAutoAdvanceTimer
{
    [self stopAutoAdvanceTimer];

    self.autoAdvanceTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                            target:self
                                                          selector:@selector(autoAdvanceFired:)
                                                          userInfo:nil
                                                           repeats:YES];
}

- (void)stopAutoAdvanceTimer
{
    if (self.autoAdvanceTimer) {
        [self.autoAdvanceTimer invalidate];
        self.autoAdvanceTimer = nil;
    }
}

- (void)autoAdvanceFired:(NSTimer *)timer
{
    NSInteger total = [self.qrImages count];
    if (total == 0) {
        [self stopAutoAdvanceTimer];
        return;
    }

    self.currentIndex++;
    if (self.currentIndex >= total) {
        self.currentIndex = 0;
    }
    [self updateDisplay];
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
// onlypgp-wip
