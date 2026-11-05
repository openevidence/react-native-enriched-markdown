#import "DosePillBackground.h"
#import "ENRMUIKit.h"
#import "RenderContext.h"

// Daniel's pill beside 15 px text is 30 px tall with 7 px corners and a 1 px
// border, centred on the digits. In em, so it scales with Dynamic Type.
static const CGFloat kPillHeightEm = 2.0;
static const CGFloat kPillCornerEm = 0.47;
static const CGFloat kPillBorderWidth = 1.0;
// The pill never grows past its line: it stays this far inside the line's
// used height, so pills on neighbouring lines never touch.
static const CGFloat kPillLineInset = 1.0;

@implementation DosePillBackground {
  StyleConfig *_config;
}

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super init];
  if (self) {
    _config = config;
  }
  return self;
}

- (void)drawBackgroundsForGlyphRange:(NSRange)glyphsToShow
                       layoutManager:(NSLayoutManager *)layoutManager
                       textContainer:(NSTextContainer *)textContainer
                             atPoint:(CGPoint)origin
{
  RCTUIColor *fill = _config.dosePillBackgroundColor;
  RCTUIColor *border = _config.dosePillBorderColor;
  if (!fill && !border)
    return;

  NSTextStorage *textStorage = layoutManager.textStorage;
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphsToShow actualGlyphRange:NULL];
  if (charRange.location == NSNotFound || charRange.length == 0)
    return;

  [textStorage enumerateAttribute:ENRMDosePillAttributeName
                          inRange:NSMakeRange(0, textStorage.length)
                          options:0
                       usingBlock:^(id value, NSRange range, BOOL *stop) {
                         if (!value || range.length == 0)
                           return;
                         if (NSIntersectionRange(range, charRange).length == 0)
                           return;
                         [self drawPillForRange:range
                                  layoutManager:layoutManager
                                  textContainer:textContainer
                                        atPoint:origin
                                           fill:fill
                                         border:border];
                       }];
}

- (void)drawPillForRange:(NSRange)range
           layoutManager:(NSLayoutManager *)layoutManager
           textContainer:(NSTextContainer *)textContainer
                 atPoint:(CGPoint)origin
                    fill:(nullable RCTUIColor *)fill
                  border:(nullable RCTUIColor *)border
{
  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  if (glyphRange.location == NSNotFound || glyphRange.length == 0)
    return;

  UIFont *font = [self textFontInRange:range textStorage:layoutManager.textStorage];
  CGFloat fontSize = font ? font.pointSize : 17.0;
  CGFloat capHeight = font ? font.capHeight : fontSize * 0.7;
  NSString *text = layoutManager.textStorage.string;

  [layoutManager
      enumerateLineFragmentsForGlyphRange:glyphRange
                               usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *tc, NSRange lineRange,
                                            BOOL *stop) {
                                 NSRange piece = NSIntersectionRange(lineRange, glyphRange);
                                 if (piece.length == 0)
                                   return;
                                 BOOL isFirst = (piece.location == glyphRange.location);
                                 BOOL isLast = (NSMaxRange(piece) == NSMaxRange(glyphRange));

                                 // Where the line wraps inside the pill, its open end stops at the
                                 // last word, not after the space the line broke at.
                                 while (!isLast && piece.length > 1) {
                                   NSUInteger lastChar =
                                       [layoutManager characterIndexForGlyphAtIndex:NSMaxRange(piece) - 1];
                                   if (lastChar >= text.length ||
                                       ![[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                           characterIsMember:[text characterAtIndex:lastChar]])
                                     break;
                                   piece.length -= 1;
                                 }

                                 CGRect textRect = [layoutManager boundingRectForGlyphRange:piece
                                                                            inTextContainer:textContainer];
                                 // Centred on the cap height, as Daniel's pill sits on its digits.
                                 CGPoint location = [layoutManager locationForGlyphAtIndex:piece.location];
                                 CGFloat capCentre = rect.origin.y + location.y - capHeight / 2.0;
                                 CGFloat height = MIN(fontSize * kPillHeightEm,
                                                      MAX(usedRect.size.height - 2.0 * kPillLineInset, capHeight));
                                 CGRect pill = CGRectMake(textRect.origin.x + origin.x,
                                                          capCentre - height / 2.0 + origin.y,
                                                          textRect.size.width, height);
                                 CGFloat radius = MIN(fontSize * kPillCornerEm, height / 2.0);
                                 [self drawPill:pill
                                        isFirst:isFirst
                                         isLast:isLast
                                         radius:radius
                                           fill:fill
                                         border:border];
                               }];
}

