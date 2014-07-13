//
//  OPPassphrasePrompt.m
//  onlyPGP
//
//  Created 2014. ARC enabled.
//

#import "OPPassphrasePrompt.h"

static OPPassphrasePrompt *sActivePrompt = nil;

@interface OPPassphrasePrompt ()

@property (nonatomic, strong) UIAlertView *alertView;

@end

@implementation OPPassphrasePrompt

+ (void)promptForPassphraseWithTitle:(NSString *)title
                             message:(NSString *)message
                          completion:(OPPassphrasePromptCompletion)completion
{
    OPPassphrasePrompt *prompt = [[OPPassphrasePrompt alloc] init];
    prompt.completionBlock = completion;

    /*
     * Store in a static variable so ARC does not deallocate
     * the prompt while the alert view is still displayed.
     */
    sActivePrompt = prompt;

    prompt.alertView = [[UIAlertView alloc] initWithTitle:title ? title : @"Passphrase"
                                                  message:message ? message : @"Enter your passphrase:"
                                                 delegate:prompt
                                        cancelButtonTitle:@"Cancel"
                                        otherButtonTitles:@"OK", nil];
    prompt.alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;

    UITextField *textField = [prompt.alertView textFieldAtIndex:0];
    textField.placeholder = @"Passphrase";
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;

    [prompt.alertView show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (self.completionBlock) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            self.completionBlock(nil, YES);
        } else {
            UITextField *textField = [alertView textFieldAtIndex:0];
            NSString *passphrase = textField.text ? textField.text : @"";
            self.completionBlock(passphrase, NO);
        }
    }

    /* Release the static reference so the prompt can be deallocated */
    sActivePrompt = nil;
}

@end
// onlypgp-wip
