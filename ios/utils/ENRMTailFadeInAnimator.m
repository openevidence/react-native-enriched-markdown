#import "ENRMTailFadeInAnimator.h"
#import <QuartzCore/QuartzCore.h>
#include <TargetConditionals.h>

static const NSTimeInterval kFadeDuration = 0.60;

/// Lightweight data for one chunk of text being faded in.
@interface ENRMOverlayFadeGroup : NSObject {
@public
  NSUInteger tailStart;
  NSUInteger tailEnd;
  CFTimeInterval startTime;
}
@end

@implementation ENRMOverlayFadeGroup
@end

#pragma mark - Overlay view

/// Transparent view drawn on top of the text view. Its drawRect: paints
/// background-colored rectangles over new text that fade from opaque to
/// transparent, revealing the text underneath.
@interface ENRMFadeOverlayView : RCTUIView
@property (nonatomic, weak) ENRMPlatformTextView *textView;
@property (nonatomic, strong) NSMutableArray<ENRMOverlayFadeGroup *> *groups;
@end

@implementation ENRMFadeOverlayView

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.opaque = NO;
    self.backgroundColor = [RCTUIColor clearColor];
#if !TARGET_OS_OSX
    self.userInteractionEnabled = NO;
#endif
    _groups = [NSMutableArray array];
  }
  return self;
}

/// Resolves the background color by walking up the view hierarchy.
- (RCTUIColor *)resolveBackgroundColor
{
#if !TARGET_OS_OSX
  for (UIView *view = self.superview; view; view = view.superview) {
    UIColor *color = view.backgroundColor;
    if (color) {
      CGFloat alpha = 0;
      [color getRed:NULL green:NULL blue:NULL alpha:&alpha];
      if (alpha > 0)
        return color;
    }
  }
  return [UIColor whiteColor];
#else
  for (NSView *view = self.superview; view; view = view.superview) {
    CGColorRef color = view.layer.backgroundColor;
    if (color && CGColorGetAlpha(color) > 0)
      return [RCTUIColor colorWithCGColor:color];
  }
  return [RCTUIColor whiteColor];
#endif
}

- (void)drawRect:(CGRect)rect
{
  if (_groups.count == 0)
    return;

  ENRMPlatformTextView *tv = _textView;
  if (!tv)
    return;

  NSLayoutManager *layoutManager = tv.layoutManager;
  NSTextContainer *textContainer = tv.textContainer;
  NSTextStorage *textStorage = tv.textStorage;
  if (!layoutManager || !textContainer || !textStorage || textStorage.length == 0)
    return;

  CGContextRef ctx = UIGraphicsGetCurrentContext();
  if (!ctx)
    return;

  RCTUIColor *bgColor = [self resolveBackgroundColor];
  CFTimeInterval now = CACurrentMediaTime();

#if !TARGET_OS_OSX
  UIEdgeInsets inset = tv.textContainerInset;
#else
  NSSize containerOrigin = tv.textContainerOrigin;
  UIEdgeInsets inset = UIEdgeInsetsMake(containerOrigin.height, containerOrigin.width, 0, 0);
#endif

  for (ENRMOverlayFadeGroup *group in _groups) {
    CGFloat t = fmax(0.0, fmin((now - group->startTime) / kFadeDuration, 1.0));
    CGFloat alpha = t * t * (3.0 - 2.0 * t); // smoothstep (ease-in-out)
    CGFloat overlayAlpha = 1.0 - alpha;
    if (overlayAlpha <= 0.001)
      continue;

    RCTUIColor *overlayColor = [bgColor colorWithAlphaComponent:overlayAlpha];
    CGContextSetFillColorWithColor(ctx, overlayColor.CGColor);

    NSUInteger clampedStart = MIN(group->tailStart, textStorage.length);
    NSUInteger clampedEnd = MIN(group->tailEnd, textStorage.length);
    if (clampedEnd <= clampedStart)
      continue;

    NSRange charRange = NSMakeRange(clampedStart, clampedEnd - clampedStart);
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
    if (glyphRange.location == NSNotFound || glyphRange.length == 0)
      continue;

    [layoutManager
        enumerateLineFragmentsForGlyphRange:glyphRange
                                 usingBlock:^(CGRect lineRect, CGRect usedRect, NSTextContainer *__unused container,
                                              NSRange lineGlyphRange, BOOL *__unused lineStop) {
                                   NSRange intersect = NSIntersectionRange(lineGlyphRange, glyphRange);
                                   if (intersect.length == 0)
                                     return;

                                   CGRect textRect = [layoutManager boundingRectForGlyphRange:intersect
                                                                              inTextContainer:textContainer];

                                   CGRect fillRect =
                                       CGRectMake(textRect.origin.x + inset.left, textRect.origin.y + inset.top,
                                                  textRect.size.width, textRect.size.height);

                                   if (fillRect.size.width > 0 && fillRect.size.height > 0) {
                                     CGContextFillRect(ctx, fillRect);
                                   }
                                 }];
  }
}

