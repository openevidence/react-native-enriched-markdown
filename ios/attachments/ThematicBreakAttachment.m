#import "ThematicBreakAttachment.h"

@implementation ThematicBreakAttachment

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex
{
  CGFloat totalHeight = self.marginTop + self.lineHeight + self.marginBottom;
  return CGRectMake(0, 0, CGRectGetWidth(lineFrag), totalHeight);
}

- (RCTUIImage *)imageForBounds:(CGRect)imageBounds
                 textContainer:(NSTextContainer *)textContainer
                characterIndex:(NSUInteger)charIndex
{
  // Respect the foreground-color alpha at our character index so the divider
  // fades in together with surrounding text during streaming animation.
  CGFloat alpha = 1.0;
  NSTextStorage *storage = textContainer.layoutManager.textStorage;
  if (storage && charIndex < storage.length) {
    RCTUIColor *fgColor = [storage attribute:NSForegroundColorAttributeName atIndex:charIndex effectiveRange:NULL];
    if (fgColor) {
      [fgColor getRed:NULL green:NULL blue:NULL alpha:&alpha];
    }
  }

  RCTUIColor *drawColor = [self.lineColor colorWithAlphaComponent:alpha];

  RCTUIGraphicsImageRenderer *renderer = [[RCTUIGraphicsImageRenderer alloc] initWithSize:imageBounds.size];

  return [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *_Nonnull rendererContext) {
    CGContextRef ctx = rendererContext.CGContext;

    CGFloat lineY = self.marginTop + (self.lineHeight / 2.0);

    [drawColor setStroke];
    CGContextSetLineWidth(ctx, self.lineHeight);
    CGContextMoveToPoint(ctx, 0, lineY);
    CGContextAddLineToPoint(ctx, imageBounds.size.width, lineY);
    CGContextStrokePath(ctx);
  }];
}

@end
