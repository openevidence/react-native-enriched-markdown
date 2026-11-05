#import <Foundation/Foundation.h>

@class RenderContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * Container for accessibility-related data extracted from RenderContext.
 * Used by MarkdownAccessibilityElementBuilder to build VoiceOver elements.
 */
@interface AccessibilityInfo : NSObject

// Headings
@property (nonatomic, copy, readonly) NSArray<NSValue *> *headingRanges;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *headingLevels;

// Links
@property (nonatomic, copy, readonly) NSArray<NSValue *> *linkRanges;
@property (nonatomic, copy, readonly) NSArray<NSString *> *linkURLs;

// Images
@property (nonatomic, copy, readonly) NSArray<NSValue *> *imageRanges;
@property (nonatomic, copy, readonly) NSArray<NSString *> *imageAltTexts;

// Dose check marks (words and icons), their ids and what VoiceOver reads
@property (nonatomic, copy, readonly) NSArray<NSValue *> *doseRanges;
@property (nonatomic, copy, readonly) NSArray<NSString *> *doseIds;
@property (nonatomic, copy, readonly) NSArray<NSString *> *doseLabels;

// List items
@property (nonatomic, copy, readonly) NSArray<NSValue *> *listItemRanges;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *listItemPositions;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *listItemDepths;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *listItemOrdered; // YES = ordered, NO = bullet

+ (instancetype)infoFromContext:(RenderContext *)context;

@end

NS_ASSUME_NONNULL_END
