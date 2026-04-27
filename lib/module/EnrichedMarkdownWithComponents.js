"use strict";

import React, { memo, useMemo } from 'react';
import { StyleSheet, View } from 'react-native';
import { EnrichedMarkdownText } from "./native/EnrichedMarkdownText.js";
import { splitMarkdownSegments } from "./utils/splitMarkdownSegments.js";
import { jsx as _jsx } from "react/jsx-runtime";
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
export const EnrichedMarkdownWithComponents = /*#__PURE__*/memo(function EnrichedMarkdownWithComponents({
  markdown,
  components,
  trailingCursor,
  ...rest
}) {
  const segments = useMemo(() => splitMarkdownSegments(markdown), [markdown]);

  // Fast path: no component segments, render a single native view directly
  const hasComponents = segments.some(s => s.type === 'component');
  if (!hasComponents) {
    return /*#__PURE__*/_jsx(EnrichedMarkdownText, {
      markdown: markdown,
      trailingCursor: trailingCursor,
      ...rest
    });
  }

  // The cursor must only appear on the final markdown segment so it sits at
  // the very end of the rendered article.
  const lastMarkdownSegmentIndex = (() => {
    for (let i = segments.length - 1; i >= 0; i--) {
      if (segments[i].type === 'markdown') return i;
    }
    return -1;
  })();
  return /*#__PURE__*/_jsx(View, {
    children: segments.map((segment, index) => {
      if (segment.type === 'markdown') {
        return /*#__PURE__*/_jsx(EnrichedMarkdownText, {
          markdown: segment.content,
          trailingCursor: trailingCursor && index === lastMarkdownSegmentIndex,
          ...rest
        }, `md-${index}`);
      }
      const Component = components?.[segment.componentId];
      if (!Component) {
        return null;
      }
      return /*#__PURE__*/_jsx(View, {
        style: styles.componentWrap,
        children: /*#__PURE__*/_jsx(Component, {
          componentId: segment.componentId,
          data: segment.props
        })
      }, `rc-${index}`);
    })
  });
});
const styles = StyleSheet.create({
  componentWrap: {
    marginBottom: 16
  }
});
//# sourceMappingURL=EnrichedMarkdownWithComponents.js.map