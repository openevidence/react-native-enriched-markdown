import React from 'react';
import type { EnrichedMarkdownTextProps } from './types/MarkdownTextProps';
export interface ComponentRegistry {
    [componentId: string]: React.ComponentType<{
        componentId: string;
        data: Record<string, unknown>;
    }>;
}
export interface EnrichedMarkdownWithComponentsProps extends EnrichedMarkdownTextProps {
    /**
     * Registry mapping component IDs to React Native components.
     * When a ```REACTCOMPONENT code fence is found with a matching componentId,
     * the registered component is rendered with the parsed JSON props as `data`.
     */
    components?: ComponentRegistry;
}
/**
 * Wrapper around EnrichedMarkdownText that supports embedded React Native
 * components via ```REACTCOMPONENT code fences.
 *
 * Splits the markdown at REACTCOMPONENT boundaries and renders alternating
 * native markdown views and custom React Native components.
 *
 * @example
 * <EnrichedMarkdownWithComponents
 *   markdown={processedMarkdown}
 *   components={{
 *     Table: MyTableComponent,
 *     ThinkingBlock: MyThinkingComponent,
 *   }}
 *   markdownStyle={myStyle}
 *   onLinkPress={handleLinkPress}
 * />
 */
export declare const EnrichedMarkdownWithComponents: React.NamedExoticComponent<EnrichedMarkdownWithComponentsProps>;
//# sourceMappingURL=EnrichedMarkdownWithComponents.d.ts.map