#import "CitationRenderer.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

static const CGFloat kPlaceholderWidth = 90.0;
static const CGFloat kPlaceholderHeight = 20.0;

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
  NSString *numbers = node.attributes[@"numbers"] ?: node.content ?: @"";
  if (numbers.length == 0)
    return;

  NSDictionary *blockAttrs = [context getTextAttributes];

  // Small leading space (outside attachment)
  [output appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:blockAttrs]];

  NSUInteger start = output.length;

  // Create placeholder attachment with fixed chip dimensions
  NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
  // Create a transparent 1x1 image so the attachment renders as empty space
#if !TARGET_OS_OSX
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0);
  UIImage *transparentImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  attachment.image = transparentImage;
#else
  NSImage *transparentImage = [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
  attachment.image = transparentImage;
#endif

  // Set bounds: verticalOffset centers the attachment with the text baseline
  UIFont *font = blockAttrs[NSFontAttributeName];
  CGFloat yOffset = font ? (font.capHeight - kPlaceholderHeight) / 2.0 : -4.0;
  attachment.bounds = CGRectMake(0, yOffset, kPlaceholderWidth, kPlaceholderHeight);

  NSAttributedString *attachmentStr = [NSAttributedString attributedStringWithAttachment:attachment];
  [output appendAttributedString:attachmentStr];

  NSRange range = NSMakeRange(start, output.length - start);

  // Register for citation tracking (used to compute frames after layout)
  [context registerCitationRange:range numbers:numbers];

  // Small trailing space
  [output appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:blockAttrs]];
}

@end
