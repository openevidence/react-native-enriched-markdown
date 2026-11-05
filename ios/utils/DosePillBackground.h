#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT const CGFloat ENRMDosePillBorderWidth;
FOUNDATION_EXPORT CGFloat ENRMDosePillHeight(CGFloat fontSize, CGFloat capHeight, CGFloat lineHeight);

@interface DosePillBackground : NSObject

- (instancetype)initWithConfig:(StyleConfig *)config;
- (void)drawBackgroundsForGlyphRange:(NSRange)glyphsToShow
                       layoutManager:(NSLayoutManager *)layoutManager
                       textContainer:(NSTextContainer *)textContainer
                             atPoint:(CGPoint)origin;

@end

NS_ASSUME_NONNULL_END
