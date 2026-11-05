#import "DoseIconAttachment.h"

static const CGFloat kBaseSurroundingFontSize = 17.0;
static const CGFloat kGlyphGrid = 22.0;
static const CGFloat kActiveRing = 2.0;
static const CGFloat kPersonIconScale = 0.9;

static NSCache<NSString *, RCTUIImage *> *sDoseIconCache = nil;

@implementation DoseIconAppearance
@end

@implementation DoseIconAttachment {
  CGFloat _baseLeadingGap;
  DoseIconAppearance *_appearance;
  CGFloat _iconSize;
  CGFloat _leadingGap;
}

+ (void)initialize
{
  if (self == [DoseIconAttachment class]) {
    sDoseIconCache = [[NSCache alloc] init];
    sDoseIconCache.countLimit = 64;
  }
}

- (instancetype)initWithKind:(ENRMDoseIconKind)kind
                  leadingGap:(CGFloat)leadingGap
                  appearance:(DoseIconAppearance *)appearance
{
  self = [super init];
  if (self) {
    _kind = kind;
    _baseLeadingGap = leadingGap;
    _appearance = appearance;
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

  CGFloat baseSize = _appearance.baseSize > 0 ? _appearance.baseSize : 22.0;
  CGFloat surroundingFontSize = surroundingFont ? surroundingFont.pointSize : kBaseSurroundingFontSize;
  CGFloat scale = surroundingFontSize / kBaseSurroundingFontSize;
  CGFloat lineHeightCap = lineFragment.size.height > 0 ? lineFragment.size.height : baseSize * scale * 1.3;

  CGFloat kindScale = _kind == ENRMDoseIconKindPerson ? kPersonIconScale : 1.0;
  _iconSize = MIN(baseSize * scale * kindScale, lineHeightCap);
  _leadingGap = _baseLeadingGap * scale;

  CGFloat yOffset = surroundingFont ? (surroundingFont.capHeight - _iconSize) / 2.0 : -5.0;
  return CGRectMake(0, yOffset, _leadingGap + _iconSize, _iconSize);
}

#if !TARGET_OS_OSX
static NSString *ENRMColorKey(UIColor *color)
{
  CGFloat r = 0, g = 0, b = 0, a = 0;
  [color getRed:&r green:&g blue:&b alpha:&a];
  return [NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f", r, g, b, a];
}

static UIColor *ENRMLighter(UIColor *tile, UIColor *glyph, CGFloat amount)
{
  CGFloat r1 = 0, g1 = 0, b1 = 0, a1 = 0, r2 = 0, g2 = 0, b2 = 0, a2 = 0;
  [tile getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
  [glyph getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
  return [UIColor colorWithRed:r1 + (r2 - r1) * amount
                         green:g1 + (g2 - g1) * amount
                          blue:b1 + (b2 - b1) * amount
                         alpha:a1];
}

- (UIImage *)imageForBounds:(CGRect)imageBounds
              textContainer:(NSTextContainer *)textContainer
             characterIndex:(NSUInteger)charIndex
{
  CGFloat baseSize = _appearance.baseSize > 0 ? _appearance.baseSize : 22.0;
  CGFloat iconSize = _iconSize > 0 ? _iconSize : baseSize;
  CGFloat leadingGap = _leadingGap;
  ENRMDoseIconKind kind = _kind;
  UIColor *tile = _appearance.tileColor ?: [UIColor grayColor];
  UIColor *glyph = _appearance.glyphColor ?: [UIColor whiteColor];
  ENRMDoseIconState state = _appearance.state;
  CGFloat dimmedOpacity = _appearance.dimmedOpacity > 0 ? _appearance.dimmedOpacity : 0.4;
  CGFloat cornerRadius = kind == ENRMDoseIconKindPerson
                             ? iconSize / 2.0
                             : (_appearance.baseCornerRadius > 0 ? _appearance.baseCornerRadius : 5.0) *
                                   (iconSize / baseSize);

  NSString *cacheKey =
      [NSString stringWithFormat:@"%ld|%ld|%@|%@|%.2f|%.2f|%.2f|%.2f|%.0fx%.0f", (long)kind, (long)state, ENRMColorKey(tile),
                                 ENRMColorKey(glyph), iconSize, leadingGap, cornerRadius, dimmedOpacity,
                                 imageBounds.size.width, imageBounds.size.height];
  UIImage *cached = [sDoseIconCache objectForKey:cacheKey];
  if (cached)
    return cached;

  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:imageBounds.size];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    CGContextRef cg = ctx.CGContext;
    if (state == ENRMDoseIconStateDimmed) {
      CGContextSetAlpha(cg, dimmedOpacity);
      CGContextBeginTransparencyLayer(cg, NULL);
    }
    CGRect square = CGRectMake(leadingGap, 0, iconSize, iconSize);
    if (state == ENRMDoseIconStateActive) {
      CGFloat ring = kActiveRing * (iconSize / kGlyphGrid);
      [[tile colorWithAlphaComponent:0.55] setFill];
      [[UIBezierPath bezierPathWithRoundedRect:square cornerRadius:cornerRadius] fill];
      [ENRMLighter(tile, glyph, 0.14) setFill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(square, ring, ring)
                                  cornerRadius:MAX(cornerRadius - ring, 1.0)] fill];
    } else {
      [tile setFill];
      [[UIBezierPath bezierPathWithRoundedRect:square cornerRadius:cornerRadius] fill];
    }

    CGContextSaveGState(cg);
    CGContextTranslateCTM(cg, square.origin.x, square.origin.y);
    CGFloat unit = iconSize / kGlyphGrid;
    CGContextScaleCTM(cg, unit, unit);
    [DoseIconAttachment drawGlyphForKind:kind tile:tile glyph:glyph];
    CGContextRestoreGState(cg);
    if (state == ENRMDoseIconStateDimmed) {
      CGContextEndTransparencyLayer(cg);
    }
  }];

  [sDoseIconCache setObject:image forKey:cacheKey];
  return image;
}

