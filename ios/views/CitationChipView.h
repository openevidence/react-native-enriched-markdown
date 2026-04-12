#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A native UIView that renders a citation chip inline.
 *
 * Layout: [8pt pad] [favicon 14pt] [4pt gap] [label] [8pt pad]
 *   or    [8pt pad] [label] [8pt pad]  when no favicon URL is provided.
 *
 * Height: 20pt.  Max total width: 90pt.
 * Background: #FCEDE8.  Text: #343231 at 11pt system regular.
 * Favicon: 14pt circular image loaded asynchronously.
 */
@interface CitationChipView : RCTUIView

- (instancetype)initWithLabel:(NSString *)label faviconUrl:(nullable NSString *)faviconUrl;

/** Re-renders the view hierarchy into a UIImage suitable for an NSTextAttachment. */
- (RCTUIImage *)renderToImage;

/** The size the chip occupies (call after init). */
@property (nonatomic, readonly) CGSize chipSize;

/** Called when the favicon finishes loading so the attachment can re-render. */
@property (nonatomic, copy, nullable) void (^onFaviconLoaded)(void);

@end

NS_ASSUME_NONNULL_END
