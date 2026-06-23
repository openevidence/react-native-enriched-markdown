#import "ENRMMathDisplayRenderer.h"
#import "ENRMMathInlineAttachment.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

#import "ENRMFeatureFlags.h"

#if ENRICHED_MARKDOWN_MATH

@implementation ENRMMathDisplayRenderer {
  RendererFactory *_rendererFactory;
  StyleConfig *_config;
}

- (instancetype)initWithRendererFactory:(id)rendererFactory config:(id)config
{
  if (self = [super init]) {
    _rendererFactory = rendererFactory;
    _config = (StyleConfig *)config;
  }
  return self;
}

- (void)renderNode:(MarkdownASTNode *)node into:(NSMutableAttributedString *)output context:(RenderContext *)context
{
  NSString *latex = [self extractLatexFromNode:node];
  if (latex.length == 0) {
    return;
  }

  if (output.length > 0 && ![output.string hasSuffix:@"\n"]) {
    [output appendAttributedString:kNewlineAttributedString];
  }

  applyBlockSpacingBefore(output, output.length, _config.mathMarginTop);

  ENRMMathInlineAttachment *attachment = [[ENRMMathInlineAttachment alloc] init];
  attachment.latex = latex;
  attachment.fontSize = _config.mathFontSize;
  attachment.mathTextColor = _config.mathColor ?: _config.paragraphColor;
  attachment.displayMode = YES;
  attachment.scaleToFit = YES;

  NSUInteger attachmentStart = output.length;
  NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
  [output appendAttributedString:attachmentString];

  NSRange blockRange = NSMakeRange(attachmentStart, output.length - attachmentStart);
  applyTextAlignment(output, blockRange, textAlignmentFromString(_config.mathTextAlign));
  applyParagraphSpacingAfter(output, attachmentStart, _config.mathMarginBottom);
}

- (NSString *)extractLatexFromNode:(MarkdownASTNode *)node
{
  if (node.content.length > 0) {
    return node.content;
  }

  NSMutableString *buffer = [NSMutableString string];
  for (MarkdownASTNode *child in node.children) {
    if (child.content.length > 0) {
      [buffer appendString:child.content];
    }
  }
  return buffer;
}

@end

#endif
