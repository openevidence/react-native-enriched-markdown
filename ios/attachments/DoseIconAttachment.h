#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ENRMDoseIconKind) {
  /// Green: the cited source gives this dose for a patient like this one.
  ENRMDoseIconKindCheck,
  /// Amber: the source gives this dose for a different patient group.
  ENRMDoseIconKindPerson,
  /// Orange: the source has a rule a calculator can compute from.
  ENRMDoseIconKindCalculator,
};

/**
 * NSTextAttachment that draws one dose check icon inline: a rounded square in
 * the mark's colour with a white glyph, sized to the surrounding text the way
 * CitationChipAttachment sizes its chip. Drawn with CoreGraphics and cached by
 * kind and size; no UIView is created.
 */
@interface DoseIconAttachment : NSTextAttachment

- (instancetype)initWithKind:(ENRMDoseIconKind)kind leadingGap:(CGFloat)leadingGap;

@property (nonatomic, readonly) ENRMDoseIconKind kind;

/// The colour of a mark of this kind; the dose underline uses the same one.
+ (RCTUIColor *)colorForKind:(ENRMDoseIconKind)kind;

@end

NS_ASSUME_NONNULL_END