+ (void)drawGlyphForKind:(ENRMDoseIconKind)kind tile:(UIColor *)tile glyph:(UIColor *)glyph
{
  switch (kind) {
    case ENRMDoseIconKindCheck: {
      [glyph setFill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.0, 3.5, 10.0, 15.0) cornerRadius:2.0] fill];
      [tile setFill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.0, 6.0, 6.0, 1.7) cornerRadius:0.85] fill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.0, 8.8, 4.0, 1.7) cornerRadius:0.85] fill];
      UIBezierPath *check = [UIBezierPath bezierPath];
      [check moveToPoint:CGPointMake(8.8, 13.8)];
      [check addLineToPoint:CGPointMake(10.5, 15.2)];
      [check addLineToPoint:CGPointMake(13.4, 12.2)];
      check.lineWidth = 1.6;
      check.lineCapStyle = kCGLineCapRound;
      check.lineJoinStyle = kCGLineJoinRound;
      [tile setStroke];
      [check stroke];
      break;
    }
    case ENRMDoseIconKindPerson: {
      [glyph setFill];
      [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.0, 5.4, 6.0, 6.0)] fill];
      UIBezierPath *body = [UIBezierPath bezierPath];
      [body moveToPoint:CGPointMake(6.4, 16.4)];
      [body addLineToPoint:CGPointMake(6.4, 15.6)];
      [body addCurveToPoint:CGPointMake(11.0, 12.0)
              controlPoint1:CGPointMake(6.4, 13.4)
              controlPoint2:CGPointMake(8.4, 12.0)];
      [body addCurveToPoint:CGPointMake(15.6, 15.6)
              controlPoint1:CGPointMake(13.6, 12.0)
              controlPoint2:CGPointMake(15.6, 13.4)];
      [body addLineToPoint:CGPointMake(15.6, 16.4)];
      [body closePath];
      [body fill];
      break;
    }
    case ENRMDoseIconKindCalculator: {
      [glyph setFill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.0, 3.5, 10.0, 15.0) cornerRadius:2.0] fill];
      [tile setFill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.6, 5.2, 6.8, 2.6) cornerRadius:0.6] fill];
      for (int row = 0; row < 2; row++) {
        for (int col = 0; col < 2; col++) {
          CGRect key = CGRectMake(7.6 + col * 4.2, 9.4 + row * 4.3, 2.6, 2.6);
          [[UIBezierPath bezierPathWithRoundedRect:key cornerRadius:0.6] fill];
        }
      }
      break;
    }
  }
}
#endif

@end
