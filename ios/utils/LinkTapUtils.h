#pragma once

#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// Returns the link URL at the tap location, or nil if no link was tapped.
NSString *_Nullable linkURLAtTapLocation(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer);

/// Returns the link URL at the given character range, or nil if none found.
NSString *_Nullable linkURLAtRange(ENRMPlatformTextView *textView, NSRange characterRange);

/// Returns the citation numbers string at the tap location, or nil if no citation was tapped.
NSString *_Nullable citationNumbersAtTapLocation(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer);

/// Returns the dose check mark id at the tap location (its words or its icons), or nil.
/// `outTarget` receives what was tapped: @"check" (the check or person icon),
/// @"calculator" (the calculator icon) or @"text" (the dose's words).
NSString *_Nullable doseIdAtTapLocation(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer,
                                        NSString *_Nullable *_Nullable outTarget);

/// Returns YES if the point (in textView coordinates) is on a link or task list checkbox.
BOOL isPointOnInteractiveElement(ENRMPlatformTextView *textView, CGPoint point);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
