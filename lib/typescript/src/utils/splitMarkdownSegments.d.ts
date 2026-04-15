export type TextSegment = {
    type: 'markdown';
    content: string;
};
export type ComponentSegment = {
    type: 'component';
    componentId: string;
    props: Record<string, unknown>;
};
export type MarkdownSegment = TextSegment | ComponentSegment;
/**
 * Wraps raw `REACTCOMPONENT!:!...` sentinels in markdown code fences.
 * This mirrors the web pipeline's `preprocessReactComponents()`.
 *
 * @example
 * preprocessReactComponents('REACTCOMPONENT!:!Table!:!{"rows":[]}')
 * // => '\n```REACTCOMPONENT\nREACTCOMPONENT!:!Table!:!{"rows":[]}\n```\n'
 */
export declare function preprocessReactComponents(text: string): string;
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
export declare function splitMarkdownSegments(markdown: string): MarkdownSegment[];
//# sourceMappingURL=splitMarkdownSegments.d.ts.map