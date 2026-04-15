"use strict";

const REACT_COMPONENT_SENTINEL = 'REACTCOMPONENT';
const SPLIT_SENTINEL = '!:!';

/**
 * Regex matching fenced code blocks with language `REACTCOMPONENT`.
 * Handles both ``` and ~~~ fences (MD4C supports both).
 */
const CODE_FENCE_REGEX = /^```REACTCOMPONENT\s*\n([\s\S]*?)\n```\s*$/gm;

/**
 * Wraps raw `REACTCOMPONENT!:!...` sentinels in markdown code fences.
 * This mirrors the web pipeline's `preprocessReactComponents()`.
 *
 * @example
 * preprocessReactComponents('REACTCOMPONENT!:!Table!:!{"rows":[]}')
 * // => '\n```REACTCOMPONENT\nREACTCOMPONENT!:!Table!:!{"rows":[]}\n```\n'
 */
export function preprocessReactComponents(text) {
  if (text.includes(REACT_COMPONENT_SENTINEL)) {
    // Don't double-wrap if already in a code fence
    if (/```REACTCOMPONENT/.test(text)) {
      return text;
    }
    return '\n```REACTCOMPONENT\n' + text + '\n```\n';
  }
  return text;
}

/**
 * Splits a markdown string into alternating text and component segments.
 * REACTCOMPONENT code fences are extracted and parsed into component
 * segments with `componentId` and `props`.
 *
 * @example
 * const segments = splitMarkdownSegments(`
 * Some text.
 *
 * \`\`\`REACTCOMPONENT
 * REACTCOMPONENT!:!Table!:!{"columns":["a","b"]}
 * \`\`\`
 *
 * More text.
 * `);
 * // => [
 * //   { type: 'markdown', content: '\nSome text.\n\n' },
 * //   { type: 'component', componentId: 'Table', props: { columns: ['a', 'b'] } },
 * //   { type: 'markdown', content: '\n\nMore text.\n' },
 * // ]
 */
export function splitMarkdownSegments(markdown) {
  const segments = [];
  let lastIndex = 0;

  // Reset regex state
  CODE_FENCE_REGEX.lastIndex = 0;
  let match;
  while ((match = CODE_FENCE_REGEX.exec(markdown)) !== null) {
    // Text before this component
    if (match.index > lastIndex) {
      const content = markdown.slice(lastIndex, match.index);
      if (content.trim().length > 0) {
        segments.push({
          type: 'markdown',
          content
        });
      }
    }

    // Parse the component content
    const inner = match[1].trim();
    const parts = inner.split(SPLIT_SENTINEL);
    if (parts.length >= 3 && parts[0] === REACT_COMPONENT_SENTINEL) {
      const componentId = parts[1];
      let props = {};
      try {
        props = JSON.parse(parts[2]);
      } catch {
        // If JSON parsing fails, pass the raw string as a `raw` prop
        props = {
          raw: parts[2]
        };
      }
      segments.push({
        type: 'component',
        componentId,
        props
      });
    }
    lastIndex = match.index + match[0].length;
  }

  // Remaining text
  if (lastIndex < markdown.length) {
    const content = markdown.slice(lastIndex);
    if (content.trim().length > 0) {
      segments.push({
        type: 'markdown',
        content
      });
    }
  }

  // If no segments found, return the entire markdown as a single text segment
  if (segments.length === 0 && markdown.trim().length > 0) {
    segments.push({
      type: 'markdown',
      content: markdown
    });
  }
  return segments;
}
//# sourceMappingURL=splitMarkdownSegments.js.map