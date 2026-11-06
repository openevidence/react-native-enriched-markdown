#import "DoseRenderer.h"
#import "DoseIconAttachment.h"
#import "DoseSpacerAttachment.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

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
  if (doseId.length == 0) {
    [_rendererFactory renderChildrenOfNode:node into:output context:context];
    return;
  }
  BOOL amber = [node.attributes[@"state"] isEqualToString:@"amber"];
  // A dose shown before its check landed keeps its place: only an underline,
  // which takes no room, so nothing around it moves.
  BOOL late = [node.attributes[@"late"] isEqualToString:@"1"];
  BOOL hasCalculator = !late && [node.attributes[@"calc"] isEqualToString:@"1"];

  NSUInteger start = output.length;
  if (amber && !late) {
    // Inserted before the words render, so the ranges the children register never shift.
    [output appendAttributedString:[self spacerWithWidth:kPillPaddingStart textAttributes:@{}]];
    [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2060"
                                                                   attributes:[self decorationAttributesFrom:@{}]]];
  }
  NSUInteger textStart = output.length;
  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSRange textRange = NSMakeRange(textStart, output.length - textStart);
  if (textRange.length == 0) {
    [output deleteCharactersInRange:NSMakeRange(start, textStart - start)];
    return;
  }

  NSDictionary *textAttributes = [output attributesAtIndex:NSMaxRange(textRange) - 1 effectiveRange:NULL];
  NSString *words = [[output.string substringWithRange:textRange]
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  if (late) {
    [self decorateLateTextRange:textRange doseId:doseId amber:amber into:output];
  } else if (amber) {
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

- (void)decorateLateTextRange:(NSRange)textRange
                       doseId:(NSString *)doseId
                        amber:(BOOL)amber
                         into:(NSMutableAttributedString *)output
{
  RCTUIColor *color = amber ? _config.doseAmberColor : _config.doseCheckColor;
  BOOL active = _config.doseActiveId.length > 0 && [_config.doseActiveId isEqualToString:doseId];
  [output addAttribute:NSUnderlineStyleAttributeName
                 value:active ? @(NSUnderlineStyleSingle) : @(NSUnderlineStyleSingle | NSUnderlinePatternDot)
                 range:textRange];
  [output addAttribute:NSUnderlineColorAttributeName value:color range:textRange];
  if (active) {
    [output addAttribute:NSBackgroundColorAttributeName
                   value:[color colorWithAlphaComponent:_config.doseActiveBackgroundOpacity]
                   range:textRange];
  }
}

- (void)decorateCheckedTextRange:(NSRange)textRange
                          doseId:(NSString *)doseId
                   hasCalculator:(BOOL)hasCalculator
                  textAttributes:(NSDictionary *)textAttributes
                            into:(NSMutableAttributedString *)output
{
  RCTUIColor *markColor = _config.doseCheckColor;

  BOOL active = _config.doseActiveId.length > 0 && [_config.doseActiveId isEqualToString:doseId];
  BOOL calculatorActive = active && hasCalculator && [_config.doseActiveTarget isEqualToString:@"calculator"];

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
    DoseIconAppearance *calculatorAppearance = [self appearanceWithColor:_config.doseCalculatorColor
                                                                   state:calculatorState];
    calculatorAppearance.glyphColor = _config.doseCalculatorGlyphColor ?: _config.doseGlyphColor;
    [self appendIcon:ENRMDoseIconKindCalculator
                   gap:_config.doseIconGap
            appearance:calculatorAppearance
        textAttributes:textAttributes
                  into:output];
  }
}

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
  NSDictionary *attributes = [self decorationAttributesFrom:textAttributes];

  // U+2060 forbids a line break before the icon, so an icon never starts a line alone.
  [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2060" attributes:attributes]];

  DoseIconAttachment *attachment = [[DoseIconAttachment alloc] initWithKind:kind leadingGap:gap appearance:appearance];
  NSMutableAttributedString *icon = [[NSMutableAttributedString alloc]
      initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
  [icon addAttributes:attributes range:NSMakeRange(0, icon.length)];
  [output appendAttributedString:icon];
}

@end
