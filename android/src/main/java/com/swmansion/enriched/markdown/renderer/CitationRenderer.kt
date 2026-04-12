package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.CitationClickSpan
import com.swmansion.enriched.markdown.spans.CitationPlaceholderSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE

class CitationRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val numbers = node.content
    if (numbers.isEmpty()) return

    // Leading space
    builder.append(" ")

    val start = builder.length
    // Insert a placeholder character that the ReplacementSpan will size
    builder.append("\uFFFC") // Object replacement character
    val end = builder.length

    builder.setSpan(
      CitationPlaceholderSpan(numbers),
      start,
      end,
      SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
    )

    builder.setSpan(
      CitationClickSpan(numbers, factory.onCitationPress, factory.styleCache),
      start,
      end,
      SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
    )

    // Trailing space
    builder.append(" ")
  }
}
