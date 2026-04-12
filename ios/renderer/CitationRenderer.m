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

  NSUInteger start = output.length;

  // Create chip attachment (direct CoreGraphics drawing, no UIView)
  CitationChipAttachment *attachment = [[CitationChipAttachment alloc] initWithLabel:displayText
                                                                          faviconUrl:faviconUrl
                                                                             numbers:numbers];

  NSMutableAttributedString *attachmentStr =
      [[NSMutableAttributedString alloc] initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];

  // Store text-for-copy as a custom attribute for clipboard substitution
  [attachmentStr addAttribute:@"CitationCopyText" value:[attachment textForCopy] range:NSMakeRange(0, attachmentStr.length)];

  [output appendAttributedString:attachmentStr];

  NSRange range = NSMakeRange(start, output.length - start);
  if (range.length == 0)
    return;

  [context registerCitationRange:range numbers:numbers];
}

@end
