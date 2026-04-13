#import "ENRMTailFadeInAnimator.h"
#import "LinkTapUtils.h"
#import <QuartzCore/QuartzCore.h>
#include <TargetConditionals.h>

static const NSTimeInterval kFadeDuration = 0.60;

typedef struct {
  NSRange range;
  __unsafe_unretained RCTUIColor *color;
} ENRMColorEntry;

/// One chunk of text being faded in independently.
@interface ENRMFadeGroup : NSObject {
@public
  CFTimeInterval startTime;
  NSArray<RCTUIColor *> *retainedColors;
  ENRMColorEntry *entries;
  NSUInteger count;
}
- (void)cleanup;
@end

@implementation ENRMFadeGroup

- (void)cleanup
{
  if (entries) {
    free(entries);
    entries = NULL;
  }
  retainedColors = nil;
  count = 0;
}

- (void)dealloc
{
  [self cleanup];
}

@end

#pragma mark -

@implementation ENRMTailFadeInAnimator {
  __weak ENRMPlatformTextView *_textView;
#if !TARGET_OS_OSX
  CADisplayLink *_displayLink;
#endif
  NSMutableArray<ENRMFadeGroup *> *_activeGroups;
}

- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView
{
  self = [super init];
  if (self) {
    _textView = textView;
    _activeGroups = [NSMutableArray array];
  }
  return self;
}

- (void)dealloc
{
  for (ENRMFadeGroup *group in _activeGroups) {
    [group cleanup];
  }
#if !TARGET_OS_OSX
  [_displayLink invalidate];
#endif
}

#pragma mark - Public API

- (void)animateFrom:(NSUInteger)tailStart to:(NSUInteger)tailEnd
{
  // Do NOT cancel previous animations — each tail fades in independently.
  // The word-level buffer delivers small tails (typically 1-2 words per tick),
  // so each call naturally produces a word-granularity animation.
  NSTextStorage *storage = _textView.textStorage;
  if (!storage || tailEnd <= tailStart || tailEnd > storage.length)
    return;

  NSRange range = NSMakeRange(tailStart, tailEnd - tailStart);

  ENRMFadeGroup *group = [self snapshotGroup:range storage:storage];
  if (!group)
    return;

  group->startTime = CACurrentMediaTime();
  [_activeGroups addObject:group];

#if !TARGET_OS_OSX
  if (!_displayLink) {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
    _displayLink.preferredFramesPerSecond = 0;
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
  }
#else
  // macOS: no display link — jump straight to fully visible.
  [self setGroup:group alpha:1.0];
  [group cleanup];
  [_activeGroups removeLastObject];
#endif
}

- (void)cancel
{
#if !TARGET_OS_OSX
  [_displayLink invalidate];
  _displayLink = nil;
#endif

  if (_activeGroups.count == 0)
    return;

  // Finalize all active groups to full opacity.
  NSTextStorage *storage = _textView.textStorage;
  if (storage) {
    [storage beginEditing];
    for (ENRMFadeGroup *group in _activeGroups) {
      [self applyGroup:group alpha:1.0 storage:storage];
      [group cleanup];
    }
    [storage endEditing];
  } else {
    for (ENRMFadeGroup *group in _activeGroups) {
      [group cleanup];
    }
  }
  [_activeGroups removeAllObjects];
}

- (void)preApplyToAttributedString:(NSMutableAttributedString *)attributedText
{
  if (_activeGroups.count == 0)
    return;

  CFTimeInterval now = CACurrentMediaTime();

  for (ENRMFadeGroup *group in _activeGroups) {
    CGFloat t = fmax(0.0, fmin((now - group->startTime) / kFadeDuration, 1.0));
    CGFloat alpha = 1.0 - (1.0 - t) * (1.0 - t); // ease-out quadratic

    for (NSUInteger i = 0; i < group->count; i++) {
      ENRMColorEntry entry = group->entries[i];
      if (NSMaxRange(entry.range) <= attributedText.length) {
        RCTUIColor *fadedColor = [entry.color colorWithAlphaComponent:alpha];
        [attributedText addAttribute:NSForegroundColorAttributeName value:fadedColor range:entry.range];
      }
    }
  }
}

