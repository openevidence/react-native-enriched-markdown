#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMTailFadeInAnimator : NSObject

- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView;

/// Start a fade-in for a new tail range. Call AFTER setting attributed text.
- (void)animateFrom:(NSUInteger)tailStart to:(NSUInteger)tailEnd;

/// Cancel all animations, removing the overlay.
- (void)cancel;

/// Whether there are active animations that need drawing.
@property (nonatomic, readonly) BOOL hasActiveAnimations;

/// Draw the fade overlay on top of text. Call from drawRect: after super.
- (void)drawOverlayInRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END
