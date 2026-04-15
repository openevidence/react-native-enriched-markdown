import type { MarkdownStyle } from './types/MarkdownStyle';
import type { MarkdownStyleInternal } from './types/MarkdownStyleInternal';
export declare function flattenSpoilerStyle(userSpoiler: MarkdownStyle['spoiler']): Partial<MarkdownStyleInternal['spoiler']> | undefined;
export declare function isStyleEqual(a: MarkdownStyle, b: MarkdownStyle, referenceKeys: readonly string[]): boolean;
//# sourceMappingURL=styleUtils.d.ts.map