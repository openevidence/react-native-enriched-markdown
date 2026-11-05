#import "DoseRenderer.h"
#import "DoseIconAttachment.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

// Space before the first icon and between icons, in points at 17 pt text
// (the spec: 4 px between the dose and its check, 4 px between icons).
static const CGFloat kGapBeforeFirstIcon = 4.0;
static const CGFloat kGapBetweenIcons = 4.0;

@implementation DoseRenderer {
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
  NSUInteger start = output.length;
  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSRange textRange = NSMakeRange(start, output.length - start);
  NSString *doseId = node.attributes[@"id"] ?: @"";
  // Without words to mark or an id to open, the dose stays plain text.
  if (textRange.length == 0 || doseId.length == 0)
    return;

  BOOL amber = [node.attributes[@"state"] isEqualToString:@"amber"];
  ENRMDoseIconKind markKind = amber ? ENRMDoseIconKindPerson : ENRMDoseIconKindCheck;
  RCTUIColor *markColor = [DoseIconAttachment colorForKind:markKind];

  [output addAttribute:NSUnderlineStyleAttributeName
                 value:@(NSUnderlineStyleSingle | NSUnderlinePatternDot)
                 range:textRange];
  [output addAttribute:NSUnderlineColorAttributeName value:markColor range:textRange];

  NSDictionary *textAttributes = [output attributesAtIndex:NSMaxRange(textRange) - 1 effectiveRange:NULL];
  [self appendIcon:markKind gap:kGapBeforeFirstIcon textAttributes:textAttributes into:output];
  if ([node.attributes[@"calc"] isEqualToString:@"1"]) {
    [self appendIcon:ENRMDoseIconKindCalculator gap:kGapBetweenIcons textAttributes:textAttributes into:output];
  }

  NSString *words = [[output.string substringWithRange:textRange]
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *label = node.attributes[@"label"];
  NSString *spoken = label.length > 0 ? [NSString stringWithFormat:@"%@, %@", words, label] : words;

  [context registerDoseRange:NSMakeRange(start, output.length - start) doseId:doseId accessibilityLabel:spoken];
}

- (void)appendIcon:(ENRMDoseIconKind)kind
                 gap:(CGFloat)gap
      textAttributes:(NSDictionary *)textAttributes
                into:(NSMutableAttributedString *)output
{
  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
  // The icon takes the text's font, so it scales with Dynamic Type, and its
  // paragraph style, so it doesn't change the line's spacing.
  if (textAttributes[NSFontAttributeName]) {
    attributes[NSFontAttributeName] = textAttributes[NSFontAttributeName];
  }
  if (textAttributes[NSParagraphStyleAttributeName]) {
    attributes[NSParagraphStyleAttributeName] = textAttributes[NSParagraphStyleAttributeName];
  }
  attributes[ENRMDoseDecorationAttributeName] = @YES;

  // A word joiner (U+2060) forbids a line break before the icon, so a mark
  // never leaves its icon alone at the start of the next line.
  [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2060" attributes:attributes]];

  DoseIconAttachment *attachment = [[DoseIconAttachment alloc] initWithKind:kind leadingGap:gap];
  NSMutableAttributedString *icon = [[NSMutableAttributedString alloc]
      initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
  [icon addAttributes:attributes range:NSMakeRange(0, icon.length)];
  [output appendAttributedString:icon];
}

@end
