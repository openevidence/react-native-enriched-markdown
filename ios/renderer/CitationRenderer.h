#import "MarkdownASTNode.h"
#import "NodeRenderer.h"
#import "RenderContext.h"

@interface CitationRenderer : NSObject <NodeRenderer>
- (instancetype)initWithRendererFactory:(id)rendererFactory config:(id)config;
@end
