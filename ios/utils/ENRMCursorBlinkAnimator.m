#import "ENRMCursorBlinkAnimator.h"
#import <QuartzCore/QuartzCore.h>
#include <TargetConditionals.h>

// Ease-in-out infinite blink, opacity 0 → kCursorMaxAlpha → 0. The peak is
// capped below 1 so the cursor reads as subtle rather than fully opaque.
static const NSTimeInterval kCursorPeriod = 1.6;
static const double kCursorMaxAlpha = 0.85;

@implementation ENRMCursorBlinkAnimator {
  __weak ENRMPlatformTextView *_textView;
#if !TARGET_OS_OSX
  CADisplayLink *_displayLink;
#endif
  NSRange _range;
  CFTimeInterval _startTime;
  RCTUIColor *_baseColor;
}

- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView
{
  self = [super init];
  if (self) {
    _textView = textView;
    _range = NSMakeRange(NSNotFound, 0);
  }
  return self;
}

- (void)dealloc
{
#if !TARGET_OS_OSX
  [_displayLink invalidate];
#endif
}

- (void)startWithRange:(NSRange)range
{
  ENRMPlatformTextView *tv = _textView;
  if (!tv)
    return;
  NSTextStorage *textStorage = tv.textStorage;
  if (!textStorage || range.length == 0 || range.location + range.length > textStorage.length)
    return;

  _range = range;
  _startTime = CACurrentMediaTime();

  NSDictionary *attrs = [textStorage attributesAtIndex:range.location effectiveRange:NULL];
  RCTUIColor *color = attrs[NSForegroundColorAttributeName];
#if !TARGET_OS_OSX
  _baseColor = color ?: [UIColor labelColor];
#else
  _baseColor = color ?: [NSColor textColor];
#endif

  // Start fully transparent so the cursor fades in from 0 — matches web's
  // 0% → 50% → 100% keyframes and avoids a one-frame flash at full opacity.
  CGFloat r = 0, g = 0, b = 0, a = 1;
  [_baseColor getRed:&r green:&g blue:&b alpha:&a];
  RCTUIColor *transparent = [RCTUIColor colorWithRed:r green:g blue:b alpha:0];
  [textStorage addAttribute:NSForegroundColorAttributeName value:transparent range:range];

#if !TARGET_OS_OSX
  if (!_displayLink) {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
    _displayLink.preferredFramesPerSecond = 0; // adaptive
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
  }
#endif
}

- (void)stop
{
#if !TARGET_OS_OSX
  [_displayLink invalidate];
  _displayLink = nil;
#endif
  _range = NSMakeRange(NSNotFound, 0);
}

#if !TARGET_OS_OSX
- (void)step:(CADisplayLink *)__unused link
{
  ENRMPlatformTextView *tv = _textView;
  if (!tv) {
    [self stop];
    return;
  }
  NSTextStorage *textStorage = tv.textStorage;
  if (!textStorage || _range.location == NSNotFound) {
    [self stop];
    return;
  }
  NSRange clamped = NSIntersectionRange(_range, NSMakeRange(0, textStorage.length));
  if (clamped.length == 0) {
    [self stop];
    return;
  }

  CFTimeInterval elapsed = CACurrentMediaTime() - _startTime;
  double phase = fmod(elapsed / kCursorPeriod, 1.0);
  // Triangle wave 0 → 1 → 0, then smoothstep to approximate ease-in-out.
  double tri = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0;
  double alpha = tri * tri * (3.0 - 2.0 * tri) * kCursorMaxAlpha;

  CGFloat r = 0, g = 0, b = 0, a = 1;
  [_baseColor getRed:&r green:&g blue:&b alpha:&a];
  RCTUIColor *animated = [RCTUIColor colorWithRed:r green:g blue:b alpha:a * (CGFloat)alpha];

  [textStorage addAttribute:NSForegroundColorAttributeName value:animated range:clamped];
}
#endif

@end
