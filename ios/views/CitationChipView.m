#import "CitationChipView.h"
#import "ENRMImageDownloader.h"

static const CGFloat kChipHeight = 20.0;
static const CGFloat kHorizontalPadding = 8.0;
static const CGFloat kFaviconSize = 14.0;
static const CGFloat kFaviconGap = 4.0;
static const CGFloat kLabelFontSize = 11.0;

@implementation CitationChipView {
#if !TARGET_OS_OSX
  UILabel *_label;
  UIImageView *_faviconView;
#else
  NSTextField *_label;
  NSImageView *_faviconView;
#endif
  NSString *_faviconUrl;
  BOOL _hasFavicon;
}

- (instancetype)initWithLabel:(NSString *)label faviconUrl:(NSString *)faviconUrl
{
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _faviconUrl = [faviconUrl copy];
    _hasFavicon = (faviconUrl.length > 0);

    // Background color: #FCEDE8
    RCTUIColor *bgColor = [RCTUIColor colorWithRed:0xFC / 255.0
                                             green:0xED / 255.0
                                              blue:0xE8 / 255.0
                                             alpha:1.0];
#if !TARGET_OS_OSX
    self.backgroundColor = bgColor;
#else
    self.wantsLayer = YES;
    self.layer.backgroundColor = bgColor.CGColor;
#endif

    // Label
#if !TARGET_OS_OSX
    _label = [[UILabel alloc] initWithFrame:CGRectZero];
    _label.text = label;
    _label.font = [UIFont systemFontOfSize:kLabelFontSize weight:UIFontWeightRegular];
    _label.textColor = [RCTUIColor colorWithRed:0x34 / 255.0
                                          green:0x32 / 255.0
                                           blue:0x31 / 255.0
                                          alpha:1.0];
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
#else
    _label = [[NSTextField alloc] initWithFrame:CGRectZero];
    _label.stringValue = label;
    _label.font = [NSFont systemFontOfSize:kLabelFontSize weight:NSFontWeightRegular];
    _label.textColor = [RCTUIColor colorWithRed:0x34 / 255.0
                                          green:0x32 / 255.0
                                           blue:0x31 / 255.0
                                          alpha:1.0];
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    _label.bordered = NO;
    _label.editable = NO;
    _label.selectable = NO;
    _label.drawsBackground = NO;
#endif
    [self addSubview:_label];

    // Favicon (if URL provided)
    if (_hasFavicon) {
#if !TARGET_OS_OSX
      _faviconView = [[UIImageView alloc] initWithFrame:CGRectZero];
      _faviconView.contentMode = UIViewContentModeScaleAspectFill;
      _faviconView.clipsToBounds = YES;
      _faviconView.layer.cornerRadius = kFaviconSize / 2.0;
#else
      _faviconView = [[NSImageView alloc] initWithFrame:CGRectZero];
      _faviconView.imageScaling = NSImageScaleProportionallyUpOrDown;
      _faviconView.wantsLayer = YES;
      _faviconView.layer.cornerRadius = kFaviconSize / 2.0;
      _faviconView.layer.masksToBounds = YES;
#endif
      [self addSubview:_faviconView];
      [self startFaviconDownload];
    }

    [self computeLayout];

    // Pill shape
#if !TARGET_OS_OSX
    self.layer.cornerRadius = kChipHeight / 2.0;
    self.clipsToBounds = YES;
#else
    self.layer.cornerRadius = kChipHeight / 2.0;
    self.layer.masksToBounds = YES;
#endif
  }
  return self;
}

#pragma mark - Layout

- (void)computeLayout
{
  // Measure label with no max width cap — JS preprocessing already truncates
  // labels to a reasonable length (~14 chars + " + N" suffix).
  CGFloat labelMaxWidth = CGFLOAT_MAX;

#if !TARGET_OS_OSX
  CGSize labelSize = [_label sizeThatFits:CGSizeMake(labelMaxWidth, kChipHeight)];
#else
  CGSize labelSize = [_label.cell cellSizeForBounds:NSMakeRect(0, 0, labelMaxWidth, kChipHeight)];
#endif
  CGFloat labelWidth = labelSize.width;
  CGFloat labelHeight = labelSize.height;

  // Compute total width
  CGFloat totalWidth;
  if (_hasFavicon) {
    totalWidth = kHorizontalPadding + kFaviconSize + kFaviconGap + labelWidth + kHorizontalPadding;
  } else {
    totalWidth = kHorizontalPadding + labelWidth + kHorizontalPadding;
  }

  _chipSize = CGSizeMake(totalWidth, kChipHeight);
  self.frame = CGRectMake(0, 0, totalWidth, kChipHeight);

  // Position subviews
  CGFloat x = kHorizontalPadding;

  if (_hasFavicon) {
    CGFloat faviconY = (kChipHeight - kFaviconSize) / 2.0;
    _faviconView.frame = CGRectMake(x, faviconY, kFaviconSize, kFaviconSize);
    x += kFaviconSize + kFaviconGap;
  }

  CGFloat labelY = (kChipHeight - labelHeight) / 2.0;
  _label.frame = CGRectMake(x, labelY, totalWidth - x - kHorizontalPadding, labelHeight);
}

#pragma mark - Image rendering

- (RCTUIImage *)renderToImage
{
  CGSize size = _chipSize;
  if (size.width <= 0 || size.height <= 0) {
    return nil;
  }

  RCTUIGraphicsImageRenderer *renderer = ImageRendererForSize(size);
  return [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *ctx) {
    [self.layer renderInContext:ctx.CGContext];
  }];
}

#pragma mark - Favicon download

- (void)startFaviconDownload
{
  if (_faviconUrl.length == 0)
    return;

  __weak typeof(self) weakSelf = self;
  [[ENRMImageDownloader shared] downloadURL:_faviconUrl
                                 completion:^(RCTUIImage *_Nullable image) {
                                   __strong typeof(weakSelf) strongSelf = weakSelf;
                                   if (!strongSelf || !image)
                                     return;

                                   strongSelf->_faviconView.image = image;
                                   if (strongSelf.onFaviconLoaded) {
                                     strongSelf.onFaviconLoaded();
                                   }
                                 }];
}

@end
