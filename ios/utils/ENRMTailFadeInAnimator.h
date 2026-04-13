#pragma once
#import "ENRMUIKit.h"
#import "LinkTapUtils.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMTailFadeInAnimator : NSObject

- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView;

- (void)animateFrom:(NSUInteger)tailStart to:(NSUInteger)tailEnd;
- (void)cancel;

/// Write all active groups' current alpha into an attributed string
/// BEFORE it is set on the text view.  This preserves animation continuity
/// when the entire text storage is replaced (text only grows).
- (void)preApplyToAttributedString:(NSMutableAttributedString *)attributedText;

@end

NS_ASSUME_NONNULL_END
