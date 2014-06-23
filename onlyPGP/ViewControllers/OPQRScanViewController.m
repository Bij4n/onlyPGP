//
//  OPQRScanViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPQRScanViewController.h"
#import "OPQRCodeChunker.h"
#import "OPPGPService.h"
#import "OPKeyStore.h"
#import "UIColor+OPAdditions.h"
#import "NSString+OPAdditions.h"

static const NSInteger kImportSuccessAlertTag = 300;
static const NSInteger kImportFailAlertTag = 301;

@interface OPQRScanViewController ()

@property (nonatomic, strong) ZBarReaderView *readerView;
@property (nonatomic, strong) OPQRCodeChunker *chunker;
@property (nonatomic, assign) BOOL isProcessing;
@property (nonatomic, assign) NSUInteger expectedChunks;
@property (nonatomic, assign) NSUInteger receivedChunks;

@end

@implementation OPQRScanViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Scan QR Code";

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                         target:self
                                                                                         action:@selector(cancelTapped:)];

    self.isProcessing = NO;
    self.expectedChunks = 0;
    self.receivedChunks = 0;

    // Configure status label
    self.statusLabel.text = @"Point camera at QR code";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont boldSystemFontOfSize:15.0];
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    self.statusLabel.numberOfLines = 2;

    // Configure progress view
    self.progressView.progress = 0.0;
    self.progressView.progressTintColor = [UIColor op_greenColor];
    self.progressView.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    self.progressView.hidden = YES;

    // Setup ZBar reader
    [self setupCamera];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.readerView start];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.readerView stop];
}

- (void)dealloc
{
    [self.readerView stop];
    self.readerView.readerDelegate = nil;
}

#pragma mark - Camera Setup

- (void)setupCamera
{
    self.readerView = [[ZBarReaderView alloc] init];
    self.readerView.readerDelegate = self;
    self.readerView.frame = self.cameraContainerView.bounds;
    self.readerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Configure scanner to only look for QR codes
    [self.readerView.scanner setSymbology:0 config:ZBAR_CFG_ENABLE to:0];
    [self.readerView.scanner setSymbology:ZBAR_QRCODE config:ZBAR_CFG_ENABLE to:1];

    self.readerView.tracksSymbols = YES;
    self.readerView.allowsPinchZoom = YES;

    [self.cameraContainerView insertSubview:self.readerView atIndex:0];

    // Add an overlay frame
    UIView *overlayView = [[UIView alloc] initWithFrame:self.cameraContainerView.bounds];
    overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlayView.userInteractionEnabled = NO;

    CGFloat inset = 40.0;
    CGFloat sideLength = MIN(self.cameraContainerView.bounds.size.width, self.cameraContainerView.bounds.size.height) - (inset * 2);
    CGFloat originX = (self.cameraContainerView.bounds.size.width - sideLength) / 2.0;
    CGFloat originY = (self.cameraContainerView.bounds.size.height - sideLength) / 2.0;

    UIView *frameView = [[UIView alloc] initWithFrame:CGRectMake(originX, originY, sideLength, sideLength)];
    frameView.layer.borderColor = [[UIColor whiteColor] CGColor];
    frameView.layer.borderWidth = 2.0;
    frameView.layer.cornerRadius = 8.0;
    frameView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
                                | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [overlayView addSubview:frameView];

    [self.cameraContainerView addSubview:overlayView];
}

#pragma mark - Actions

- (void)cancelTapped:(id)sender
{
    [self.readerView stop];

    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - ZBarReaderViewDelegate

- (void)readerView:(ZBarReaderView *)readerView didReadSymbols:(ZBarSymbolSet *)symbols fromImage:(UIImage *)image
{
    if (self.isProcessing) return;

    for (ZBarSymbol *symbol in symbols) {
        NSString *data = symbol.data;
        if (!data || [data length] == 0) continue;

        [self processScannedData:data];
        break;
    }
}

- (void)processScannedData:(NSString *)data
{
    // Check if this is a single complete key (not chunked)
    if ([data op_isArmoredPGPBlock]) {
        self.isProcessing = YES;
        [self.readerView stop];
        [self importArmoredKey:data];
        return;
    }

    // Handle chunked QR data
    // Expected format: chunk data includes metadata about total chunks
    if (!self.chunker) {
        // Try to detect chunk format and create chunker
        // First chunk should tell us total expected count
        // We start with a reasonable default and adjust
        self.chunker = [[OPQRCodeChunker alloc] initWithExpectedChunkCount:0];
    }

    BOOL added = [self.chunker addChunkString:data];

    if (added) {
        self.receivedChunks++;
        self.expectedChunks = self.chunker.expectedChunkCount;

        // Update UI
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.hidden = NO;

            if (self.expectedChunks > 0) {
                float progress = (float)self.receivedChunks / (float)self.expectedChunks;
                self.progressView.progress = progress;
                self.statusLabel.text = [NSString stringWithFormat:@"Scanning chunk %lu of %lu",
                                         (unsigned long)self.receivedChunks,
                                         (unsigned long)self.expectedChunks];
            } else {
                self.statusLabel.text = [NSString stringWithFormat:@"Received %lu chunks...",
                                         (unsigned long)self.receivedChunks];
            }
        });

        // Check if complete
        if ([self.chunker isComplete]) {
            self.isProcessing = YES;
            [self.readerView stop];

            NSString *assembledKey = [self.chunker assembledArmoredKey];
            if (assembledKey) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.statusLabel.text = @"All chunks received! Importing...";
                    self.progressView.progress = 1.0;
                    [self importArmoredKey:assembledKey];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showAlertWithTitle:@"Error"
                                    message:@"Failed to assemble key from QR chunks."
                                        tag:kImportFailAlertTag];
                });
            }
        }
    }
}

#pragma mark - Import

- (void)importArmoredKey:(NSString *)armoredKey
{
    NSError *error = nil;
    OPKey *importedKey = [[OPPGPService sharedService] importKeyFromArmoredString:armoredKey error:&error];

    if (error || !importedKey) {
        NSString *message = [error localizedDescription];
        if (!message) {
            message = @"Could not import the scanned key.";
        }
        [self showAlertWithTitle:@"Import Failed" message:message tag:kImportFailAlertTag];
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"OPKeyringDidChangeNotification" object:nil];

    NSString *primaryName = importedKey.primaryUserID ? importedKey.primaryUserID : importedKey.shortKeyID;
    NSString *message = [NSString stringWithFormat:@"Successfully imported key for %@.", primaryName];
    [self showAlertWithTitle:@"Import Successful" message:message tag:kImportSuccessAlertTag];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kImportSuccessAlertTag) {
        if (self.navigationController) {
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    } else if (alertView.tag == kImportFailAlertTag) {
        // Reset and allow rescanning
        self.isProcessing = NO;
        self.chunker = nil;
        self.receivedChunks = 0;
        self.expectedChunks = 0;
        self.progressView.progress = 0.0;
        self.progressView.hidden = YES;
        self.statusLabel.text = @"Point camera at QR code";
        [self.readerView start];
    }
}

#pragma mark - Helpers

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message tag:(NSInteger)tag
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil];
    alert.tag = tag;
    [alert show];
}

@end
// onlypgp-wip
