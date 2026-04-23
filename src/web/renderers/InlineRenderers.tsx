import type { MouseEvent } from 'react';
import type { RendererProps, RendererMap } from '../types';
import { extractNodeText } from '../utils';
import { KaTeXRenderer } from './KaTeXRenderer';

function TextRenderer({ node }: RendererProps) {
  return <>{node.content ?? ''}</>;
}

function LineBreakRenderer(_props: RendererProps) {
  return <br />;
}

function StrongRenderer({ node, styles, renderChildren }: RendererProps) {
  return <strong style={styles.strong}>{renderChildren(node)}</strong>;
}

function EmphasisRenderer({ node, styles, renderChildren }: RendererProps) {
  return <em style={styles.emphasis}>{renderChildren(node)}</em>;
}

function StrikethroughRenderer({
  node,
  styles,
  renderChildren,
}: RendererProps) {
  return <s style={styles.strikethrough}>{renderChildren(node)}</s>;
}

function UnderlineRenderer({ node, styles, renderChildren }: RendererProps) {
  return <u style={styles.underline}>{renderChildren(node)}</u>;
}

function CodeRenderer({ node, styles, renderChildren }: RendererProps) {
  return (
    <code style={styles.code}>{node.content ?? renderChildren(node)}</code>
  );
}

function LinkRenderer({
  node,
  styles,
  callbacks,
  renderChildren,
}: RendererProps) {
  const url = node.attributes?.url;

  if (!url) return <>{renderChildren(node)}</>;

  const handleClick = (event: MouseEvent) => {
    if (callbacks.onLinkPress) {
      event.preventDefault();
      callbacks.onLinkPress({ url });
    }
  };

  const handleContextMenu = (event: MouseEvent) => {
    if (callbacks.onLinkLongPress) {
      event.preventDefault();
      callbacks.onLinkLongPress({ url });
    }
  };

  return (
    <a
      href={url}
      style={styles.link}
      target="_blank"
      rel="noopener noreferrer"
      onClick={handleClick}
      onContextMenu={handleContextMenu}
    >
      {renderChildren(node)}
    </a>
  );
}

function LatexMathInlineRenderer({
  node,
  styles,
  capabilities,
}: RendererProps) {
  const content = extractNodeText(node);

  return (
    <KaTeXRenderer
      content={content}
      katex={capabilities.katex}
      displayMode={false}
      style={styles.mathInline}
      fallbackTag="code"
    />
  );
}

function CitationRenderer({ node, styles, callbacks }: RendererProps) {
  const numbers = node.content ?? node.attributes?.numbers ?? '';

  const handleClick = () => {
    callbacks.onCitationPress?.({ numbers });
  };

  // The leading space gives the chip inline-word separation mid-line. The
  // browser collapses consecutive whitespace and strips leading whitespace at
  // block/line starts, so this is a no-op where not needed and a single space
  // everywhere else — mirroring the native renderers.
  return (
    <>
      {' '}
      <span
        role="button"
        tabIndex={0}
        style={styles.citation}
        onClick={handleClick}
      >
        {numbers}
      </span>
    </>
  );
}

export const inlineRenderers: RendererMap = {
  Text: TextRenderer,
  LineBreak: LineBreakRenderer,
  Strong: StrongRenderer,
  Emphasis: EmphasisRenderer,
  Strikethrough: StrikethroughRenderer,
  Underline: UnderlineRenderer,
  Code: CodeRenderer,
  Link: LinkRenderer,
  LatexMathInline: LatexMathInlineRenderer,
  Citation: CitationRenderer,
};