@end

#pragma mark - Animator

@implementation ENRMTailFadeInAnimator {
  __weak ENRMPlatformTextView *_textView;
#if !TARGET_OS_OSX
  CADisplayLink *_displayLink;
#endif
  ENRMFadeOverlayView *_overlayView;
}

- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView
{
  self = [super init];
  if (self) {
    _textView = textView;
  }
  return self;
}

- (void)dealloc
{
#if !TARGET_OS_OSX
  [_displayLink invalidate];
#endif
  [_overlayView removeFromSuperview];
}

- (BOOL)hasActiveAnimations
{
  return _overlayView != nil && _overlayView.groups.count > 0;
}

- (void)ensureOverlayView
{
  ENRMPlatformTextView *tv = _textView;
  if (!tv)
    return;

  if (!_overlayView) {
    _overlayView = [[ENRMFadeOverlayView alloc] initWithFrame:tv.bounds];
    _overlayView.textView = tv;
    _overlayView.autoresizingMask =
#if !TARGET_OS_OSX
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
#else
        NSViewWidthSizable | NSViewHeightSizable;
#endif
    [tv addSubview:_overlayView];
  } else {
    _overlayView.frame = tv.bounds;
  }
}

#pragma mark - Public API

- (void)animateFrom:(NSUInteger)tailStart to:(NSUInteger)tailEnd
{
  if (tailEnd <= tailStart)
    return;

  [self ensureOverlayView];

  ENRMOverlayFadeGroup *group = [[ENRMOverlayFadeGroup alloc] init];
  group->tailStart = tailStart;
  group->tailEnd = tailEnd;
  group->startTime = CACurrentMediaTime();
  [_overlayView.groups addObject:group];

  // Invalidate the overlay synchronously so the new fade group lands in the
  // same vsync as the text-view redraw triggered by setting `attributedText`.
  // Without this, the display link callback (`step:`) wouldn't fire until the
  // *next* vsync, leaving the overlay's cached layer stale for one frame —
  // i.e. the new tail would composite at full opacity over the freshly drawn
  // text, then snap back to the fade overlay on the following frame.
#if !TARGET_OS_OSX
  [_overlayView setNeedsDisplay];
#else
  [_overlayView setNeedsDisplay:YES];
#endif

#if !TARGET_OS_OSX
  if (!_displayLink) {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
    _displayLink.preferredFramesPerSecond = 0; // adaptive
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
  }
#else
  // macOS: no display link — jump straight to fully visible.
  [_overlayView.groups removeLastObject];
  if (_overlayView.groups.count == 0) {
    [_overlayView removeFromSuperview];
    _overlayView = nil;
  }
#endif
}

- (void)cancel
{
#if !TARGET_OS_OSX
  [_displayLink invalidate];
  _displayLink = nil;
#endif

  [_overlayView removeFromSuperview];
  _overlayView = nil;
}

- (void)drawOverlayInRect:(CGRect)rect
{
  // No-op: drawing is handled by _overlayView's drawRect:
}

#pragma mark - Display Link

#if !TARGET_OS_OSX
- (void)step:(CADisplayLink *)__unused link
{
  if (!_overlayView || _overlayView.groups.count == 0) {
    [self cancel];
    return;
  }

  CFTimeInterval now = CACurrentMediaTime();

  // Remove completed groups
  NSMutableIndexSet *completed = [NSMutableIndexSet indexSet];
  for (NSUInteger i = 0; i < _overlayView.groups.count; i++) {
    ENRMOverlayFadeGroup *group = _overlayView.groups[i];
    if ((now - group->startTime) >= kFadeDuration) {
      [completed addIndex:i];
    }
  }
  [_overlayView.groups removeObjectsAtIndexes:completed];

  if (_overlayView.groups.count == 0) {
    [self cancel];
    return;
  }

  // Redraw overlay
#if !TARGET_OS_OSX
  [_overlayView setNeedsDisplay];
#else
  [_overlayView setNeedsDisplay:YES];
#endif
}
#endif

@end