#pragma mark - Display Link

#if !TARGET_OS_OSX
- (void)step:(CADisplayLink *)__unused link
{
  NSTextStorage *storage = _textView.textStorage;
  if (!storage) {
    [self cancel];
    return;
  }

  CFTimeInterval now = CACurrentMediaTime();

  [storage beginEditing];

  // Track which groups completed this frame.
  NSMutableIndexSet *completed = [NSMutableIndexSet indexSet];

  for (NSUInteger gi = 0; gi < _activeGroups.count; gi++) {
    ENRMFadeGroup *group = _activeGroups[gi];
    CGFloat t = fmax(0.0, fmin((now - group->startTime) / kFadeDuration, 1.0));
    CGFloat alpha = 1.0 - (1.0 - t) * (1.0 - t); // ease-out quadratic

    [self applyGroup:group alpha:alpha storage:storage];

    if (t >= 1.0) {
      [completed addIndex:gi];
    }
  }

  [storage endEditing];

  // Remove completed groups in reverse order to keep indices valid.
  [completed enumerateIndexesWithOptions:NSEnumerationReverse
                              usingBlock:^(NSUInteger idx, __unused BOOL *stop) {
                                [self->_activeGroups[idx] cleanup];
                                [self->_activeGroups removeObjectAtIndex:idx];
                              }];

  if (_activeGroups.count == 0) {
    [_displayLink invalidate];
    _displayLink = nil;
  }
}
#endif

#pragma mark - Internals

- (ENRMFadeGroup *)snapshotGroup:(NSRange)range storage:(NSTextStorage *)storage
{
  NSMutableArray<RCTUIColor *> *colors = [NSMutableArray array];
  NSMutableArray<NSValue *> *ranges = [NSMutableArray array];

  [storage enumerateAttribute:NSForegroundColorAttributeName
                      inRange:range
                      options:0
                   usingBlock:^(RCTUIColor *color, NSRange subRange, __unused BOOL *stop) {
                     [colors addObject:color ?: [RCTUIColor labelColor]];
                     [ranges addObject:[NSValue valueWithRange:subRange]];
                   }];

  if (colors.count == 0)
    return nil;

  ENRMFadeGroup *group = [[ENRMFadeGroup alloc] init];
  group->count = colors.count;
  group->retainedColors = [colors copy];
  group->entries = malloc(sizeof(ENRMColorEntry) * group->count);

  for (NSUInteger i = 0; i < group->count; i++) {
    group->entries[i].color = group->retainedColors[i];
    group->entries[i].range = [ranges[i] rangeValue];
  }

  return group;
}

/// Apply a single alpha value to every entry in a group.
- (void)applyGroup:(ENRMFadeGroup *)group alpha:(CGFloat)alpha storage:(NSTextStorage *)storage
{
  for (NSUInteger i = 0; i < group->count; i++) {
    ENRMColorEntry entry = group->entries[i];
    if (NSMaxRange(entry.range) <= storage.length) {
      RCTUIColor *fadedColor = [entry.color colorWithAlphaComponent:alpha];
      [storage addAttribute:NSForegroundColorAttributeName value:fadedColor range:entry.range];
    }
  }
}

/// Convenience: apply alpha when only one group needs an immediate update.
- (void)setGroup:(ENRMFadeGroup *)group alpha:(CGFloat)alpha
{
  NSTextStorage *storage = _textView.textStorage;
  if (!storage || group->count == 0)
    return;
  [storage beginEditing];
  [self applyGroup:group alpha:alpha storage:storage];
  [storage endEditing];
}

@end
