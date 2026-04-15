package com.swmansion.enriched.markdown.renderer

import android.content.Context
import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.style.AlignmentSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.MathInlineSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE

/**
 * Renders display math ($$...$$) as a centered block in the single-view path.
 * Reuses [MathInlineSpan] for the actual LaTeX rendering, but wraps it with
 * newlines and center alignment to make it a block-level element.
 */
class MathDisplayRenderer(
  private val config: RendererConfig,
  private val context: Context,
) : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val latex = extractLatex(node)
    if (latex.isEmpty()) return

    val mathStyle = config.style.mathStyle
    // Use paragraph color for the math text so it respects dark mode.
    // The math-specific color may not be theme-aware in all apps.
    val textColor = config.style.paragraphStyle.color

    // Ensure we start on a new line
    if (builder.isNotEmpty() && builder[builder.length - 1] != '\n') {
      builder.append('\n')
    }

    val blockStart = builder.length

    val spanStart = builder.length
    builder.append("\uFFFC")
    val spanEnd = builder.length

    val span = MathInlineSpan(
      context = context,
      latex = latex,
      fontSize = mathStyle.fontSize,
      textColor = textColor,
      scaleToFit = true,
    )
    builder.setSpan(span, spanStart, spanEnd, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)

    // Center-align the math block
    builder.setSpan(
      AlignmentSpan.Standard(Layout.Alignment.ALIGN_CENTER),
      blockStart,
      spanEnd,
      SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
    )

    builder.append('\n')
  }

  private fun extractLatex(node: MarkdownASTNode): String {
    if (!node.content.isNullOrEmpty()) return node.content!!
    return node.children.mapNotNull { it.content }.joinToString("")
  }
}
