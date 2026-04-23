package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.CitationChipSpan
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
    val label = node.content
    val numbers = node.getAttribute("numbers") ?: return
    val faviconUrl = node.getAttribute("faviconUrl") ?: ""

    // Insert a leading space when the preceding content doesn't already end
    // with whitespace. The space gives the chip inline-word separation mid-
    // line, and the layout engine collapses trailing whitespace at wrap
    // boundaries — so a wrapped chip starts the new line flush with its
    // leading edge, regardless of paragraph indent (bullets, nested lists).
    if (builder.isNotEmpty() && !builder[builder.length - 1].isWhitespace()) {
      builder.append(' ')
    }

    val start = builder.length
    builder.append("\uFFFC") // Object replacement character
    val end = builder.length

    builder.setSpan(
      CitationChipSpan(
        label = label,
        faviconUrl = faviconUrl,
        numbers = numbers,
        onCitationPress = factory.onCitationPress,
        styleCache = factory.styleCache,
        context = factory.context,
      ),
      start,
      end,
      SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
    )
  }
}
