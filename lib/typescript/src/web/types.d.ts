import type { ComponentType, ReactNode } from 'react';
import type { MarkdownStyleInternal } from '../types/MarkdownStyleInternal';
import type { Styles } from './styles';
import type { LinkPressEvent, LinkLongPressEvent, TaskListItemPressEvent, CitationPressEvent } from '../types/events';
import type { KaTeXInstance } from './katex';
export type NodeType = 'Document' | 'Paragraph' | 'Text' | 'Link' | 'Heading' | 'LineBreak' | 'Strong' | 'Emphasis' | 'Strikethrough' | 'Underline' | 'Code' | 'Image' | 'Blockquote' | 'UnorderedList' | 'OrderedList' | 'ListItem' | 'CodeBlock' | 'ThematicBreak' | 'Table' | 'TableHead' | 'TableBody' | 'TableRow' | 'TableHeaderCell' | 'TableCell' | 'LatexMathInline' | 'LatexMathDisplay' | 'Citation';
export interface NodeAttributes {
    level?: string;
    url?: string;
    title?: string;
    language?: string;
    fenceChar?: string;
    isTask?: string;
    taskChecked?: string;
    /** Stamped by indexTaskItems() — not present in the raw WASM output. */
    taskIndex?: number;
    /** Stamped by markInlineImages() — not present in the raw WASM output. */
    isInline?: boolean;
    colCount?: string;
    headRowCount?: string;
    bodyRowCount?: string;
    align?: 'left' | 'center' | 'right' | 'default';
    /** Comma-separated citation numbers, e.g. "1,2,3". */
    numbers?: string;
}
export interface ASTNode {
    type: NodeType;
    /** Present on Text, Code, LatexMathInline, LatexMathDisplay nodes. */
    content?: string;
    /** Present on nodes that carry structural metadata (Heading, Link, etc.). */
    attributes?: NodeAttributes;
    /** Child nodes; absent on leaf nodes (Text, LineBreak, ThematicBreak). */
    children?: ASTNode[];
}
export interface RendererCallbacks {
    onLinkPress?: (event: LinkPressEvent) => void;
    onLinkLongPress?: (event: LinkLongPressEvent) => void;
    onTaskListItemPress?: (event: TaskListItemPressEvent) => void;
    onCitationPress?: (event: CitationPressEvent) => void;
}
export interface RenderCapabilities {
    katex: KaTeXInstance | null;
}
export interface RendererProps {
    node: ASTNode;
    style: MarkdownStyleInternal;
    styles: Styles;
    parentType?: NodeType;
    callbacks: RendererCallbacks;
    capabilities: RenderCapabilities;
    renderChildren: (node: ASTNode) => ReactNode;
}
export type RendererMap = Partial<Record<NodeType, ComponentType<RendererProps>>>;
//# sourceMappingURL=types.d.ts.map