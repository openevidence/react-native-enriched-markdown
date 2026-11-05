#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ENRMDoseIconKind) {
  /// The source gives this dose for a patient like this one.
  ENRMDoseIconKindCheck,
  /// The source gives this dose for a different patient group.
  ENRMDoseIconKindPerson,
  /// The source has rules a calculator can compute from.
  ENRMDoseIconKindCalculator,
};

typedef NS_ENUM(NSInteger, ENRMDoseIconState) {
  ENRMDoseIconStateNormal,
  /// This icon's card is open: a ring around a lighter tile.
  ENRMDoseIconStateActive,
  /// The other icon of the same mark is open: drawn faded.
  ENRMDoseIconStateDimmed,
};

/// What the tile looks like; the renderer fills it from StyleConfig.
@interface DoseIconAppearance : NSObject
@property (nonatomic, strong) RCTUIColor *tileColor;
@property (nonatomic, strong) RCTUIColor *glyphColor;
/// Tile size and corner radius beside 17 pt text; scaled with the text.
@property (nonatomic, assign) CGFloat baseSize;
@property (nonatomic, assign) CGFloat baseCornerRadius;
@property (nonatomic, assign) ENRMDoseIconState state;
@property (nonatomic, assign) CGFloat dimmedOpacity;
@end

/**
 * NSTextAttachment that draws one dose check icon inline: a rounded tile in
 * the mark's colour with a glyph, sized to the surrounding text the way
 * CitationChipAttachment sizes its chip. Drawn with CoreGraphics and cached;
 * no UIView is created.
 */
@interface DoseIconAttachment : NSTextAttachment

- (instancetype)initWithKind:(ENRMDoseIconKind)kind
                  leadingGap:(CGFloat)leadingGap
                  appearance:(DoseIconAppearance *)appearance;

@property (nonatomic, readonly) ENRMDoseIconKind kind;

@end

NS_ASSUME_NONNULL_END
