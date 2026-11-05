#import "DoseRenderer.h"
#import "DoseIconAttachment.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

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
  BOOL hasCalculator = [node.attributes[@"calc"] isEqualToString:@"1"];
  ENRMDoseIconKind markKind = amber ? ENRMDoseIconKindPerson : ENRMDoseIconKindCheck;
  RCTUIColor *markColor = amber ? _config.doseAmberColor : _config.doseCheckColor;

  // The mark whose card is open: its words get a tint of the open icon's
  // colour, the open icon a ring and the other icon fades.
  BOOL active = _config.doseActiveId.length > 0 && [_config.doseActiveId isEqualToString:doseId];
  BOOL calculatorActive = active && hasCalculator && [_config.doseActiveTarget isEqualToString:@"calculator"];

  [output addAttribute:NSUnderlineStyleAttributeName
                 value:@(NSUnderlineStyleSingle | NSUnderlinePatternDot)
                 range:textRange];
  [output addAttribute:NSUnderlineColorAttributeName value:markColor range:textRange];
  if (active) {
    RCTUIColor *tint = calculatorActive ? _config.doseCalculatorColor : markColor;
    [output addAttribute:NSBackgroundColorAttributeName
                   value:[tint colorWithAlphaComponent:_config.doseActiveBackgroundOpacity]
                   range:textRange];
  }

  ENRMDoseIconState markState = !active ? ENRMDoseIconStateNormal
                                        : (calculatorActive ? ENRMDoseIconStateDimmed : ENRMDoseIconStateActive);
  ENRMDoseIconState calculatorState = !active ? ENRMDoseIconStateNormal
                                              : (calculatorActive ? ENRMDoseIconStateActive : ENRMDoseIconStateDimmed);

  NSDictionary *textAttributes = [output attributesAtIndex:NSMaxRange(textRange) - 1 effectiveRange:NULL];
  [self appendIcon:markKind
                 gap:_config.doseIconGap
          appearance:[self appearanceWithColor:markColor state:markState]
      textAttributes:textAttributes
                into:output];
  if (hasCalculator) {
    [self appendIcon:ENRMDoseIconKindCalculator
                   gap:_config.doseIconGap
            appearance:[self appearanceWithColor:_config.doseCalculatorColor state:calculatorState]
        textAttributes:textAttributes
                  into:output];
  }

  NSString *words = [[output.string substringWithRange:textRange]
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *label = node.attributes[@"label"];
  NSString *spoken = label.length > 0 ? [NSString stringWithFormat:@"%@, %@", words, label] : words;

  [context registerDoseRange:NSMakeRange(start, output.length - start) doseId:doseId accessibilityLabel:spoken];
}

- (DoseIconAppearance *)appearanceWithColor:(RCTUIColor *)color state:(ENRMDoseIconState)state
{
  DoseIconAppearance *appearance = [[DoseIconAppearance alloc] init];
  appearance.tileColor = color;
  appearance.glyphColor = _config.doseGlyphColor;
  appearance.baseSize = _config.doseIconSize;
  appearance.baseCornerRadius = _config.doseIconBorderRadius;
  appearance.state = state;
  appearance.dimmedOpacity = _config.doseDimmedOpacity;
  return appearance;
}

- (void)appendIcon:(ENRMDoseIconKind)kind
                 gap:(CGFloat)gap
          appearance:(DoseIconAppearance *)appearance
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

  DoseIconAttachment *attachment = [[DoseIconAttachment alloc] initWithKind:kind leadingGap:gap appearance:appearance];
  NSMutableAttributedString *icon = [[NSMutableAttributedString alloc]
      initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
  [icon addAttributes:attributes range:NSMakeRange(0, icon.length)];
  [output appendAttributedString:icon];
}

@end
