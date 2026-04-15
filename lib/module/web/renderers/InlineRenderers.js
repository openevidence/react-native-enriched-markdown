"use strict";

import { extractNodeText } from "../utils.js";
import { KaTeXRenderer } from "./KaTeXRenderer.js";
import { Fragment as _Fragment, jsx as _jsx } from "react/jsx-runtime";
function TextRenderer({
  node
}) {
  return /*#__PURE__*/_jsx(_Fragment, {
    children: node.content ?? ''
  });
}
function LineBreakRenderer(_props) {
  return /*#__PURE__*/_jsx("br", {});
}
function StrongRenderer({
  node,
  styles,
  renderChildren
}) {
  return /*#__PURE__*/_jsx("strong", {
    style: styles.strong,
    children: renderChildren(node)
  });
}
function EmphasisRenderer({
  node,
  styles,
  renderChildren
}) {
  return /*#__PURE__*/_jsx("em", {
    style: styles.emphasis,
    children: renderChildren(node)
  });
}
function StrikethroughRenderer({
  node,
  styles,
  renderChildren
}) {
  return /*#__PURE__*/_jsx("s", {
    style: styles.strikethrough,
    children: renderChildren(node)
  });
}
function UnderlineRenderer({
  node,
  styles,
  renderChildren
}) {
  return /*#__PURE__*/_jsx("u", {
    style: styles.underline,
    children: renderChildren(node)
  });
}
function CodeRenderer({
  node,
  styles,
  renderChildren
}) {
  return /*#__PURE__*/_jsx("code", {
    style: styles.code,
    children: node.content ?? renderChildren(node)
  });
}
function LinkRenderer({
  node,
  styles,
  callbacks,
  renderChildren
}) {
  const url = node.attributes?.url;
  if (!url) return /*#__PURE__*/_jsx(_Fragment, {
    children: renderChildren(node)
  });
  const handleClick = event => {
    if (callbacks.onLinkPress) {
      event.preventDefault();
      callbacks.onLinkPress({
        url
      });
    }
  };
  const handleContextMenu = event => {
    if (callbacks.onLinkLongPress) {
      event.preventDefault();
      callbacks.onLinkLongPress({
        url
      });
    }
  };
  return /*#__PURE__*/_jsx("a", {
    href: url,
    style: styles.link,
    target: "_blank",
    rel: "noopener noreferrer",
    onClick: handleClick,
    onContextMenu: handleContextMenu,
    children: renderChildren(node)
  });
}
function LatexMathInlineRenderer({
  node,
  styles,
  capabilities
}) {
  const content = extractNodeText(node);
  return /*#__PURE__*/_jsx(KaTeXRenderer, {
    content: content,
    katex: capabilities.katex,
    displayMode: false,
    style: styles.mathInline,
    fallbackTag: "code"
  });
}
function CitationRenderer({
  node,
  styles,
  callbacks
}) {
  const numbers = node.content ?? node.attributes?.numbers ?? '';
  const handleClick = () => {
    callbacks.onCitationPress?.({
      numbers
    });
  };
  return /*#__PURE__*/_jsx("span", {
    role: "button",
    tabIndex: 0,
    style: styles.citation,
    onClick: handleClick,
    children: numbers
  });
}
export const inlineRenderers = {
  Text: TextRenderer,
  LineBreak: LineBreakRenderer,
  Strong: StrongRenderer,
  Emphasis: EmphasisRenderer,
  Strikethrough: StrikethroughRenderer,
  Underline: UnderlineRenderer,
  Code: CodeRenderer,
  Link: LinkRenderer,
  LatexMathInline: LatexMathInlineRenderer,
  Citation: CitationRenderer
};
//# sourceMappingURL=InlineRenderers.js.map