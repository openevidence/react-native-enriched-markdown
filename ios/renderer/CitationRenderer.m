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

  // 1. Render citation text using the block's text attributes (same as TextRenderer).
  //    This ensures the citation uses the correct font, paragraph style, and baseline
  //    from the surrounding block context.
  NSAttributedString *text = [[NSAttributedString alloc] initWithString:numbers
                                                             attributes:[context getTextAttributes]];
  [output appendAttributedString:text];

  NSRange range = NSMakeRange(start, output.length - start);
  if (range.length == 0)
    return;

  // 2. Overlay citation-specific styling on top of the block attributes.
  RCTUIColor *citationColor = [_config citationColor];
  if (citationColor) {
    [output addAttribute:NSForegroundColorAttributeName value:citationColor range:range];
  }
  [output addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleNone) range:range];
  [output addAttribute:CitationAttributeName value:@YES range:range];

  // 3. Apply citation-specific font size if configured (otherwise keep block font).
  CGFloat citationFontSize = [_config citationFontSize];
  if (citationFontSize > 0) {
    [output enumerateAttribute:NSFontAttributeName
                       inRange:range
                       options:0
                    usingBlock:^(UIFont *font, NSRange subrange, BOOL *stop) {
                      if (font) {
                        UIFont *sizedFont = [font fontWithSize:citationFontSize];
                        [output addAttribute:NSFontAttributeName value:sizedFont range:subrange];
                      }
                    }];
  }

  // 4. Register for tap handling
  [context registerCitationRange:range numbers:numbers];
}

@end
