import { useState, useMemo, useCallback, useRef, useEffect } from 'react';
import { View } from 'react-native';
import EnrichedMarkdownTextNativeComponent from '../EnrichedMarkdownTextNativeComponent';
import type { MarkdownStyleInternal } from '../EnrichedMarkdownTextNativeComponent';
import EnrichedMarkdownNativeComponent from '../EnrichedMarkdownNativeComponent';
import { normalizeMarkdownStyle } from '../normalizeMarkdownStyle';
import type { NativeSyntheticEvent } from 'react-native';
import type { MarkdownStyle, Md4cFlags } from '../types/MarkdownStyle';
import type {
  EnrichedMarkdownTextProps,
  ContextMenuItem,
} from '../types/MarkdownTextProps';
import type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
  CitationPressEvent,
  CitationLayoutEvent,
  CitationLayoutItem,
  OnContextMenuItemPressEvent,
} from '../types/events';

export type { MarkdownStyle, Md4cFlags };
export type { EnrichedMarkdownTextProps, ContextMenuItem };
export type { LinkPressEvent, LinkLongPressEvent, TaskListItemPressEvent, CitationPressEvent, CitationLayoutItem };

const defaultMd4cFlags: Md4cFlags = {
  underline: false,
  latexMath: true,
};

export const EnrichedMarkdownText = ({
  markdown,
  markdownStyle = {},
  containerStyle,
  onLinkPress,
  onLinkLongPress,
  onTaskListItemPress,
  onCitationPress,
  renderCitation,
  enableLinkPreview,
  selectable = true,
  md4cFlags = defaultMd4cFlags,
  allowFontScaling = true,
  maxFontSizeMultiplier,
  allowTrailingMargin = false,
  flavor = 'commonmark',
  streamingAnimation = false,
  spoilerMode = 'particles',
  contextMenuItems,
  ...rest
}: EnrichedMarkdownTextProps) => {
  const normalizedStyleRef = useRef<MarkdownStyleInternal | null>(null);
  const normalized = normalizeMarkdownStyle(markdownStyle);
  if (normalizedStyleRef.current !== normalized) {
    normalizedStyleRef.current = normalized;
  }
  const normalizedStyle = normalizedStyleRef.current!;

  const normalizedMd4cFlags = useMemo(
    () => ({
      underline: md4cFlags.underline ?? false,
      latexMath: md4cFlags.latexMath ?? true,
    }),
    [md4cFlags]
  );

  const contextMenuCallbacksRef = useRef<
    Map<string, ContextMenuItem['onPress']>
  >(new Map());

  useEffect(() => {
    const callbacksMap = new Map<string, ContextMenuItem['onPress']>();
    if (contextMenuItems) {
      for (const item of contextMenuItems) {
        callbacksMap.set(item.text, item.onPress);
      }
    }
    contextMenuCallbacksRef.current = callbacksMap;
  }, [contextMenuItems]);

  const nativeContextMenuItems = useMemo(
    () =>
      contextMenuItems
        ?.filter((item) => item.visible !== false)
        .map((item) => ({ text: item.text, icon: item.icon })),
    [contextMenuItems]
  );

  const handleContextMenuItemPress = useCallback(
    (e: NativeSyntheticEvent<OnContextMenuItemPressEvent>) => {
      const { itemText, selectedText, selectionStart, selectionEnd } =
        e.nativeEvent;
      const callback = contextMenuCallbacksRef.current.get(itemText);
      callback?.({
        text: selectedText,
        selection: { start: selectionStart, end: selectionEnd },
      });
    },
    []
  );

  const handleLinkPress = useCallback(
    (e: NativeSyntheticEvent<LinkPressEvent>) => {
      const { url } = e.nativeEvent;
      onLinkPress?.({ url });
    },
    [onLinkPress]
  );

  const handleLinkLongPress = useCallback(
    (e: NativeSyntheticEvent<LinkLongPressEvent>) => {
      const { url } = e.nativeEvent;
      onLinkLongPress?.({ url });
    },
    [onLinkLongPress]
  );

  const handleTaskListItemPress = useCallback(
    (e: NativeSyntheticEvent<TaskListItemPressEvent>) => {
      const { index, checked, text } = e.nativeEvent;
      onTaskListItemPress?.({ index, checked, text });
    },
    [onTaskListItemPress]
  );

  const handleCitationPress = useCallback(
    (e: NativeSyntheticEvent<CitationPressEvent>) => {
      const { numbers } = e.nativeEvent;
      onCitationPress?.({ numbers });
    },
    [onCitationPress]
  );

  // Citation overlay state — populated by native onCitationLayout events
  const [citationFrames, setCitationFrames] = useState<CitationLayoutItem[]>(
    []
  );

  const handleCitationLayout = useCallback(
    (e: NativeSyntheticEvent<CitationLayoutEvent>) => {
      try {
        const parsed = JSON.parse(e.nativeEvent.citationsJson) as CitationLayoutItem[];
        setCitationFrames(parsed);
      } catch {
        setCitationFrames([]);
      }
    },
    []
  );

  // Separate native-only props from the rest spread (which may include
  // web-only props like `dir` that the native component doesn't accept).
  const { dir: _dir, ...nativeRest } = rest as Record<string, unknown> & {
    dir?: string;
  };

  const sharedProps = {
    markdown,
    markdownStyle: normalizedStyle,
    onLinkPress: handleLinkPress,
    onLinkLongPress: handleLinkLongPress,
    onTaskListItemPress: handleTaskListItemPress,
    onCitationPress: handleCitationPress,
    onCitationLayout: renderCitation ? handleCitationLayout : undefined,
    enableLinkPreview: onLinkLongPress == null && (enableLinkPreview ?? true),
    selectable,
    md4cFlags: normalizedMd4cFlags,
    allowFontScaling,
    maxFontSizeMultiplier,
    allowTrailingMargin,
    streamingAnimation,
    spoilerMode,
    style: containerStyle,
    contextMenuItems: nativeContextMenuItems,
    onContextMenuItemPress: handleContextMenuItemPress,
    ...nativeRest,
  };

  const nativeComponent =
    flavor === 'github' ? (
      <EnrichedMarkdownNativeComponent {...(sharedProps as any)} />
    ) : (
      <EnrichedMarkdownTextNativeComponent {...(sharedProps as any)} />
    );

  // If no renderCitation prop, render the native component directly (no overlay)
  if (!renderCitation || citationFrames.length === 0) {
    return nativeComponent;
  }

  // Wrap in a View and overlay citation React elements at the native-reported positions
  return (
    <View>
      {nativeComponent}
      {citationFrames.map((frame, i) => (
        <View
          key={`cit-${i}-${frame.numbers}`}
          pointerEvents="box-none"
          style={{
            position: 'absolute',
            left: frame.x,
            top: frame.y,
            width: frame.width,
            height: frame.height,
          }}
        >
          {renderCitation(frame)}
        </View>
      ))}
    </View>
  );
};

export default EnrichedMarkdownText;
