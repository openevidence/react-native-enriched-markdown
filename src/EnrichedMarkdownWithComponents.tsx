import React, { useMemo } from 'react';
import { View } from 'react-native';
import { EnrichedMarkdownText } from './native/EnrichedMarkdownText';
import type { EnrichedMarkdownTextProps } from './types/MarkdownTextProps';
import {
  splitMarkdownSegments,
  type MarkdownSegment,
} from './utils/splitMarkdownSegments';

export interface ComponentRegistry {
  [componentId: string]: React.ComponentType<{
    componentId: string;
    data: Record<string, unknown>;
  }>;
}

export interface EnrichedMarkdownWithComponentsProps
  extends EnrichedMarkdownTextProps {
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
export function EnrichedMarkdownWithComponents({
  markdown,
  components,
  ...rest
}: EnrichedMarkdownWithComponentsProps) {
  const segments: MarkdownSegment[] = useMemo(
    () => splitMarkdownSegments(markdown),
    [markdown]
  );

  // Fast path: no component segments, render a single native view directly
  const hasComponents = segments.some((s) => s.type === 'component');
  if (!hasComponents) {
    return <EnrichedMarkdownText markdown={markdown} {...rest} />;
  }

  return (
    <View>
      {segments.map((segment, index) => {
        if (segment.type === 'markdown') {
          return (
            <EnrichedMarkdownText
              key={`md-${index}`}
              markdown={segment.content}
              {...rest}
            />
          );
        }

        const Component = components?.[segment.componentId];
        if (!Component) {
          return null;
        }

        return (
          <Component
            key={`rc-${index}`}
            componentId={segment.componentId}
            data={segment.props}
          />
        );
      })}
    </View>
  );
}
