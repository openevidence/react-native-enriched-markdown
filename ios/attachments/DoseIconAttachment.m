#import "DoseIconAttachment.h"

// Sized like the citation chip: 18 pt tall beside 17 pt text, scaled with the
// surrounding font and capped by the line height so a mark never grows a line.
static const CGFloat kBaseSurroundingFontSize = 17.0;
static const CGFloat kBaseIconSize = 18.0;
static const CGFloat kBaseCornerRadius = 4.5;
// Glyphs are drawn on an 18-unit grid and scaled to the icon's size.
static const CGFloat kGlyphGrid = 18.0;

static NSCache<NSString *, RCTUIImage *> *sDoseIconCache = nil;

@implementation DoseIconAttachment {
  CGFloat _baseLeadingGap;
  // Computed per layout in attachmentBoundsForTextContainer:, used by imageForBounds:.
  CGFloat _iconSize;
  CGFloat _leadingGap;
}

+ (void)initialize
{
  if (self == [DoseIconAttachment class]) {
    sDoseIconCache = [[NSCache alloc] init];
    sDoseIconCache.countLimit = 48;
  }
}

+ (RCTUIColor *)colorForKind:(ENRMDoseIconKind)kind
{
  switch (kind) {
    case ENRMDoseIconKindCheck:
      return [RCTUIColor colorWithRed:47 / 255.0 green:158 / 255.0 blue:92 / 255.0 alpha:1.0]; // #2F9E5C
    case ENRMDoseIconKindPerson:
      return [RCTUIColor colorWithRed:217 / 255.0 green:119 / 255.0 blue:6 / 255.0 alpha:1.0]; // #D97706
    case ENRMDoseIconKindCalculator:
      return [RCTUIColor colorWithRed:228 / 255.0 green:100 / 255.0 blue:61 / 255.0 alpha:1.0]; // #E4643D, OE orange
  }
  return [RCTUIColor grayColor];
}

- (instancetype)initWithKind:(ENRMDoseIconKind)kind leadingGap:(CGFloat)leadingGap
{
  self = [super init];
  if (self) {
    _kind = kind;
    _baseLeadingGap = leadingGap;
  }
  return self;
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
    if (!surroundingFont && characterIndex > 0) {
      surroundingFont = [storage attribute:NSFontAttributeName atIndex:characterIndex - 1 effectiveRange:NULL];
    }
  }

  CGFloat surroundingFontSize = surroundingFont ? surroundingFont.pointSize : kBaseSurroundingFontSize;
  CGFloat scale = surroundingFontSize / kBaseSurroundingFontSize;
  CGFloat lineHeightCap = lineFragment.size.height > 0 ? lineFragment.size.height : kBaseIconSize * scale * 1.3;

  _iconSize = MIN(kBaseIconSize * scale, lineHeightCap);
  _leadingGap = _baseLeadingGap * scale;

  // Centre the square on the text's cap height, as the citation chip does.
  CGFloat yOffset = surroundingFont ? (surroundingFont.capHeight - _iconSize) / 2.0 : -4.0;
  return CGRectMake(0, yOffset, _leadingGap + _iconSize, _iconSize);
}

#if !TARGET_OS_OSX
- (UIImage *)imageForBounds:(CGRect)imageBounds
              textContainer:(NSTextContainer *)textContainer
             characterIndex:(NSUInteger)charIndex
{
  CGFloat iconSize = _iconSize > 0 ? _iconSize : kBaseIconSize;
  CGFloat leadingGap = _leadingGap;
  ENRMDoseIconKind kind = _kind;

  NSString *cacheKey = [NSString stringWithFormat:@"%ld|%.2f|%.2f|%.0fx%.0f", (long)kind, iconSize, leadingGap,
                                                  imageBounds.size.width, imageBounds.size.height];
  UIImage *cached = [sDoseIconCache objectForKey:cacheKey];
  if (cached)
    return cached;

  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:imageBounds.size];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    CGContextRef cg = ctx.CGContext;
    CGRect square = CGRectMake(leadingGap, 0, iconSize, iconSize);
    CGFloat radius = kBaseCornerRadius * (iconSize / kBaseIconSize);
    [[DoseIconAttachment colorForKind:kind] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:square cornerRadius:radius] fill];

    CGContextSaveGState(cg);
    CGContextTranslateCTM(cg, square.origin.x, square.origin.y);
    CGFloat unit = iconSize / kGlyphGrid;
    CGContextScaleCTM(cg, unit, unit);
    [[UIColor whiteColor] setStroke];
    [[UIColor whiteColor] setFill];
    [DoseIconAttachment drawGlyphForKind:kind];
    CGContextRestoreGState(cg);
  }];

  [sDoseIconCache setObject:image forKey:cacheKey];
  return image;
}

/// Draws the white glyph on the 18-unit grid (the caller has scaled the context).
+ (void)drawGlyphForKind:(ENRMDoseIconKind)kind
{
  switch (kind) {
    case ENRMDoseIconKindCheck: {
      // A page with a check mark: "checked against the source document".
      UIBezierPath *page = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.0, 3.4, 8.0, 11.2) cornerRadius:1.6];
      page.lineWidth = 1.5;
      [page stroke];
      UIBezierPath *line = [UIBezierPath bezierPath];
      [line moveToPoint:CGPointMake(7.4, 6.4)];
      [line addLineToPoint:CGPointMake(10.6, 6.4)];
      line.lineWidth = 1.5;
      line.lineCapStyle = kCGLineCapRound;
      [line stroke];
      UIBezierPath *check = [UIBezierPath bezierPath];
      [check moveToPoint:CGPointMake(7.0, 10.2)];
      [check addLineToPoint:CGPointMake(8.6, 11.8)];
      [check addLineToPoint:CGPointMake(11.3, 8.8)];
      check.lineWidth = 1.7;
      check.lineCapStyle = kCGLineCapRound;
      check.lineJoinStyle = kCGLineJoinRound;
      [check stroke];
      break;
    }
    case ENRMDoseIconKindPerson: {
      // A person: "written for a different patient group".
      [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(6.3, 3.6, 5.4, 5.4)] fill];
      UIBezierPath *shoulders = [UIBezierPath bezierPath];
      [shoulders moveToPoint:CGPointMake(4.2, 14.6)];
      [shoulders addCurveToPoint:CGPointMake(13.8, 14.6)
                   controlPoint1:CGPointMake(4.4, 9.4)
                   controlPoint2:CGPointMake(13.6, 9.4)];
      [shoulders closePath];
      [shoulders fill];
      break;
    }
    case ENRMDoseIconKindCalculator: {
      // A calculator: "a rule the dosing calculator can compute from".
      UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.0, 3.2, 8.0, 11.6) cornerRadius:1.6];
      body.lineWidth = 1.5;
      [body stroke];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.0, 5.2, 4.0, 2.1) cornerRadius:0.5] fill];
      for (int row = 0; row < 2; row++) {
        for (int col = 0; col < 2; col++) {
          CGFloat cx = 7.6 + col * 2.8;
          CGFloat cy = 9.6 + row * 2.6;
          [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx - 0.85, cy - 0.85, 1.7, 1.7)] fill];
        }
      }
      break;
    }
  }
}
#endif

@end
