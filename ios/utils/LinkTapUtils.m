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

NSString *_Nullable doseIdAtTapLocation(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer,
                                        NSString *_Nullable *_Nullable outTarget)
{
  NSUInteger characterIndex = ENRMCharacterIndexForTap(textView, recognizer);
  if (characterIndex == NSNotFound)
    return nil;

  NSAttributedString *attrText = ENRMGetAttributedText(textView);
  NSString *doseId = [attrText attribute:ENRMDoseIdAttributeName atIndex:characterIndex effectiveRange:NULL];
  if (doseId && outTarget) {
    // An icon is a word joiner followed by the attachment, both marked as
    // decoration; a tap on either one is a tap on that icon.
    NSString *target = @"text";
    NSUInteger end = MIN(characterIndex + 2, attrText.length);
    for (NSUInteger i = characterIndex; i < end; i++) {
      id attachment = [attrText attribute:NSAttachmentAttributeName atIndex:i effectiveRange:NULL];
      if ([attachment isKindOfClass:[DoseIconAttachment class]]) {
        target = ((DoseIconAttachment *)attachment).kind == ENRMDoseIconKindCalculator ? @"calculator" : @"check";
        break;
      }
      if (![attrText attribute:ENRMDoseDecorationAttributeName atIndex:i effectiveRange:NULL])
        break;
    }
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
