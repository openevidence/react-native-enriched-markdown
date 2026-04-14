package com.swmansion.enriched.markdown.utils.text

import android.graphics.Color
import android.text.Spannable
import android.text.style.ForegroundColorSpan
import android.util.Log
import android.view.Choreographer
import android.widget.TextView
import java.lang.ref.WeakReference

/**
 * Animates newly appended text by fading it in from transparent to its original
 * foreground color, matching the iOS ENRMTailFadeInAnimator approach:
 *
 * 1. Snapshot original foreground colors for the tail range.
 * 2. Pre-zero the tail's alpha (set all foreground colors to transparent).
 * 3. Use [Choreographer] frame callbacks to progressively restore original colors.
 *
 * Each call to [animate] creates an independent fade group so overlapping
 * animations (from rapid streaming) run concurrently without interfering.
 */
class TailFadeInAnimator(
  textView: TextView,
) {
  private val viewRef = WeakReference(textView)
  private val activeGroups = mutableListOf<FadeGroup>()
  private var frameCallbackRegistered = false

  /**
   * Pre-zeros the tail range on the given [Spannable] and starts a fade-in
   * animation for that range. Call this BEFORE setting text on the view.
   *
   * @param text The spannable text that will be set on the view
   * @param tailStart Start index of the new content
   * @param tailEnd End index of the new content
   */
  fun prepareAndAnimate(
    text: Spannable,
    tailStart: Int,
    tailEnd: Int,
  ) {
    if (tailEnd <= tailStart) return

    val group = snapshotGroup(text, tailStart, tailEnd)
    if (group == null) {
      Log.d(TAG, "prepareAndAnimate: snapshotGroup returned null for [$tailStart,$tailEnd)")
      return
    }
    Log.d(TAG, "prepareAndAnimate: [$tailStart,$tailEnd) entries=${group.entries.size}")

    // Pre-zero: replace all foreground colors in the tail with transparent versions.
    // This ensures the text is invisible on the very first frame after setText.
    for (entry in group.entries) {
      val transparent = Color.argb(0, Color.red(entry.originalColor), Color.green(entry.originalColor), Color.blue(entry.originalColor))
      text.setSpan(
        ForegroundColorSpan(transparent),
        entry.start,
        entry.end,
        entry.flags,
      )
    }

    group.startTimeNanos = System.nanoTime()
    activeGroups.add(group)

    ensureFrameCallback()
  }

  /**
   * Pre-applies in-progress fade groups to a new [Spannable] that is about to
   * replace the current text. This ensures seamless transitions when text is
   * updated mid-animation (the iOS equivalent is `preApplyToAttributedString:`).
   */
  fun preApplyToSpannable(text: Spannable) {
    if (activeGroups.isEmpty()) return
    val now = System.nanoTime()

    for (group in activeGroups) {
      val t = clamp((now - group.startTimeNanos) / FADE_DURATION_NANOS.toFloat())
      val alpha = smoothstep(t)

      for (entry in group.entries) {
        if (entry.end > text.length) continue
        val fadedColor = colorWithAlpha(entry.originalColor, alpha)
        // Remove any existing ForegroundColorSpan in this range first
        removeSpansInRange(text, entry.start, entry.end)
        text.setSpan(
          ForegroundColorSpan(fadedColor),
          entry.start,
          entry.end,
          entry.flags,
        )
      }
    }
  }

  fun cancelAll() {
    activeGroups.clear()
    // Frame callback will self-remove when activeGroups is empty
  }

  // --- Frame callback ---

  private val frameCallback =
    Choreographer.FrameCallback {
      frameCallbackRegistered = false
      step(System.nanoTime())
    }

  private fun ensureFrameCallback() {
    if (!frameCallbackRegistered) {
      frameCallbackRegistered = true
      Choreographer.getInstance().postFrameCallback(frameCallback)
    }
  }

  private fun step(frameTimeNanos: Long) {
    val textView = viewRef.get()
    val spannable = textView?.text as? Spannable
    if (textView == null || spannable == null) {
      Log.d(TAG, "step: textView=${textView != null} spannable=${spannable != null} textType=${textView?.text?.javaClass?.simpleName} — aborting")
      activeGroups.clear()
      return
    }

    val completedIndices = mutableListOf<Int>()

    for ((index, group) in activeGroups.withIndex()) {
      val t = clamp((frameTimeNanos - group.startTimeNanos) / FADE_DURATION_NANOS.toFloat())
      val alpha = smoothstep(t)

      for (entry in group.entries) {
        if (entry.end > spannable.length) continue
        val fadedColor = colorWithAlpha(entry.originalColor, alpha)
        removeSpansInRange(spannable, entry.start, entry.end)
        spannable.setSpan(
          ForegroundColorSpan(fadedColor),
          entry.start,
          entry.end,
          entry.flags,
        )
      }

      if (t >= 1f) {
        completedIndices.add(index)
      }
    }

    // Remove completed groups in reverse order to keep indices valid
    for (i in completedIndices.asReversed()) {
      val group = activeGroups.removeAt(i)
      // Restore exact original colors
      for (entry in group.entries) {
        if (entry.end > spannable.length) continue
        removeSpansInRange(spannable, entry.start, entry.end)
        spannable.setSpan(
          ForegroundColorSpan(entry.originalColor),
          entry.start,
          entry.end,
          entry.flags,
        )
      }
    }

    textView.invalidate()

    if (activeGroups.isNotEmpty()) {
      Log.d(TAG, "step: ${activeGroups.size} groups remaining, scheduling next frame")
      ensureFrameCallback()
    } else {
      Log.d(TAG, "step: all groups completed")
    }
  }

  // --- Helpers ---

  /**
   * Snapshots all foreground color entries for the given range.
   * For regions without an explicit ForegroundColorSpan, uses the view's
   * current text color as the default.
   */
  private fun snapshotGroup(
    text: Spannable,
    start: Int,
    end: Int,
  ): FadeGroup? {
    val textView = viewRef.get() ?: return null
    val defaultColor = textView.currentTextColor
    val entries = mutableListOf<ColorEntry>()

    // Build a list of sub-ranges with their foreground colors.
    // Regions without an explicit ForegroundColorSpan use the default text color.
    var cursor = start
    val spans =
      text
        .getSpans(start, end, ForegroundColorSpan::class.java)
        .sortedBy { text.getSpanStart(it) }

    for (span in spans) {
      val spanStart = text.getSpanStart(span).coerceAtLeast(start)
      val spanEnd = text.getSpanEnd(span).coerceAtMost(end)
      val flags = text.getSpanFlags(span)

      // Gap before this span uses default color
      if (cursor < spanStart) {
        entries.add(ColorEntry(cursor, spanStart, defaultColor, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE))
      }

      entries.add(ColorEntry(spanStart, spanEnd, span.foregroundColor, flags))
      // Remove the original span so we can replace it with our animated version
      text.removeSpan(span)
      cursor = spanEnd
    }

    // Trailing gap after last span
    if (cursor < end) {
      entries.add(ColorEntry(cursor, end, defaultColor, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE))
    }

    return if (entries.isNotEmpty()) FadeGroup(entries) else null
  }

  private fun removeSpansInRange(
    spannable: Spannable,
    start: Int,
    end: Int,
  ) {
    val existing = spannable.getSpans(start, end, ForegroundColorSpan::class.java)
    for (span in existing) {
      val ss = spannable.getSpanStart(span)
      val se = spannable.getSpanEnd(span)
      // Only remove spans that are fully contained in the range
      if (ss >= start && se <= end) {
        spannable.removeSpan(span)
      }
    }
  }

  companion object {
    private const val TAG = "ENRM_FadeAnim"
    private const val FADE_DURATION_MS = 600L
    private const val FADE_DURATION_NANOS = FADE_DURATION_MS * 1_000_000L

    /** Smoothstep easing: t * t * (3 - 2t), matching iOS implementation. */
    private fun smoothstep(t: Float): Float = t * t * (3f - 2f * t)

    private fun clamp(value: Float): Float = value.coerceIn(0f, 1f)

    private fun colorWithAlpha(
      color: Int,
      alpha: Float,
    ): Int {
      val a = ((color ushr 24) * alpha).toInt()
      return (a shl 24) or (color and 0x00FFFFFF)
    }
  }

  private data class ColorEntry(
    val start: Int,
    val end: Int,
    val originalColor: Int,
    val flags: Int,
  )

  private class FadeGroup(
    val entries: List<ColorEntry>,
  ) {
    var startTimeNanos: Long = 0L
  }
}
