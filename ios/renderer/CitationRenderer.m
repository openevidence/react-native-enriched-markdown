#import "CitationRenderer.h"
#import "CitationBackground.h"
#import "FontUtils.h"
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
  NSString *numbers = node.content ?: @"";
  if (numbers.length == 0)
    return;

  NSUInteger start = output.length;

  // Build citation text from the numbers content
  BlockStyle *blockStyle = [context getBlockStyle];
  UIFont *blockFont = cachedFontFromBlockStyle(blockStyle, context);

  CGFloat fontSize = [_config citationFontSize] > 0 ? [_config citationFontSize] : blockStyle.fontSize;
  UIFont *citationFont = [UIFont systemFontOfSize:fontSize];
  if (!citationFont) {
    citationFont = blockFont;
  }

  RCTUIColor *citationColor = [_config citationColor] ?: blockStyle.color;

  NSDictionary *attributes = @{
    NSFontAttributeName : citationFont,
    NSForegroundColorAttributeName : citationColor,
    NSUnderlineStyleAttributeName : @(NSUnderlineStyleNone),
    CitationAttributeName : @YES,
  };

  NSAttributedString *citationString = [[NSAttributedString alloc] initWithString:numbers attributes:attributes];
  [output appendAttributedString:citationString];

  NSRange range = NSMakeRange(start, output.length - start);
  if (range.length == 0)
    return;

  // Register for tap handling
  [context registerCitationRange:range numbers:numbers];
}

@end
