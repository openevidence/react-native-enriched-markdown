#import "DoseSpacerAttachment.h"

static const CGFloat kSpacerBaseFontSize = 17.0;

@implementation DoseSpacerAttachment {
  CGFloat _baseWidth;
}

- (instancetype)initWithBaseWidth:(CGFloat)baseWidth
{
  self = [super initWithData:nil ofType:nil];
  if (self) {
    _baseWidth = baseWidth;
  }
  return self;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)glyphPosition
                            characterIndex:(NSUInteger)characterIndex
{
  UIFont *font = nil;
  NSTextStorage *storage = textContainer.layoutManager.textStorage;
  if (storage && characterIndex < storage.length) {
    font = [storage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
  }
  CGFloat scale = (font ? font.pointSize : kSpacerBaseFontSize) / kSpacerBaseFontSize;
  return CGRectMake(0, 0, _baseWidth * scale, 0.01);
}

#if !TARGET_OS_OSX
- (UIImage *)imageForBounds:(CGRect)imageBounds
              textContainer:(NSTextContainer *)textContainer
             characterIndex:(NSUInteger)charIndex
{
  // A clear image, or UIKit draws its placeholder for an attachment without one.
  static UIImage *clear = nil;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    clear = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1)]
        imageWithActions:^(UIGraphicsImageRendererContext *ctx){
        }];
  });
  return clear;
}
#endif

@end
