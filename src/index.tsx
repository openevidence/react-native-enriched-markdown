export { default as EnrichedMarkdownText } from './native/EnrichedMarkdownText';
export type {
  EnrichedMarkdownTextProps,
  MarkdownStyle,
  Md4cFlags,
  ContextMenuItem as TextContextMenuItem,
} from './native/EnrichedMarkdownText';
export type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
  CitationPressEvent,
} from './types/events';

export { EnrichedMarkdownInput } from './EnrichedMarkdownInput';
export type {
  EnrichedMarkdownInputProps,
  EnrichedMarkdownInputInstance,
  MarkdownInputStyle,
  StyleState,
  ContextMenuItem,
  OnLinkDetected,
  CaretRect,
} from './EnrichedMarkdownInput';

export { EnrichedMarkdownWithComponents } from './EnrichedMarkdownWithComponents';
export type {
  EnrichedMarkdownWithComponentsProps,
  ComponentRegistry,
} from './EnrichedMarkdownWithComponents';

export {
  splitMarkdownSegments,
  preprocessReactComponents,
} from './utils/splitMarkdownSegments';
export type {
  MarkdownSegment,
  TextSegment,
  ComponentSegment,
} from './utils/splitMarkdownSegments';
