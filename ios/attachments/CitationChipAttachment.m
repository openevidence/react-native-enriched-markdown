#import "CitationChipAttachment.h"
#import "ENRMUIKit.h"
#import "StyleConfig.h"

// Baseline chip dimensions, sized for a 17pt surrounding font. All values
// scale proportionally with the actual surrounding font size, and chipHeight
// is capped by the proposed line fragment height so the chip never exceeds
// the line. Per-layout dimensions are computed in attachmentBoundsForTextContainer:.
static const CGFloat kBaseSurroundingFontSize = 17.0;
static const CGFloat kBaseChipHeight = 18.0;
static const CGFloat kBaseChipFontSize = 11.0;
static const CGFloat kBaseChipPaddingH = 7.0;
static const CGFloat kBaseFaviconSize = 13.0;
static const CGFloat kBaseFaviconGap = 3.5;
// Trailing buffer so the chip doesn't kiss following punctuation/text.
// Leading separation is handled by a space character injected by CitationRenderer,
// which wraps naturally at line breaks.
static const CGFloat kBaseMarginRight = 3.0;

static NSCache<NSString *, UIImage *> *sChipImageCache = nil;
static NSCache<NSString *, UIImage *> *sFaviconCache = nil;

@implementation CitationChipAttachment {
  NSString *_label;
  NSString *_faviconUrl;
  NSString *_numbers;
  UIImage *_faviconImage;

  RCTUIColor *_bgColor;
  RCTUIColor *_textColor;
  CGFloat _configFontSize;     // >0 = explicit override, 0 = auto-scale
  CGFloat _configBorderRadius; // >0 = explicit override, 0 = pill

  // Computed per-layout in attachmentBoundsForTextContainer:, consumed by imageForBounds:.
  CGFloat _chipHeight;
  CGFloat _chipWidth;
  CGFloat _fontSize;
  CGFloat _chipPaddingH;
  CGFloat _faviconSize;
  CGFloat _faviconGap;
  CGFloat _marginRight;
  CGFloat _borderRadius;

  BOOL _faviconLoaded;
  __weak NSLayoutManager *_layoutManager;
}

+ (void)initialize
{
  if (self == [CitationChipAttachment class]) {
    sChipImageCache = [[NSCache alloc] init];
    sChipImageCache.countLimit = 200;
    sFaviconCache = [[NSCache alloc] init];
    sFaviconCache.countLimit = 50;
  }
}

- (instancetype)initWithLabel:(NSString *)label
                   faviconUrl:(NSString *)faviconUrl
                      numbers:(NSString *)numbers
                       config:(StyleConfig *)config
{
  self = [super init];
  if (self) {
    _label = [label copy];
    _faviconUrl = [faviconUrl copy];
    _numbers = [numbers copy];
    _faviconLoaded = NO;

    _bgColor = [config citationBackgroundColor] ?: [RCTUIColor colorWithRed:0.988 green:0.933 blue:0.910 alpha:1.0];
    _textColor = [config citationColor] ?: [RCTUIColor colorWithRed:0.204 green:0.196 blue:0.192 alpha:1.0];
    _configFontSize = [config citationFontSize];
    _configBorderRadius = [config citationBorderRadius];

    if (_faviconUrl.length > 0) {
      UIImage *cached = [sFaviconCache objectForKey:_faviconUrl];
      if (cached) {
        _faviconImage = cached;
        _faviconLoaded = YES;
      } else {
        [self loadFavicon];
      }
    }
  }
  return self;
}

- (NSString *)textForCopy
{
  return [NSString stringWithFormat:@"[%@]", _numbers];
}

