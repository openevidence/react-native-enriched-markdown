package com.swmansion.enriched.markdown.utils.text.view

import android.graphics.Color
import android.os.Build
import android.view.textclassifier.TextClassifier
import androidx.appcompat.widget.AppCompatTextView
import androidx.core.view.ViewCompat
import com.swmansion.enriched.markdown.accessibility.MarkdownAccessibilityHelper
import com.swmansion.enriched.markdown.utils.text.SafeEditableFactory
import com.swmansion.enriched.markdown.utils.text.SafeSpannableFactory

fun AppCompatTextView.setupAsMarkdownTextView(accessibilityHelper: MarkdownAccessibilityHelper) {
  // Drops the (-1, -1) setSpan that Samsung's selection drag pushes when the
  // handle leaves the text bounds — would otherwise crash SpannableStringBuilder.
  // Both factories: setTextIsSelectable below switches the buffer through
  // BufferType.SPANNABLE; setText(.., EDITABLE) at render time uses Editable.
  setEditableFactory(SafeEditableFactory)
  setSpannableFactory(SafeSpannableFactory)
  setBackgroundColor(Color.TRANSPARENT)
  includeFontPadding = false
  // setTextIsSelectable must be called BEFORE setting movementMethod because
  // it internally overrides movementMethod to ArrowKeyMovementMethod.
  setTextIsSelectable(true)
  movementMethod = LinkLongPressMovementMethod.createInstance()
  customSelectionActionModeCallback = createSelectionActionModeCallback(this)
  // SmartSelectSprite crashes with "Center point is not inside any of the
  // rectangles!" when Layout.getSelection returns empty rects near an
  // ImageSpan (ReplacementSpan). NO_OP makes skipTextClassification() return
  // true, bypassing the entire SmartSelectSprite code path. Regular text
  // selection (long-press, handles, copy/paste) still works; only automatic
  // entity detection (phone numbers, addresses) is disabled.
  //
  // TODO: Add an Android-only `enableSmartTextSelection` prop that skips this
  // NO_OP override. This would let users who don't render images opt in to
  // entity detection. The prop should default to false and its docs should
  // warn that enabling it with markdown containing images will crash.
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    setTextClassifier(TextClassifier.NO_OP)
  }
  isVerticalScrollBarEnabled = false
  isHorizontalScrollBarEnabled = false
  ViewCompat.setAccessibilityDelegate(this, accessibilityHelper)
}

fun AppCompatTextView.applySelectableState(selectable: Boolean) {
  if (isTextSelectable == selectable) {
    // Even when the selectable state hasn't changed, ensure the movement
    // method is correct — setTextIsSelectable overrides it on every call.
    if (movementMethod !is LinkLongPressMovementMethod) {
      movementMethod = LinkLongPressMovementMethod.createInstance()
    }
    return
  }
  setTextIsSelectable(selectable)
  // setTextIsSelectable overrides movementMethod to ArrowKeyMovementMethod,
  // so we must set our custom movement method AFTER.
  movementMethod = LinkLongPressMovementMethod.createInstance()
  if (!selectable && !isClickable) isClickable = true
}
