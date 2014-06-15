//
//  OPOnboardingViewController.m
//  onlyPGP
//
//  Created 2014. All rights reserved.
//

#import "OPOnboardingViewController.h"
#import "UIColor+OPTheme.h"

static NSString * const kHasCompletedOnboardingKey = @"hasCompletedOnboarding";

@interface OPOnboardingViewController ()

@property (nonatomic, assign) NSInteger pageCount;
@property (nonatomic, strong) UIButton *getStartedButton;
@property (nonatomic, strong) NSArray *pageTitles;
@property (nonatomic, strong) NSArray *pageSubtitles;
@property (nonatomic, strong) NSArray *pageIcons;

@end

@implementation OPOnboardingViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.pageCount = 3;
    self.view.backgroundColor = [UIColor whiteColor];

    self.pageTitles = @[
        @"Welcome to onlyPGP",
        @"Manage Your Keys",
        @"Encrypt Everything"
    ];

    self.pageSubtitles = @[
        @"Your PGP keys, on your iPhone.",
        @"Generate, import, and share OpenPGP keys.\nSearch keyservers to find friends.",
        @"Send encrypted messages that only\nthe recipient can read."
    ];

    // Unicode icons for each page
    self.pageIcons = @[
        @"\U0001F512",  // Lock
        @"\U0001F511",  // Key
        @"\U0001F6E1"   // Shield
    ];

    self.pageControl.numberOfPages = self.pageCount;
    self.pageControl.currentPage = 0;

    self.skipButton.tintColor = [UIColor op_grayColor];

    [self setupPages];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat pageWidth = self.scrollView.bounds.size.width;
    CGFloat contentWidth = pageWidth * self.pageCount;
    self.scrollView.contentSize = CGSizeMake(contentWidth, self.scrollView.bounds.size.height);

    // Reposition page subviews on layout changes
    [self repositionPages];
}

#pragma mark - Page Setup

- (void)setupPages
{
    CGFloat pageWidth = 320.0;
    CGFloat pageHeight = 520.0;

    for (NSInteger i = 0; i < self.pageCount; i++) {
        UIView *pageView = [[UIView alloc] initWithFrame:CGRectMake(i * pageWidth, 0, pageWidth, pageHeight)];
        pageView.tag = 1000 + i;
        pageView.backgroundColor = [UIColor clearColor];

        // Icon label
        UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, pageWidth, 100)];
        iconLabel.tag = 2000 + i;
        iconLabel.text = self.pageIcons[i];
        iconLabel.font = [UIFont systemFontOfSize:72];
        iconLabel.textAlignment = NSTextAlignmentCenter;
        [pageView addSubview:iconLabel];

        // Title label
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 220, pageWidth - 40, 36)];
        titleLabel.tag = 3000 + i;
        titleLabel.text = self.pageTitles[i];
        titleLabel.font = [UIFont boldSystemFontOfSize:26];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor = [UIColor darkTextColor];
        titleLabel.adjustsFontSizeToFitWidth = YES;
        [pageView addSubview:titleLabel];

        // Subtitle label
        UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, 268, pageWidth - 60, 60)];
        subtitleLabel.tag = 4000 + i;
        subtitleLabel.text = self.pageSubtitles[i];
        subtitleLabel.font = [UIFont systemFontOfSize:16];
        subtitleLabel.textAlignment = NSTextAlignmentCenter;
        subtitleLabel.textColor = [UIColor op_grayColor];
        subtitleLabel.numberOfLines = 0;
        [pageView addSubview:subtitleLabel];

        // "Get Started" button on last page
        if (i == self.pageCount - 1) {
            UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
            startButton.frame = CGRectMake(40, 370, pageWidth - 80, 48);
            startButton.backgroundColor = [UIColor op_tintColor];
            startButton.layer.cornerRadius = 8.0;
            [startButton setTitle:@"Get Started" forState:UIControlStateNormal];
            [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            startButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
            [startButton addTarget:self action:@selector(getStartedTapped:) forControlEvents:UIControlEventTouchUpInside];
            [pageView addSubview:startButton];
            self.getStartedButton = startButton;
        }

        [self.scrollView addSubview:pageView];
    }

    self.scrollView.contentSize = CGSizeMake(pageWidth * self.pageCount, pageHeight);
}

- (void)repositionPages
{
    CGFloat pageWidth = self.scrollView.bounds.size.width;
    CGFloat pageHeight = self.scrollView.bounds.size.height;

    for (NSInteger i = 0; i < self.pageCount; i++) {
        UIView *pageView = [self.scrollView viewWithTag:1000 + i];
        if (pageView) {
            pageView.frame = CGRectMake(i * pageWidth, 0, pageWidth, pageHeight);

            // Reposition icon
            UILabel *iconLabel = (UILabel *)[pageView viewWithTag:2000 + i];
            if (iconLabel) {
                iconLabel.frame = CGRectMake(0, pageHeight * 0.15, pageWidth, 100);
            }

            // Reposition title
            UILabel *titleLabel = (UILabel *)[pageView viewWithTag:3000 + i];
            if (titleLabel) {
                titleLabel.frame = CGRectMake(20, pageHeight * 0.40, pageWidth - 40, 36);
            }

            // Reposition subtitle
            UILabel *subtitleLabel = (UILabel *)[pageView viewWithTag:4000 + i];
            if (subtitleLabel) {
                subtitleLabel.frame = CGRectMake(30, pageHeight * 0.48, pageWidth - 60, 60);
            }

            // Reposition Get Started button
            if (i == self.pageCount - 1 && self.getStartedButton) {
                self.getStartedButton.frame = CGRectMake(40, pageHeight * 0.65, pageWidth - 80, 48);
            }
        }
    }

    self.scrollView.contentSize = CGSizeMake(pageWidth * self.pageCount, pageHeight);
}

#pragma mark - Actions

- (IBAction)skipTapped:(id)sender
{
    [self completeOnboarding];
}

- (IBAction)pageControlChanged:(id)sender
{
    NSInteger page = self.pageControl.currentPage;
    CGFloat pageWidth = self.scrollView.bounds.size.width;
    CGPoint offset = CGPointMake(page * pageWidth, 0);
    [self.scrollView setContentOffset:offset animated:YES];
}

- (void)getStartedTapped:(id)sender
{
    [self completeOnboarding];
}

#pragma mark - Onboarding Completion

- (void)completeOnboarding
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHasCompletedOnboardingKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Animate dismissal
    [UIView animateWithDuration:0.4
                     animations:^{
                         self.view.alpha = 0.0;
                         self.view.transform = CGAffineTransformMakeScale(1.1, 1.1);
                     }
                     completion:^(BOOL finished) {
                         [self dismissViewControllerAnimated:NO completion:nil];
                     }];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat pageWidth = scrollView.bounds.size.width;
    if (pageWidth <= 0) return;

    NSInteger page = (NSInteger)floor((scrollView.contentOffset.x - pageWidth / 2.0) / pageWidth) + 1;

    if (page < 0) page = 0;
    if (page >= self.pageCount) page = self.pageCount - 1;

    self.pageControl.currentPage = page;

    // Show/hide skip button on last page
    if (page == self.pageCount - 1) {
        [UIView animateWithDuration:0.2 animations:^{
            self.skipButton.alpha = 0.0;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.skipButton.alpha = 1.0;
        }];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    CGFloat pageWidth = scrollView.bounds.size.width;
    if (pageWidth <= 0) return;

    NSInteger page = (NSInteger)(scrollView.contentOffset.x / pageWidth);
    self.pageControl.currentPage = page;
}

#pragma mark - Status Bar

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
// onlypgp-wip
