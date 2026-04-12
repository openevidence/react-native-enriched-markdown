package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.style.ReplacementSpan
import com.facebook.react.uimanager.PixelUtil
import kotlin.math.roundToInt

/**
 * A ReplacementSpan that reserves a fixed-size rectangle (90dp x 20dp) and draws nothing.
 * The actual citation chip is rendered as a React Native overlay view positioned
 * using the frame information emitted via the onCitationLayout event.
 *
 * Stores the [numbers] string so the layout pass can read it back when building
 * the citation-frame array.
 */
class CitationPlaceholderSpan(
  val numbers: String,
) : ReplacementSpan() {
  private val widthPx = PixelUtil.toPixelFromDIP(90f).roundToInt()
  private val heightPx = PixelUtil.toPixelFromDIP(20f).roundToInt()

  override fun getSize(
    paint: Paint,
    text: CharSequence,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    if (fm != null) {
      val fontHeight = fm.descent - fm.ascent
      val diff = heightPx - fontHeight
      fm.ascent -= diff / 2
      fm.descent += diff / 2
      fm.top = fm.ascent
      fm.bottom = fm.descent
    }
    return widthPx
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
    // Draw nothing — the React Native view will be overlaid
  }
}
