#import "LinkTapUtils.h"
#import "DoseIconAttachment.h"
#import "ENRMSpoilerTapUtils.h"
#import "ENRMTextHitTest.h"
#import "RenderContext.h"

NSString *_Nullable linkURLAtTapLocation(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer)
{
  NSUInteger characterIndex = ENRMCharacterIndexForTap(textView, recognizer);
  if (characterIndex == NSNotFound)
    return nil;

  NSAttributedString *attrText = ENRMGetAttributedText(textView);
  return [attrText attribute:@"linkURL" atIndex:characterIndex effectiveRange:NULL];
}

NSString *_Nullable linkURLAtRange(ENRMPlatformTextView *textView, NSRange characterRange)
{
  NSAttributedString *attrText = ENRMGetAttributedText(textView);
  if (characterRange.location >= attrText.length) {
    return nil;
  }
  return [attrText attribute:@"linkURL" atIndex:characterRange.location effectiveRange:NULL];
}

NSString *_Nullable citationNumbersAtTapLocation(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer)
{
  NSUInteger characterIndex = ENRMCharacterIndexForTap(textView, recognizer);
  if (characterIndex == NSNotFound)
    return nil;

  NSAttributedString *attrText = ENRMGetAttributedText(textView);
  return [attrText attribute:@"citationNumbers" atIndex:characterIndex effectiveRange:NULL];
}

// How far outside an icon's own box a tap still counts as that icon, in points.
// The tiles are small (22 pt, 4 pt apart), so a finger landing near one should
// still hit it; where two tiles' margins overlap, the nearer tile wins.
static const CGFloat kDoseIconTapSlop = 8.0;

NSString *_Nullable doseIdAtTapLocation(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer,
                                        NSString *_Nullable *_Nullable outTarget)
{
  NSAttributedString *attrText = ENRMGetAttributedText(textView);
  CGPoint location = [recognizer locationInView:textView];
  CGPoint point = CGPointMake(location.x - textView.textContainerInset.left, location.y - textView.textContainerInset.top);
  NSUInteger characterIndex = ENRMCharacterIndexAtPoint(textView, location);
  if (characterIndex == NSNotFound)
    return nil;

  NSLayoutManager *layoutManager = textView.layoutManager;
  NSTextContainer *container = textView.textContainer;
  NSRange fullRange = NSMakeRange(0, attrText.length);
  NSRange doseRange = NSMakeRange(NSNotFound, 0);
  NSString *doseId = [attrText attribute:ENRMDoseIdAttributeName
                                  atIndex:characterIndex
                    longestEffectiveRange:&doseRange
                                  inRange:fullRange];
  // A tap on the right edge of a mark's last icon can resolve to the character
  // after the mark; count it when the point is still inside that icon's slop.
  if (!doseId && characterIndex > 0) {
    NSRange previousRange = NSMakeRange(NSNotFound, 0);
    NSString *previousId = [attrText attribute:ENRMDoseIdAttributeName
                                       atIndex:characterIndex - 1
                         longestEffectiveRange:&previousRange
                                       inRange:fullRange];
    if (previousId) {
      NSRange glyphs = [layoutManager glyphRangeForCharacterRange:NSMakeRange(characterIndex - 1, 1)
                                             actualCharacterRange:NULL];
      CGRect rect = [layoutManager boundingRectForGlyphRange:glyphs inTextContainer:container];
      if (CGRectContainsPoint(CGRectInset(rect, -kDoseIconTapSlop, -kDoseIconTapSlop), point)) {
        doseId = previousId;
        doseRange = previousRange;
      }
    }
  }
  if (!doseId)
    return nil;

  if (outTarget) {
    // Which icon the tap is on: the nearest icon whose box, widened by the
    // slop, holds the point. Elsewhere in the mark it is a tap on its words.
    __block NSString *target = @"text";
    __block CGFloat nearest = CGFLOAT_MAX;
    [attrText enumerateAttribute:NSAttachmentAttributeName
                         inRange:doseRange
                         options:0
                      usingBlock:^(id value, NSRange range, BOOL *stop) {
                        if (![value isKindOfClass:[DoseIconAttachment class]])
                          return;
                        NSRange glyphs = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
                        CGRect rect = [layoutManager boundingRectForGlyphRange:glyphs inTextContainer:container];
                        if (!CGRectContainsPoint(CGRectInset(rect, -kDoseIconTapSlop, -kDoseIconTapSlop), point))
                          return;
                        CGFloat distance = fabs(CGRectGetMidX(rect) - point.x);
                        if (distance < nearest) {
                          nearest = distance;
                          target = ((DoseIconAttachment *)value).kind == ENRMDoseIconKindCalculator ? @"calculator"
                                                                                                     : @"check";
                        }
                      }];
    *outTarget = target;
  }
  return doseId;
}

BOOL isPointOnInteractiveElement(ENRMPlatformTextView *textView, CGPoint point)
{
  NSUInteger charIndex = ENRMCharacterIndexAtPoint(textView, point);
  if (charIndex == NSNotFound)
    return NO;

  NSDictionary *attrs = [ENRMGetAttributedText(textView) attributesAtIndex:charIndex effectiveRange:NULL];
  return attrs[@"linkURL"] != nil || attrs[@"citationNumbers"] != nil || [attrs[@"TaskItem"] boolValue] ||
         attrs[SpoilerAttributeName] != nil || attrs[ENRMDoseIdAttributeName] != nil;
}
