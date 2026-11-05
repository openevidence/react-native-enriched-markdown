#import "MarkdownASTNode.h"
#import "NodeRenderer.h"
#import "RenderContext.h"

/**
 * Renders a dose check mark: the dose's own words with a dotted underline in the
 * mark's colour, then its icons (green check or amber person, and an orange
 * calculator when the node says calc="1"). Words and icons form one tap target,
 * registered with the render context under the node's id.
 */
@interface DoseRenderer : NSObject <NodeRenderer>
- (instancetype)initWithRendererFactory:(id)rendererFactory config:(id)config;
@end
