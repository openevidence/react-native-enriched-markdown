#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// Drives a fade in/out animation on the foreground color alpha of a single
/// character range inside a text view's text storage. Used to render the
/// trailing block cursor (▌) during streaming idle.
@interface ENRMCursorBlinkAnimator : NSObject

- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView;

/// Begin animating the foreground color alpha of `range`. The base color is
/// captured from the current attributes at the start of the range.
- (void)startWithRange:(NSRange)range;

/// Stop animating. Does not restore color or remove characters; callers are
/// expected to remove the cursor character when no longer needed.
- (void)stop;

@end

NS_ASSUME_NONNULL_END
