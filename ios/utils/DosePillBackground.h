#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Draws the pill an amber dose sits in (Daniel's Nov 4 mock): a rounded box
 * with a 1 pt border around every character marked with
 * ENRMDosePillAttributeName (its padding, words and person icon). A pill cut
 * by a line wrap keeps its rounded, closed ends at the dose's start and end
 * and leaves its border open where the line breaks, like inline code.
 */
@interface DosePillBackground : NSObject

- (instancetype)initWithConfig:(StyleConfig *)config;
- (void)drawBackgroundsForGlyphRange:(NSRange)glyphsToShow
                       layoutManager:(NSLayoutManager *)layoutManager
                       textContainer:(NSTextContainer *)textContainer
                             atPoint:(CGPoint)origin;

@end

NS_ASSUME_NONNULL_END
