"use strict";

import { useMemo, useCallback, useRef, useEffect } from 'react';
import EnrichedMarkdownTextNativeComponent from '../EnrichedMarkdownTextNativeComponent';
import EnrichedMarkdownNativeComponent from '../EnrichedMarkdownNativeComponent';
import { normalizeMarkdownStyle } from '../normalizeMarkdownStyle';
import { jsx as _jsx } from "react/jsx-runtime";
const defaultMd4cFlags = {
  underline: false,
  latexMath: true
};
export const EnrichedMarkdownText = ({
  markdown,
  markdownStyle = {},
  containerStyle,
  onLinkPress,
  onLinkLongPress,
  onTaskListItemPress,
  onCitationPress,
  enableLinkPreview,
  selectable = true,
  md4cFlags = defaultMd4cFlags,
  allowFontScaling = true,
  maxFontSizeMultiplier,
  allowTrailingMargin = false,
  flavor = 'commonmark',
  streamingAnimation = false,
  trailingCursor = false,
  spoilerMode = 'particles',
  contextMenuItems,
  ...rest
}) => {
  const normalizedStyleRef = useRef(null);
  const normalized = normalizeMarkdownStyle(markdownStyle);
  // normalizeMarkdownStyle returns cached objects for structurally equal inputs,
  // so this referential check is sufficient to preserve a stable prop reference.
  if (normalizedStyleRef.current !== normalized) {
    normalizedStyleRef.current = normalized;
  }
  const normalizedStyle = normalizedStyleRef.current;
  const normalizedMd4cFlags = useMemo(() => ({
    underline: md4cFlags.underline ?? false,
    latexMath: md4cFlags.latexMath ?? true
  }), [md4cFlags]);
  const contextMenuCallbacksRef = useRef(new Map());
  useEffect(() => {
    const callbacksMap = new Map();
    if (contextMenuItems) {
      for (const item of contextMenuItems) {
        callbacksMap.set(item.text, item.onPress);
      }
    }
    contextMenuCallbacksRef.current = callbacksMap;
  }, [contextMenuItems]);
  const nativeContextMenuItems = useMemo(() => contextMenuItems?.filter(item => item.visible !== false).map(item => ({
    text: item.text,
    icon: item.icon
  })), [contextMenuItems]);
  const handleContextMenuItemPress = useCallback(e => {
    const {
      itemText,
      selectedText,
      selectionStart,
      selectionEnd
    } = e.nativeEvent;
    const callback = contextMenuCallbacksRef.current.get(itemText);
    callback?.({
      text: selectedText,
      selection: {
        start: selectionStart,
        end: selectionEnd
      }
    });
  }, []);
  const handleLinkPress = useCallback(e => {
    const {
      url
    } = e.nativeEvent;
    onLinkPress?.({
      url
    });
  }, [onLinkPress]);
  const handleLinkLongPress = useCallback(e => {
    const {
      url
    } = e.nativeEvent;
    onLinkLongPress?.({
      url
    });
  }, [onLinkLongPress]);
  const handleTaskListItemPress = useCallback(e => {
    const {
      index,
      checked,
      text
    } = e.nativeEvent;
    onTaskListItemPress?.({
      index,
      checked,
      text
    });
  }, [onTaskListItemPress]);
  const handleCitationPress = useCallback(e => {
    const {
      numbers
    } = e.nativeEvent;
    onCitationPress?.({
      numbers
    });
  }, [onCitationPress]);
  const sharedProps = {
    markdown,
    markdownStyle: normalizedStyle,
    onLinkPress: handleLinkPress,
    onLinkLongPress: handleLinkLongPress,
    onTaskListItemPress: handleTaskListItemPress,
    onCitationPress: handleCitationPress,
    enableLinkPreview: onLinkLongPress == null && (enableLinkPreview ?? true),
    selectable,
    md4cFlags: normalizedMd4cFlags,
    allowFontScaling,
    maxFontSizeMultiplier,
    allowTrailingMargin,
    streamingAnimation,
    trailingCursor,
    spoilerMode,
    style: containerStyle,
    contextMenuItems: nativeContextMenuItems,
    onContextMenuItemPress: handleContextMenuItemPress,
    ...rest
  };
  if (flavor === 'github') {
    return /*#__PURE__*/_jsx(EnrichedMarkdownNativeComponent, {
      ...sharedProps
    });
  }
  return /*#__PURE__*/_jsx(EnrichedMarkdownTextNativeComponent, {
    ...sharedProps
  });
};
export default EnrichedMarkdownText;
//# sourceMappingURL=EnrichedMarkdownText.js.map