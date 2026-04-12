#import "CitationRenderer.h"
#import "CitationChipAttachment.h"
#import "CitationChipView.h"
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

  NSDictionary *blockAttrs = [context getTextAttributes];

  // ── Create the chip view and attachment ──
  CitationChipView *chipView = [[CitationChipView alloc] initWithLabel:displayText
                                                            faviconUrl:faviconUrl];
  CitationChipAttachment *attachment = [[CitationChipAttachment alloc] initWithChipView:chipView];

  // ── Build the attachment string ──
  NSMutableAttributedString *attachmentStr =
      [[NSMutableAttributedString alloc] initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];

  // Apply the surrounding block font so vertical alignment calculations work
  [attachmentStr addAttributes:blockAttrs range:NSMakeRange(0, attachmentStr.length)];

  // Record the range for tap handling
  NSUInteger start = output.length;
  [output appendAttributedString:attachmentStr];
  NSRange range = NSMakeRange(start, output.length - start);

  if (range.length > 0) {
    [context registerCitationRange:range numbers:numbers];
  }
}

@end
