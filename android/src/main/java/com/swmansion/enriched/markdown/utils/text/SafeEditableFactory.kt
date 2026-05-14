package com.swmansion.enriched.markdown.utils.text

import android.text.Editable
import android.text.Spannable
import android.text.SpannableStringBuilder

/**
 * Buffer that drops setSpan calls with a negative start/end.
 *
 * Samsung's Editor.semSetSelection passes (-1, -1) to Selection.setSelection
 * when a selection-handle drag resolves to an offset outside the text (gap,
 * image span, below last line). AOSP guards this; Samsung doesn't, and the
 * raw setSpan(-1, -1) crashes SpannableStringBuilder.checkRange.
 */
private class SafeSpannableStringBuilder(
  text: CharSequence,
) : SpannableStringBuilder(text) {
  override fun setSpan(
    what: Any?,
    start: Int,
    end: Int,
    flags: Int,
  ) {
    if (start < 0 || end < 0) return
    super.setSpan(what, start, end, flags)
  }
}

object SafeEditableFactory : Editable.Factory() {
  override fun newEditable(source: CharSequence): Editable = SafeSpannableStringBuilder(source)
}

object SafeSpannableFactory : Spannable.Factory() {
  override fun newSpannable(source: CharSequence): Spannable = SafeSpannableStringBuilder(source)
}