#pragma mark - NSTextAttachment

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)glyphPosition
                            characterIndex:(NSUInteger)characterIndex
{
  UIFont *surroundingFont = nil;
  NSTextStorage *storage = textContainer.layoutManager.textStorage;
  if (storage && characterIndex < storage.length) {
    surroundingFont = [storage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
    // The attachment character may not carry a font attribute directly — fall
    // back to the preceding character, which inherits from the surrounding
    // text (including the whitespace injected by CitationRenderer).
    if (!surroundingFont && characterIndex > 0) {
      surroundingFont = [storage attribute:NSFontAttributeName atIndex:characterIndex - 1 effectiveRange:NULL];
    }
  }

  CGFloat surroundingFontSize = surroundingFont ? surroundingFont.pointSize : kBaseSurroundingFontSize;
  CGFloat lineHeightCap = lineFragment.size.height > 0
                              ? lineFragment.size.height
                              : (surroundingFont ? surroundingFont.lineHeight : kBaseChipHeight * 1.3);

  CGFloat desiredChipHeight = kBaseChipHeight * (surroundingFontSize / kBaseSurroundingFontSize);
  _chipHeight = MIN(desiredChipHeight, lineHeightCap);
  CGFloat scale = _chipHeight / kBaseChipHeight;

  CGFloat autoFontSize = kBaseChipFontSize * scale;
  // Explicit config wins, but clamp so the label still fits inside the chip.
  _fontSize = _configFontSize > 0 ? MIN(_configFontSize, _chipHeight * 0.85) : autoFontSize;

  _chipPaddingH = kBaseChipPaddingH * scale;
  _faviconSize = kBaseFaviconSize * scale;
  _faviconGap = kBaseFaviconGap * scale;
  _marginRight = kBaseMarginRight * scale;

  _borderRadius = _configBorderRadius > 0 ? MIN(_configBorderRadius, _chipHeight / 2.0) : _chipHeight / 2.0;

  NSDictionary *textAttrs = @{NSFontAttributeName : [UIFont systemFontOfSize:_fontSize]};
  CGSize textSize = [_label sizeWithAttributes:textAttrs];
  _chipWidth = _chipPaddingH + textSize.width + _chipPaddingH;
  if (_faviconUrl.length > 0) {
    _chipWidth += _faviconSize + _faviconGap;
  }

  CGFloat totalWidth = _chipWidth + _marginRight;
  CGFloat yOffset = surroundingFont ? (surroundingFont.capHeight - _chipHeight) / 2.0 : -4.0;
  return CGRectMake(0, yOffset, totalWidth, _chipHeight);
}

- (UIImage *)imageForBounds:(CGRect)imageBounds
              textContainer:(NSTextContainer *)textContainer
             characterIndex:(NSUInteger)charIndex
{
  _layoutManager = textContainer.layoutManager;

  NSString *cacheKey =
      [NSString stringWithFormat:@"%@|%d|%.1f|%.1f|%p|%p|%.2f|%.2f", _label, _faviconLoaded, _chipWidth, _chipHeight,
                                 _bgColor, _textColor, _fontSize, _borderRadius];
  UIImage *cached = [sChipImageCache objectForKey:cacheKey];
  if (cached)
    return cached;

  RCTUIColor *bgColor = _bgColor;
  RCTUIColor *textColor = _textColor;
  CGFloat chipHeight = _chipHeight;
  CGFloat chipWidth = _chipWidth;
  CGFloat chipPaddingH = _chipPaddingH;
  CGFloat faviconSize = _faviconSize;
  CGFloat faviconGap = _faviconGap;
  CGFloat fontSize = _fontSize;
  CGFloat borderRadius = _borderRadius;
  UIImage *faviconImage = _faviconImage;
  NSString *label = _label;

  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:imageBounds.size];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    CGContextRef cg = ctx.CGContext;
    CGRect chipRect = CGRectMake(0, 0, chipWidth, chipHeight);

    UIBezierPath *pill = [UIBezierPath bezierPathWithRoundedRect:chipRect cornerRadius:borderRadius];
    [bgColor setFill];
    [pill fill];

    CGFloat x = chipRect.origin.x + chipPaddingH;

    if (faviconImage) {
      CGFloat iconY = (chipHeight - faviconSize) / 2.0;
      CGRect iconRect = CGRectMake(x, iconY, faviconSize, faviconSize);
      CGContextSaveGState(cg);
      [[UIBezierPath bezierPathWithOvalInRect:iconRect] addClip];
      [faviconImage drawInRect:iconRect];
      CGContextRestoreGState(cg);
      x += faviconSize + faviconGap;
    }

    CGFloat maxTextW = chipRect.origin.x + chipWidth - chipPaddingH - x;
    if (maxTextW > 0) {
      UIFont *chipFont = [UIFont systemFontOfSize:fontSize];
      NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
      para.lineBreakMode = NSLineBreakByTruncatingTail;
      NSDictionary *attrs = @{
        NSFontAttributeName : chipFont,
        NSForegroundColorAttributeName : textColor,
        NSParagraphStyleAttributeName : para,
      };
      // Vertically center the label's line box inside the chip using the
      // font's actual line height — stays centered regardless of the
      // (dynamic) fontSize / chipHeight values.
      CGFloat textY = (chipHeight - chipFont.lineHeight) / 2.0;
      [label drawInRect:CGRectMake(x, textY, maxTextW, chipFont.lineHeight) withAttributes:attrs];
    }
  }];

  [sChipImageCache setObject:image forKey:cacheKey];
  return image;
}

#pragma mark - Favicon

- (void)loadFavicon
{
  NSURL *url = [NSURL URLWithString:_faviconUrl];
  if (!url)
    return;

  __weak CitationChipAttachment *weakSelf = self;
  NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:url
      completionHandler:^(NSData *data, NSURLResponse *__unused response, NSError *__unused error) {
        if (!data)
          return;
        UIImage *image = [UIImage imageWithData:data];
        if (!image)
          return;
        [sFaviconCache setObject:image forKey:self->_faviconUrl];
        dispatch_async(dispatch_get_main_queue(), ^{
          CitationChipAttachment *strong = weakSelf;
          if (!strong)
            return;
          strong->_faviconImage = image;
          strong->_faviconLoaded = YES;
          // Invalidate DISPLAY only (not layout) so the text system re-composites
          // the attachment image without recalculating glyph metrics. The chip
          // bounds are unchanged (chipWidth always reserves favicon space).
          NSLayoutManager *lm = strong->_layoutManager;
          if (lm && lm.textStorage.length > 0) {
            [lm invalidateDisplayForCharacterRange:NSMakeRange(0, lm.textStorage.length)];
          }
        });
      }];
  [task resume];
}

@end
