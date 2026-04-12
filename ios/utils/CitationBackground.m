#import "CitationBackground.h"
#import "ENRMUIKit.h"

NSString *const CitationAttributeName = @"Citation";

static const CGFloat kChipHPad = 7.0;
static const CGFloat kChipVPad = 1.5;

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
  CGFloat containerWidth = textContainer.size.width;

  [textStorage enumerateAttribute:CitationAttributeName
                          inRange:NSMakeRange(0, textStorage.length)
                          options:0
                       usingBlock:^(id value, NSRange range, BOOL *stop) {
                         if (!value || range.length == 0)
                           return;
                         if (NSIntersectionRange(range, charRange).length == 0)
                           return;

                         [self drawChipForRange:range
                                 layoutManager:layoutManager
                                 textContainer:textContainer
                                   textStorage:textStorage
                                       atPoint:origin
                               backgroundColor:backgroundColor
                                  cornerRadius:cornerRadius
                                containerWidth:containerWidth];
                       }];
}

- (void)drawChipForRange:(NSRange)range
           layoutManager:(NSLayoutManager *)layoutManager
           textContainer:(NSTextContainer *)textContainer
             textStorage:(NSTextStorage *)textStorage
                 atPoint:(CGPoint)origin
         backgroundColor:(RCTUIColor *)backgroundColor
            cornerRadius:(CGFloat)cornerRadius
          containerWidth:(CGFloat)containerWidth
{
  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  if (glyphRange.location == NSNotFound || glyphRange.length == 0)
    return;

  CGRect textRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];

  // Compute chip height from capHeight (visible text height for uppercase/numbers)
  // instead of ascender-descender (which includes empty descender space).
  UIFont *font = [textStorage attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL];
  CGFloat visibleTextHeight = font ? font.capHeight : textRect.size.height * 0.7;
  CGFloat chipHeight = visibleTextHeight + kChipVPad * 2;

  // Center the chip vertically within the line fragment
  CGFloat lineH = textRect.size.height;
  CGFloat chipY = textRect.origin.y + origin.y + (lineH - chipHeight) / 2.0;

  // Horizontal: expand by padding but clamp to container bounds
  CGFloat chipX = textRect.origin.x + origin.x - kChipHPad;
  CGFloat chipW = textRect.size.width + kChipHPad * 2;

  // Clamp left edge so the chip is never clipped by the text container
  if (chipX < origin.x) {
    CGFloat overflow = origin.x - chipX;
    chipX = origin.x;
    chipW -= overflow;
  }
  // Clamp right edge
  if (chipX + chipW > origin.x + containerWidth) {
    chipW = origin.x + containerWidth - chipX;
  }

  CGRect chipRect = CGRectMake(chipX, chipY, chipW, chipHeight);

  UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:chipRect cornerRadius:cornerRadius];
  [backgroundColor setFill];
  [path fill];
}

@end
