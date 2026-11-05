#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ENRMDoseIconKind) {
  ENRMDoseIconKindCheck,
  ENRMDoseIconKindPerson,
  ENRMDoseIconKindCalculator,
};

typedef NS_ENUM(NSInteger, ENRMDoseIconState) {
  ENRMDoseIconStateNormal,
  ENRMDoseIconStateActive,
  ENRMDoseIconStateDimmed,
};

@interface DoseIconAppearance : NSObject
@property (nonatomic, strong) RCTUIColor *tileColor;
@property (nonatomic, strong) RCTUIColor *glyphColor;
@property (nonatomic, assign) CGFloat baseSize;
@property (nonatomic, assign) CGFloat baseCornerRadius;
@property (nonatomic, assign) ENRMDoseIconState state;
@property (nonatomic, assign) CGFloat dimmedOpacity;
@end

@interface DoseIconAttachment : NSTextAttachment

- (instancetype)initWithKind:(ENRMDoseIconKind)kind
                  leadingGap:(CGFloat)leadingGap
                  appearance:(DoseIconAppearance *)appearance;

@property (nonatomic, readonly) ENRMDoseIconKind kind;

@end

NS_ASSUME_NONNULL_END
