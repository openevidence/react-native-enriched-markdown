#pragma once
#import "ENRMUIKit.h"

@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * NSTextAttachment that draws a citation chip inline using CoreGraphics.
 * No UIView hierarchy is created — drawing is done directly in imageForBounds:.
 * Chip images are cached globally by label + favicon state.
 */
@interface CitationChipAttachment : NSTextAttachment

- (instancetype)initWithLabel:(NSString *)label
                   faviconUrl:(NSString *)faviconUrl
                      numbers:(NSString *)numbers
                       config:(StyleConfig *)config;

/// Returns a copy-friendly text representation, e.g. "[1]" or "[1,2]".
- (NSString *)textForCopy;

@end

NS_ASSUME_NONNULL_END
