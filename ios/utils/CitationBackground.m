#import "CitationBackground.h"
#import "ENRMUIKit.h"

NSString *const CitationAttributeName = @"Citation";

@implementation CitationBackground {
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
  RCTUIColor *backgroundColor = _config.citationBackgroundColor;
  if (!backgroundColor)
    return;

  NSTextStorage *textStorage = layoutManager.textStorage;
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphsToShow actualGlyphRange:NULL];
  if (charRange.location == NSNotFound || charRange.length == 0)
    return;

  CGFloat cornerRadius = [_config citationBorderRadius];

  [textStorage enumerateAttribute:CitationAttributeName
                          inRange:NSMakeRange(0, textStorage.length)
                          options:0
                       usingBlock:^(id value, NSRange range, BOOL *stop) {
                         if (!value || range.length == 0)
                           return;
                         if (NSIntersectionRange(range, charRange).length == 0)
                           return;

                         [self drawCitationBackgroundForRange:range
                                               layoutManager:layoutManager
                                               textContainer:textContainer
                                                     atPoint:origin
                                             backgroundColor:backgroundColor
                                                cornerRadius:cornerRadius];
                       }];
}

- (void)drawCitationBackgroundForRange:(NSRange)range
                         layoutManager:(NSLayoutManager *)layoutManager
                         textContainer:(NSTextContainer *)textContainer
                               atPoint:(CGPoint)origin
                       backgroundColor:(RCTUIColor *)backgroundColor
                          cornerRadius:(CGFloat)cornerRadius
{
  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  if (glyphRange.location == NSNotFound || glyphRange.length == 0)
    return;

  [layoutManager
      enumerateLineFragmentsForGlyphRange:glyphRange
                               usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *tc, NSRange lineRange,
                                            BOOL *stop) {
                                 NSRange intersect = NSIntersectionRange(lineRange, glyphRange);
                                 if (intersect.length == 0)
                                   return;

                                 CGRect textRect = [layoutManager boundingRectForGlyphRange:intersect
                                                                            inTextContainer:textContainer];
                                 CGRect finalRect = CGRectMake(textRect.origin.x + origin.x,
                                                               textRect.origin.y + origin.y,
                                                               textRect.size.width,
                                                               textRect.size.height);

                                 UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:finalRect
                                                                                 cornerRadius:cornerRadius];
                                 [backgroundColor setFill];
                                 [path fill];
                               }];
}

@end
