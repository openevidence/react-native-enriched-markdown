package com.swmansion.enriched.markdown.spans

import android.text.TextPaint
import android.text.style.ClickableSpan
import android.view.View
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.renderer.SpanStyleCache

class CitationClickSpan(
  val numbers: String,
  private val onCitationPress: ((String) -> Unit)?,
  private val styleCache: SpanStyleCache,
) : ClickableSpan() {
  override fun onClick(widget: View) {
    onCitationPress?.invoke(numbers)
      ?: (widget as? EnrichedMarkdownText)?.emitOnCitationPress(numbers)
  }

  override fun updateDrawState(textPaint: TextPaint) {
    super.updateDrawState(textPaint)
    textPaint.color = styleCache.citationColor
    textPaint.isUnderlineText = false
    if (styleCache.citationFontSize > 0f) {
      textPaint.textSize = styleCache.citationFontSize
    }
  }
}
