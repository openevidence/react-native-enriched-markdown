package com.swmansion.enriched.markdown.utils.text.view

import android.text.Spanned
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.CitationChipSpan
import com.swmansion.enriched.markdown.spans.LinkSpan

/**
 * Returns the character offset in the text for the given touch coordinates,
 * or -1 if the layout is not available.
 */
fun TextView.charOffsetAt(
  x: Float,
  y: Float,
): Int {
  val l = layout ?: return -1
  val lx = (x.toInt() - totalPaddingLeft + scrollX).toFloat()
  val ly = y.toInt() - totalPaddingTop + scrollY
  val line = l.getLineForVertical(ly)
  return l.getOffsetForHorizontal(line, lx)
}

/**
 * Returns true if the given character offset falls on an interactive span
 * (link or citation chip).
 */
fun TextView.isInteractiveOffset(offset: Int): Boolean {
  if (offset < 0) return false
  val spanned = text as? Spanned ?: return false
  if (spanned.getSpans(offset, offset, LinkSpan::class.java).isNotEmpty()) return true
  if (spanned.getSpans(offset, offset, CitationChipSpan::class.java).isNotEmpty()) return true
  return false
}
