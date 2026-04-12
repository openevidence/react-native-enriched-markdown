#import "CitationChipAttachment.h"
#import "CitationChipView.h"
#import "RuntimeKeys.h"
#import <objc/runtime.h>

static const CGFloat kChipHeight = 20.0;
static const CGFloat kLeadingMargin = 4.0;
static const CGFloat kTrailingMargin = 2.0;

@interface CitationChipAttachment ()

@property (nonatomic, strong, readwrite) CitationChipView *chipView;
@property (nonatomic, weak) NSTextContainer *textContainer;
@property (nonatomic, weak) ENRMPlatformTextView *textView;

@end

@implementation CitationChipAttachment

- (instancetype)initWithChipView:(CitationChipView *)chipView
{
  self = [super init];
  if (self) {
    _chipView = chipView;

    // Initial render (no favicon yet — or favicon if already cached)
    RCTUIImage *initialImage = [chipView renderToImage];
    if (initialImage) {
      self.image = initialImage;
    }

    // Set initial bounds so the attachment has a size before layout asks
    CGFloat chipWidth = chipView.chipSize.width;
    CGFloat totalWidth = kLeadingMargin + chipWidth + kTrailingMargin;
    self.bounds = CGRectMake(0, 0, totalWidth, kChipHeight);

    // Re-render when favicon arrives
    __weak typeof(self) weakSelf = self;
    chipView.onFaviconLoaded = ^{
      [weakSelf handleFaviconLoaded];
    };
  }
  return self;
}

#pragma mark - NSTextAttachment overrides

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  self.textContainer = textContainer;

  CGFloat chipWidth = self.chipView.chipSize.width;
  // Total width = leading margin + chip + trailing margin
  CGFloat totalWidth = kLeadingMargin + chipWidth + kTrailingMargin;

  // Vertically center with surrounding text baseline
  UIFont *appliedFont = nil;
  NSLayoutManager *layoutManager = textContainer.layoutManager;
  NSTextStorage *textStorage = layoutManager.textStorage;

  if (textStorage && characterIndex < textStorage.length) {
    appliedFont = [textStorage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
  }

  CGFloat verticalOffset;
  if (appliedFont) {
    verticalOffset = (appliedFont.capHeight - kChipHeight) / 2.0;
  } else {
    verticalOffset = (lineFragment.size.height - kChipHeight) / 2.0;
  }

  return CGRectMake(0, verticalOffset, totalWidth, kChipHeight);
}

- (RCTUIImage *)imageForBounds:(CGRect)imageBounds
                 textContainer:(NSTextContainer *)textContainer
                characterIndex:(NSUInteger)characterIndex
{
  self.textContainer = textContainer;

  CGFloat chipWidth = self.chipView.chipSize.width;
  CGFloat chipHeight = self.chipView.chipSize.height;

  if (chipWidth <= 0 || chipHeight <= 0) {
    return self.image;
  }

  CGSize totalSize = imageBounds.size;
  if (totalSize.width <= 0 || totalSize.height <= 0) {
    return self.image;
  }

  // Render the chip view into an image, then composite it into a
  // margin-padded canvas matching the attachment bounds.
  RCTUIImage *chipImage = [self.chipView renderToImage];
  if (!chipImage) {
    return self.image;
  }

  RCTUIGraphicsImageRenderer *renderer = ImageRendererForSize(totalSize);
  RCTUIImage *rendered = [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *ctx) {
    CGFloat chipY = (totalSize.height - chipHeight) / 2.0;
    [chipImage drawInRect:CGRectMake(kLeadingMargin, chipY, chipWidth, chipHeight)];
  }];

  return rendered ?: self.image;
}

#pragma mark - Favicon reload

- (void)handleFaviconLoaded
{
  // Re-render the chip to a new image
  RCTUIImage *newImage = [self.chipView renderToImage];
  if (newImage) {
    self.image = newImage;
  }

  [self refreshDisplay];
}

- (void)refreshDisplay
{
  ENRMPlatformTextView *tv = [self fetchAssociatedTextView];
  if (!tv)
    return;

  NSRange range = [self findAttachmentRangeInText:tv.textStorage];
  if (range.location != NSNotFound) {
    [tv.layoutManager invalidateDisplayForCharacterRange:range];
  }
}

- (ENRMPlatformTextView *)fetchAssociatedTextView
{
  if (self.textView)
    return self.textView;
  if (!self.textContainer)
    return nil;
  self.textView = objc_getAssociatedObject(self.textContainer, kTextViewKey);
  return self.textView;
}

- (NSRange)findAttachmentRangeInText:(NSAttributedString *)attributedString
{
  __block NSRange foundRange = NSMakeRange(NSNotFound, 0);
  if (!attributedString || attributedString.length == 0)
    return foundRange;

  [attributedString enumerateAttribute:NSAttachmentAttributeName
                               inRange:NSMakeRange(0, attributedString.length)
                               options:0
                            usingBlock:^(id value, NSRange range, BOOL *stop) {
                              if (value == self) {
                                foundRange = range;
                                *stop = YES;
                              }
                            }];
  return foundRange;
}

@end
