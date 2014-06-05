//
//  OPPassphrasePrompt.h
//  onlyPGP
//
//  Created 2014. ARC enabled.
//

#import <UIKit/UIKit.h>

typedef void(^OPPassphrasePromptCompletion)(NSString *passphrase, BOOL cancelled);

@interface OPPassphrasePrompt : NSObject <UIAlertViewDelegate>

+ (void)promptForPassphraseWithTitle:(NSString *)title
                             message:(NSString *)message
                          completion:(OPPassphrasePromptCompletion)completion;

@property (nonatomic, copy) OPPassphrasePromptCompletion completionBlock;

@end
