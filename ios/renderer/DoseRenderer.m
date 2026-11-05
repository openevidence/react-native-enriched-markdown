#import "DoseRenderer.h"
#import "DoseIconAttachment.h"
#import "DoseSpacerAttachment.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

// The amber pill's padding beside 17 pt text, from Daniel's Nov 4 mock (15 px
// text: 12.5 px before the words, 9 px before the icon, 10.5 px after it).
static const CGFloat kPillPaddingStart = 13.0;
static const CGFloat kPillIconGap = 10.0;
static const CGFloat kPillPaddingEnd = 12.0;

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
  NSString *doseId = node.attributes[@"id"] ?: @"";
  // Without an id to open, the dose stays plain text.
  if (doseId.length == 0) {
    [_rendererFactory renderChildrenOfNode:node into:output context:context];
    return;
  }
  BOOL amber = [node.attributes[@"state"] isEqualToString:@"amber"];
  BOOL hasCalculator = [node.attributes[@"calc"] isEqualToString:@"1"];

  // An amber dose's pill opens with padding before its words. It goes in
  // before the words are rendered, so nothing the children register (links,
  // citations) ever shifts; it takes the words' font once they exist.
  NSUInteger start = output.length;
  if (amber) {
    [output appendAttributedString:[self spacerWithWidth:kPillPaddingStart textAttributes:@{}]];
    [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2060"
                                                                   attributes:[self decorationAttributesFrom:@{}]]];
  }
  NSUInteger textStart = output.length;
  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSRange textRange = NSMakeRange(textStart, output.length - textStart);
  // Without words to mark, the dose stays plain text (and loses its padding,
  // which nothing follows yet).
  if (textRange.length == 0) {
    [output deleteCharactersInRange:NSMakeRange(start, textStart - start)];
    return;
  }

  NSDictionary *textAttributes = [output attributesAtIndex:NSMaxRange(textRange) - 1 effectiveRange:NULL];
  NSString *words = [[output.string substringWithRange:textRange]
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  if (amber) {
    NSDictionary *firstAttributes = [output attributesAtIndex:textStart effectiveRange:NULL];
    [output addAttributes:[self decorationAttributesFrom:firstAttributes] range:NSMakeRange(start, textStart - start)];
    [self finishAmberPillFrom:start textAttributes:textAttributes doseId:doseId into:output];
  } else {
    [self decorateCheckedTextRange:textRange
                            doseId:doseId
                     hasCalculator:hasCalculator
                    textAttributes:textAttributes
                              into:output];
  }

  NSString *label = node.attributes[@"label"];
  NSString *spoken = label.length > 0 ? [NSString stringWithFormat:@"%@, %@", words, label] : words;
  [context registerDoseRange:NSMakeRange(start, output.length - start) doseId:doseId accessibilityLabel:spoken];
}

/// A checked dose: a dotted underline in the check's colour under the exact
/// words, then the check and (when the source has rules) calculator tiles.
- (void)decorateCheckedTextRange:(NSRange)textRange
                          doseId:(NSString *)doseId
                   hasCalculator:(BOOL)hasCalculator
                  textAttributes:(NSDictionary *)textAttributes
                            into:(NSMutableAttributedString *)output
{
  RCTUIColor *markColor = _config.doseCheckColor;

  // The mark whose card is open: its words get a tint of the open icon's
  // colour, the open icon a ring and the other icon fades.
  BOOL active = _config.doseActiveId.length > 0 && [_config.doseActiveId isEqualToString:doseId];
  BOOL calculatorActive = active && hasCalculator && [_config.doseActiveTarget isEqualToString:@"calculator"];

  // At rest the mark is a dotted underline in its colour; while its card is
  // open the line turns solid in the open icon's colour (Daniel v2 pp. 3-5).
  RCTUIColor *activeColor = calculatorActive ? _config.doseCalculatorColor : markColor;
  [output addAttribute:NSUnderlineStyleAttributeName
                 value:active ? @(NSUnderlineStyleSingle) : @(NSUnderlineStyleSingle | NSUnderlinePatternDot)
                 range:textRange];
  [output addAttribute:NSUnderlineColorAttributeName value:active ? activeColor : markColor range:textRange];
  if (active) {
    [output addAttribute:NSBackgroundColorAttributeName
                   value:[activeColor colorWithAlphaComponent:_config.doseActiveBackgroundOpacity]
                   range:textRange];
  }

  ENRMDoseIconState markState = !active ? ENRMDoseIconStateNormal
                                        : (calculatorActive ? ENRMDoseIconStateDimmed : ENRMDoseIconStateActive);
  ENRMDoseIconState calculatorState = !active ? ENRMDoseIconStateNormal
                                              : (calculatorActive ? ENRMDoseIconStateActive : ENRMDoseIconStateDimmed);

  [self appendIcon:ENRMDoseIconKindCheck
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
}

/// An amber dose, as in Daniel's Nov 4 mock: its words and a round person
/// icon inside a bordered pill, with no underline. The pill's padding is two
/// spacers held to the words by word joiners, so the text system keeps room
/// for it and a wrap never strands the padding or the icon; the layout
/// manager draws the pill itself (DosePillBackground). Its look doesn't change
/// while the card is open, as in his hover-open mock.
- (void)finishAmberPillFrom:(NSUInteger)pillStart
             textAttributes:(NSDictionary *)textAttributes
                     doseId:(NSString *)doseId
                       into:(NSMutableAttributedString *)output
{
  [self appendIcon:ENRMDoseIconKindPerson
                 gap:kPillIconGap
          appearance:[self appearanceWithColor:_config.doseAmberColor state:ENRMDoseIconStateNormal]
      textAttributes:textAttributes
                into:output];
  [output appendAttributedString:[[NSAttributedString alloc]
                                     initWithString:@"\u2060"
                                         attributes:[self decorationAttributesFrom:textAttributes]]];
  [output appendAttributedString:[self spacerWithWidth:kPillPaddingEnd textAttributes:textAttributes]];

  [output addAttribute:ENRMDosePillAttributeName value:doseId range:NSMakeRange(pillStart, output.length - pillStart)];
}

- (NSMutableAttributedString *)spacerWithWidth:(CGFloat)width textAttributes:(NSDictionary *)textAttributes
{
  DoseSpacerAttachment *spacer = [[DoseSpacerAttachment alloc] initWithBaseWidth:width];
  NSMutableAttributedString *string = [[NSMutableAttributedString alloc]
      initWithAttributedString:[NSAttributedString attributedStringWithAttachment:spacer]];
  [string addAttributes:[self decorationAttributesFrom:textAttributes] range:NSMakeRange(0, string.length)];
  return string;
}

/// The words' font and paragraph style, marked as decoration: copy and
/// VoiceOver skip it, and it never changes the line's spacing.
- (NSDictionary *)decorationAttributesFrom:(NSDictionary *)textAttributes
{
  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
  if (textAttributes[NSFontAttributeName]) {
    attributes[NSFontAttributeName] = textAttributes[NSFontAttributeName];
  }
  if (textAttributes[NSParagraphStyleAttributeName]) {
    attributes[NSParagraphStyleAttributeName] = textAttributes[NSParagraphStyleAttributeName];
  }
  attributes[ENRMDoseDecorationAttributeName] = @YES;
  return attributes;
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
  // The icon takes the text's font, so it scales with Dynamic Type, and its
  // paragraph style, so it doesn't change the line's spacing.
  NSDictionary *attributes = [self decorationAttributesFrom:textAttributes];

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