- (nullable UIFont *)textFontInRange:(NSRange)range textStorage:(NSTextStorage *)textStorage
{
  // The words' font, skipping the padding and icon at the pill's ends.
  __block UIFont *found = nil;
  [textStorage enumerateAttribute:NSFontAttributeName
                          inRange:range
                          options:0
                       usingBlock:^(id value, NSRange r, BOOL *stop) {
                         if ([value isKindOfClass:[UIFont class]]) {
                           found = value;
                           *stop = YES;
                         }
                       }];
  return found;
}

#pragma mark - Drawing

- (void)drawPill:(CGRect)rect
         isFirst:(BOOL)isFirst
          isLast:(BOOL)isLast
          radius:(CGFloat)radius
            fill:(nullable RCTUIColor *)fill
          border:(nullable RCTUIColor *)border
{
  // Stroke on the half-pixel line inside the rect, so the 1 pt border stays
  // within the pill's measured height.
  CGRect inner = CGRectInset(rect, kPillBorderWidth / 2.0, kPillBorderWidth / 2.0);
  UIBezierPath *shape = [self pathForRect:inner isFirst:isFirst isLast:isLast radius:radius];
  if (fill) {
    [fill setFill];
    [shape fill];
  }
  if (border) {
    [border setStroke];
    UIBezierPath *stroke =
        (isFirst && isLast) ? shape : [self openBorderPathForRect:inner isFirst:isFirst isLast:isLast radius:radius];
    stroke.lineWidth = kPillBorderWidth;
    BezierPathSetRoundStyle(stroke);
    [stroke stroke];
  }
}

- (UIBezierPath *)pathForRect:(CGRect)rect isFirst:(BOOL)isFirst isLast:(BOOL)isLast radius:(CGFloat)radius
{
#if !TARGET_OS_OSX
  UIRectCorner corners = 0;
  if (isFirst)
    corners |= (UIRectCornerTopLeft | UIRectCornerBottomLeft);
  if (isLast)
    corners |= (UIRectCornerTopRight | UIRectCornerBottomRight);
  return [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:corners cornerRadii:CGSizeMake(radius, radius)];
#else
  return UIBezierPathWithRoundedRect(rect, (isFirst || isLast) ? radius : 0);
#endif
}

/// The border of one line's piece of a wrapped pill: closed and rounded at the
/// dose's start or end, open on the side where the line breaks.
- (UIBezierPath *)openBorderPathForRect:(CGRect)rect isFirst:(BOOL)isFirst isLast:(BOOL)isLast radius:(CGFloat)r
{
  UIBezierPath *path = [UIBezierPath bezierPath];
  CGFloat minX = CGRectGetMinX(rect), maxX = CGRectGetMaxX(rect);
  CGFloat minY = CGRectGetMinY(rect), maxY = CGRectGetMaxY(rect);
  if (isFirst) {
    [path moveToPoint:CGPointMake(maxX, minY)];
    BezierPathAddLine(path, CGPointMake(minX + r, minY));
    BezierPathAddQuadCurve(path, CGPointMake(minX, minY + r), CGPointMake(minX, minY));
    BezierPathAddLine(path, CGPointMake(minX, maxY - r));
    BezierPathAddQuadCurve(path, CGPointMake(minX + r, maxY), CGPointMake(minX, maxY));
    BezierPathAddLine(path, CGPointMake(maxX, maxY));
  } else if (isLast) {
    [path moveToPoint:CGPointMake(minX, minY)];
    BezierPathAddLine(path, CGPointMake(maxX - r, minY));
    BezierPathAddQuadCurve(path, CGPointMake(maxX, minY + r), CGPointMake(maxX, minY));
    BezierPathAddLine(path, CGPointMake(maxX, maxY - r));
    BezierPathAddQuadCurve(path, CGPointMake(maxX - r, maxY), CGPointMake(maxX, maxY));
    BezierPathAddLine(path, CGPointMake(minX, maxY));
  } else {
    [path moveToPoint:CGPointMake(minX, minY)];
    BezierPathAddLine(path, CGPointMake(maxX, minY));
    [path moveToPoint:CGPointMake(minX, maxY)];
    BezierPathAddLine(path, CGPointMake(maxX, maxY));
  }
  return path;
}

@end
