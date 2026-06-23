#import "ENRMMathInlineAttachmentShared.h"

#if ENRICHED_MARKDOWN_MATH

@implementation ENRMMathInlineAttachment

#if !TARGET_OS_OSX

- (void)prepareIfNeeded
{
  if (_displayList)
    return;

  MTMathUILabel *mathLabel = [[MTMathUILabel alloc] init];
  mathLabel.labelMode = self.displayMode ? kMTMathUILabelModeDisplay : kMTMathUILabelModeText;
  mathLabel.textAlignment = kMTTextAlignmentLeft;
  mathLabel.fontSize = self.fontSize;
  mathLabel.latex = self.latex;

  if (self.mathTextColor) {
    mathLabel.textColor = self.mathTextColor;
  }

  [mathLabel layoutIfNeeded];

  _displayList = mathLabel.displayList;
  if (_displayList) {
    _mathAscent = _displayList.ascent;
    _mathDescent = _displayList.descent;
    _cachedSize = CGSizeMake(_displayList.width, _mathAscent + _mathDescent);
  }
}

- (CGFloat)scaleForAvailableWidth:(CGFloat)availableWidth
{
  if (!self.scaleToFit || _cachedSize.width <= 0 || availableWidth <= 0 || _cachedSize.width <= availableWidth) {
    return 1.0;
  }
  return availableWidth / _cachedSize.width;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  [self prepareIfNeeded];

  CGFloat availableWidth = lineFragment.size.width > 0 ? lineFragment.size.width : textContainer.size.width;
  CGFloat scale = [self scaleForAvailableWidth:availableWidth];
  CGSize scaledSize = CGSizeMake(_cachedSize.width * scale, _cachedSize.height * scale);
  CGFloat scaledDescent = _mathDescent * scale;

  return CGRectMake(0, -scaledDescent, scaledSize.width, scaledSize.height);
}

- (UIImage *)imageForBounds:(CGRect)imageBounds
              textContainer:(NSTextContainer *)textContainer
             characterIndex:(NSUInteger)characterIndex
{
  [self prepareIfNeeded];

  if (!_displayList)
    return nil;

  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.opaque = NO;

  CGSize imageSize = imageBounds.size;
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    imageSize = _cachedSize;
  }

  CGFloat scale = _cachedSize.width > 0 ? imageSize.width / _cachedSize.width : 1.0;

  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:imageSize format:format];

  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
    CGContextRef ctx = rendererContext.CGContext;

    CGContextSaveGState(ctx);

    CGContextTranslateCTM(ctx, 0, imageSize.height);
    CGContextScaleCTM(ctx, scale, -scale);
    _displayList.position = CGPointMake(0, _mathDescent);

    [_displayList draw:ctx];

    CGContextRestoreGState(ctx);
  }];
}

#endif

@end

#endif
