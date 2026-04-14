package com.swmansion.enriched.markdown.spans

import android.text.TextPaint
import android.text.style.MetricAffectingSpan
import androidx.annotation.FloatRange

/**
 * Span that modulates the alpha of the text paint color.
 *
 * Extends MetricAffectingSpan (not CharacterStyle) because Android's TextLine
 * only queries MetricAffectingSpan.class when building the span set that receives
 * updateDrawState calls. A plain CharacterStyle would never be drawn.
 */
class FadeInSpan : MetricAffectingSpan() {
  @set:FloatRange(from = 0.0, to = 1.0)
  var alpha: Float = 0f

  override fun updateMeasureState(textPaint: TextPaint) {
    // No-op: fade should not affect text measurement / layout.
  }

  override fun updateDrawState(tp: TextPaint) {
    tp.color = multiplyAlpha(tp.color, alpha)
    tp.underlineColor = multiplyAlpha(tp.underlineColor, alpha)
  }

  private fun multiplyAlpha(
    color: Int,
    alpha: Float,
  ): Int {
    if (alpha >= 1f) return color
    if (alpha <= 0f) return color and 0x00FFFFFF
    val a = ((color ushr 24) * alpha).toInt()
    return (a shl 24) or (color and 0x00FFFFFF)
  }
}
