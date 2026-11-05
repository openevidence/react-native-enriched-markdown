#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@class StyleConfig;

@interface TextViewLayoutManager : NSLayoutManager <NSLayoutManagerDelegate>

@property (nonatomic, strong) StyleConfig *config;

@end

NS_ASSUME_NONNULL_END
