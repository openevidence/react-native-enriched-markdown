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
  ...rest
}) {
  const segments = useMemo(() => splitMarkdownSegments(markdown), [markdown]);

  // Fast path: no component segments, render a single native view directly
  const hasComponents = segments.some(s => s.type === 'component');
  if (!hasComponents) {
    return /*#__PURE__*/_jsx(EnrichedMarkdownText, {
      markdown: markdown,
      ...rest
    });
  }
  return /*#__PURE__*/_jsx(View, {
    children: segments.map((segment, index) => {
      if (segment.type === 'markdown') {
        return /*#__PURE__*/_jsx(EnrichedMarkdownText, {
          markdown: segment.content,
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