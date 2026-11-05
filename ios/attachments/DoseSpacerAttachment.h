#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An invisible, zero-height attachment that only takes up width: the padding
 * inside an amber dose's pill. Its width is given beside 17 pt text and
 * scales with the surrounding font, so the pill keeps its proportions under
 * Dynamic Type.
 */
@interface DoseSpacerAttachment : NSTextAttachment

- (instancetype)initWithBaseWidth:(CGFloat)baseWidth;

@end

NS_ASSUME_NONNULL_END
