#import "CitationRenderer.h"
#import "CitationBackground.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

static const CGFloat kFaviconSize = 12.0;

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

  // ── Leading margin (outside chip range) ──
  NSAttributedString *leadingMargin = [[NSAttributedString alloc] initWithString:@"  " attributes:blockAttrs];
  [output appendAttributedString:leadingMargin];

  NSUInteger start = output.length;

  // ── Build citation attributes ──
  NSMutableDictionary *attrs = [blockAttrs mutableCopy];
  RCTUIColor *citationColor = [_config citationColor];
  if (citationColor) {
    attrs[NSForegroundColorAttributeName] = citationColor;
  }
  attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleNone);
  attrs[CitationAttributeName] = @YES;

  CGFloat citationFontSize = [_config citationFontSize];
  if (citationFontSize > 0) {
    UIFont *currentFont = attrs[NSFontAttributeName];
    if (currentFont) {
      attrs[NSFontAttributeName] = [currentFont fontWithSize:citationFontSize];
    }
  }

  // ── Favicon ──
  if (faviconUrl.length > 0) {
    NSTextAttachment *faviconAttachment = [[NSTextAttachment alloc] init];
    UIFont *font = attrs[NSFontAttributeName];
    CGFloat yOffset = font ? (font.capHeight - kFaviconSize) / 2.0 : -2.0;
    faviconAttachment.bounds = CGRectMake(0, yOffset, kFaviconSize, kFaviconSize);

    NSMutableAttributedString *iconStr =
        [[NSMutableAttributedString alloc] initWithAttributedString:[NSAttributedString attributedStringWithAttachment:faviconAttachment]];
    [iconStr addAttribute:CitationAttributeName value:@YES range:NSMakeRange(0, iconStr.length)];
    [output appendAttributedString:iconStr];

    // Gap after favicon: regular space with citation attrs so it gets chip background
    NSAttributedString *gap = [[NSAttributedString alloc] initWithString:@" " attributes:attrs];
    [output appendAttributedString:gap];

    // Async load favicon image
    NSURL *url = [NSURL URLWithString:faviconUrl];
    if (url) {
      __weak NSTextAttachment *weakAttachment = faviconAttachment;
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
          UIImage *image = [UIImage imageWithData:data];
          if (image) {
            dispatch_async(dispatch_get_main_queue(), ^{
              NSTextAttachment *strong = weakAttachment;
              if (strong) {
                strong.image = image;
              }
            });
          }
        }
      });
    }
  }

  // ── Label text ──
  NSAttributedString *labelStr = [[NSAttributedString alloc] initWithString:displayText attributes:attrs];
  [output appendAttributedString:labelStr];

  // Mark the full chip range for tap handling and background drawing
  NSRange range = NSMakeRange(start, output.length - start);
  if (range.length == 0)
    return;

  [context registerCitationRange:range numbers:numbers];

  // ── Trailing margin (outside chip range) ──
  NSAttributedString *trailingMargin = [[NSAttributedString alloc] initWithString:@"  " attributes:blockAttrs];
  [output appendAttributedString:trailingMargin];
}

@end
