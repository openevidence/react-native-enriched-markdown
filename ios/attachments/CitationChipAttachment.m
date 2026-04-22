#import "CitationChipAttachment.h"
#import "ENRMUIKit.h"
#import "StyleConfig.h"

// Chip design constants (matching React Native CitationElement)
static const CGFloat kChipHeight = 20.0;
static const CGFloat kChipPaddingH = 8.0;
static const CGFloat kFaviconSize = 14.0;
static const CGFloat kFaviconGap = 4.0;
static const CGFloat kMarginLeft = 4.0;
static const CGFloat kMarginRight = 2.0;

static NSCache<NSString *, UIImage *> *sChipImageCache = nil;
static NSCache<NSString *, UIImage *> *sFaviconCache = nil;

@implementation CitationChipAttachment {
  NSString *_label;
  NSString *_faviconUrl;
  NSString *_numbers;
  UIImage *_faviconImage;
  CGFloat _chipWidth;
  CGFloat _fontSize;
  CGFloat _borderRadius;
  RCTUIColor *_bgColor;
  RCTUIColor *_textColor;
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
    CGFloat cfgFontSize = [config citationFontSize];
    _fontSize = cfgFontSize > 0 ? cfgFontSize : 11.0;
    CGFloat cfgRadius = [config citationBorderRadius];
    // Treat >= kChipHeight as "pill" (matches the JS default of 999).
    _borderRadius = cfgRadius > 0 ? MIN(cfgRadius, kChipHeight / 2.0) : kChipHeight / 2.0;

    // Compute chip width
    NSDictionary *textAttrs = @{NSFontAttributeName : [UIFont systemFontOfSize:_fontSize]};
    CGSize textSize = [_label sizeWithAttributes:textAttrs];
    _chipWidth = kChipPaddingH + textSize.width + kChipPaddingH;
    if (_faviconUrl.length > 0) {
      _chipWidth += kFaviconSize + kFaviconGap;
    }
    // Check favicon cache
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
  CGFloat totalWidth = kMarginLeft + _chipWidth + kMarginRight;

  UIFont *surroundingFont = nil;
  NSTextStorage *storage = textContainer.layoutManager.textStorage;
  if (storage && characterIndex < storage.length) {
    surroundingFont = [storage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
  }

  CGFloat yOffset = surroundingFont ? (surroundingFont.capHeight - kChipHeight) / 2.0 : -4.0;
  return CGRectMake(0, yOffset, totalWidth, kChipHeight);
}

- (UIImage *)imageForBounds:(CGRect)imageBounds
              textContainer:(NSTextContainer *)textContainer
             characterIndex:(NSUInteger)charIndex
{
  // Capture layout manager so loadFavicon can invalidate display later.
  _layoutManager = textContainer.layoutManager;

  NSString *cacheKey =
      [NSString stringWithFormat:@"%@|%d|%.0f|%p|%p|%.1f|%.1f", _label, _faviconLoaded, imageBounds.size.width,
                                 _bgColor, _textColor, _fontSize, _borderRadius];
  UIImage *cached = [sChipImageCache objectForKey:cacheKey];
  if (cached)
    return cached;

  RCTUIColor *bgColor = _bgColor;
  RCTUIColor *textColor = _textColor;

  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:imageBounds.size];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    CGContextRef cg = ctx.CGContext;
    CGRect chipRect = CGRectMake(kMarginLeft, 0, self->_chipWidth, kChipHeight);

    // Pill background
    UIBezierPath *pill = [UIBezierPath bezierPathWithRoundedRect:chipRect cornerRadius:self->_borderRadius];
    [bgColor setFill];
    [pill fill];

    CGFloat x = chipRect.origin.x + kChipPaddingH;

    // Favicon
    if (self->_faviconImage) {
      CGFloat iconY = (kChipHeight - kFaviconSize) / 2.0;
      CGRect iconRect = CGRectMake(x, iconY, kFaviconSize, kFaviconSize);
      CGContextSaveGState(cg);
      [[UIBezierPath bezierPathWithOvalInRect:iconRect] addClip];
      [self->_faviconImage drawInRect:iconRect];
      CGContextRestoreGState(cg);
      x += kFaviconSize + kFaviconGap;
    }

    // Label
    CGFloat maxTextW = chipRect.origin.x + self->_chipWidth - kChipPaddingH - x;
    if (maxTextW > 0) {
      NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
      para.lineBreakMode = NSLineBreakByTruncatingTail;
      NSDictionary *attrs = @{
        NSFontAttributeName : [UIFont systemFontOfSize:self->_fontSize],
        NSForegroundColorAttributeName : textColor,
        NSParagraphStyleAttributeName : para,
      };
      CGFloat textY = (kChipHeight - self->_fontSize) / 2.0 - 1.0;
      [self->_label drawInRect:CGRectMake(x, textY, maxTextW, kChipHeight) withAttributes:attrs];
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
          // bounds are unchanged (chipWidth always includes favicon space).
          NSLayoutManager *lm = strong->_layoutManager;
          if (lm && lm.textStorage.length > 0) {
            [lm invalidateDisplayForCharacterRange:NSMakeRange(0, lm.textStorage.length)];
          }
        });
      }];
  [task resume];
}

@end
