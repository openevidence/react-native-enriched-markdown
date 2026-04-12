package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import kotlin.math.roundToInt

/**
 * Draws a rounded-rect background behind citation chip text.
 * Used together with [LinkSpan] on the same range — LinkSpan handles
 * click events and applies text color/underline via updateDrawState(),
 * while this span handles the background visual and text rendering.
 */
class CitationBackgroundSpan(
  private val styleCache: SpanStyleCache,
) : ReplacementSpan() {
  override fun getSize(
    paint: Paint,
    text: CharSequence,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    if (fm != null) {
      val metrics = paint.fontMetricsInt
      fm.top = metrics.top
      fm.ascent = metrics.ascent
      fm.descent = metrics.descent
      fm.bottom = metrics.bottom
    }
    return paint.measureText(text, start, end).roundToInt()
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    val width = paint.measureText(text, start, end)
    val rect = RectF(x, top.toFloat(), x + width, bottom.toFloat())
    val cornerRadius = styleCache.citationBorderRadius

    val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    bgPaint.color = styleCache.citationBackgroundColor
    bgPaint.style = Paint.Style.FILL
    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, bgPaint)

    canvas.drawText(text, start, end, x, y.toFloat(), paint)
  }
}
