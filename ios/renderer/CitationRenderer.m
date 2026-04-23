#import "CitationRenderer.h"
#import "CitationChipAttachment.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

@implementation CitationRenderer {
  RendererFactory *_rendererFactory;
  StyleConfig *_config;
}

- (instancetype)initWithRendererFactory:(id)rendererFactory config:(id)config
{
  self = [super init];
  if (self) {
    _rendererFactory = rendererFactory;
    _config = (StyleConfig *)config;
  }
  return self;
}

#pragma mark - Rendering

- (void)renderNode:(MarkdownASTNode *)node into:(NSMutableAttributedString *)output context:(RenderContext *)context
{
  NSString *displayText = node.content ?: @"";
  NSString *numbers = node.attributes[@"numbers"] ?: displayText;
  NSString *faviconUrl = node.attributes[@"faviconUrl"] ?: @"";

  if (displayText.length == 0)
    return;

  // Insert a leading space when the preceding content doesn't already end with
  // whitespace. The space gives the chip inline-word separation mid-line, and
  // TextKit naturally collapses trailing whitespace at wrap boundaries — so a
  // wrapped chip starts the new line flush with its leading edge, regardless
  // of paragraph indent (bullets, nested lists, etc.).
  NSDictionary *surroundingAttrs = nil;
  if (output.length > 0) {
    surroundingAttrs = [output attributesAtIndex:output.length - 1 effectiveRange:NULL];
    unichar lastChar = [output.string characterAtIndex:output.length - 1];
    if (![[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:lastChar]) {
      [output appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:surroundingAttrs]];
    }
  }

  NSUInteger start = output.length;

  // Create chip attachment (direct CoreGraphics drawing, no UIView)
  CitationChipAttachment *attachment = [[CitationChipAttachment alloc] initWithLabel:displayText
                                                                          faviconUrl:faviconUrl
                                                                             numbers:numbers
                                                                              config:_config];

  NSMutableAttributedString *attachmentStr = [[NSMutableAttributedString alloc]
      initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];

  // Inherit font (and other typographic attributes) from the preceding text so
  // attachmentBoundsForTextContainer: can read the actual surrounding font to
  // scale the chip. Without this, the attachment character carries no font
  // attribute and the chip falls back to the baseline surrounding font size.
  if (surroundingAttrs) {
    UIFont *font = surroundingAttrs[NSFontAttributeName];
    if (font) {
      [attachmentStr addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, attachmentStr.length)];
    }
    NSParagraphStyle *paragraphStyle = surroundingAttrs[NSParagraphStyleAttributeName];
    if (paragraphStyle) {
      [attachmentStr addAttribute:NSParagraphStyleAttributeName
                            value:paragraphStyle
                            range:NSMakeRange(0, attachmentStr.length)];
    }
  }

  // Store text-for-copy as a custom attribute for clipboard substitution
  [attachmentStr addAttribute:@"CitationCopyText"
                        value:[attachment textForCopy]
                        range:NSMakeRange(0, attachmentStr.length)];

  [output appendAttributedString:attachmentStr];

  NSRange range = NSMakeRange(start, output.length - start);
  if (range.length == 0)
    return;

  [context registerCitationRange:range numbers:numbers];
}

@end
