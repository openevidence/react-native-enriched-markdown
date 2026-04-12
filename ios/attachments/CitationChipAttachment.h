#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@class CitationChipView;

/**
 * NSTextAttachment that renders a CitationChipView as an inline image.
 *
 * On creation the chip is rendered without its favicon. When the favicon
 * finishes downloading, the attachment re-renders and invalidates layout
 * so the text system redraws.
 */
@interface CitationChipAttachment : NSTextAttachment

@property (nonatomic, strong, readonly) CitationChipView *chipView;

- (instancetype)initWithChipView:(CitationChipView *)chipView;

@end

NS_ASSUME_NONNULL_END
