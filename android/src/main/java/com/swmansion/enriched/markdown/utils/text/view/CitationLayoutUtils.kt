package com.swmansion.enriched.markdown.utils.text.view

import android.text.Spanned
import android.widget.TextView
import com.facebook.react.uimanager.PixelUtil
import com.swmansion.enriched.markdown.events.CitationLayoutEvent
import com.swmansion.enriched.markdown.spans.CitationChipSpan

/**
 * Computes the on-screen frames (in dp) of all [CitationChipSpan] instances
 * in the given [TextView]'s laid-out text.
 *
 * @param yOffsetPx Additional vertical pixel offset to add to each frame.
 *   Used by the GFM component where each segment view has its own top position
 *   inside the parent FrameLayout.
 * @return A list of [CitationLayoutEvent.CitationFrame], one per chip span,
 *   with coordinates in dp suitable for React Native layout.
 */
fun TextView.computeCitationFrames(yOffsetPx: Float = 0f): List<CitationLayoutEvent.CitationFrame> {
  val textLayout = layout ?: return emptyList()
  val spanned = text as? Spanned ?: return emptyList()

  val spans = spanned.getSpans(0, spanned.length, CitationChipSpan::class.java)
  if (spans.isEmpty()) return emptyList()

  return spans.map { span ->
    val spanStart = spanned.getSpanStart(span)
    val line = textLayout.getLineForOffset(spanStart)

    val xPx = textLayout.getPrimaryHorizontal(spanStart) + paddingLeft
    val yPx = textLayout.getLineTop(line).toFloat() + paddingTop + yOffsetPx

    val widthPx = PixelUtil.toPixelFromDIP(90f)
    val heightPx = (textLayout.getLineBottom(line) - textLayout.getLineTop(line)).toFloat()

    CitationLayoutEvent.CitationFrame(
      x = PixelUtil.toDIPFromPixel(xPx),
      y = PixelUtil.toDIPFromPixel(yPx),
      width = PixelUtil.toDIPFromPixel(widthPx),
      height = PixelUtil.toDIPFromPixel(heightPx),
      numbers = span.numbers,
    )
  }
}
