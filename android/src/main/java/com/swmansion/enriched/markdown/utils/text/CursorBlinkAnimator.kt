package com.swmansion.enriched.markdown.utils.text

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.text.Spannable
import android.text.style.ReplacementSpan
import android.view.Choreographer
import android.widget.TextView
import java.lang.ref.WeakReference

/**
 * Drives a fade in/out animation on a trailing block cursor inside a
 * TextView. Used to render the typewriter cursor during streaming idle.
 *
 * The cursor is rendered by [AnimatedCursorSpan], a ReplacementSpan that
 * inherits the surrounding text's font metrics in `getSize`. This is
 * intentional: rendering the cursor as a real character (e.g. ▌) would
 * fall back to a different font with larger ascent/descent and bump the
 * line height up whenever the cursor was visible.
 *
 * Mutating [AnimatedCursorSpan.alpha] alone is not enough to repaint: the
 * Spannable's listeners are only notified by `setSpan`, and the framework's
 * text-cache invalidation hangs off those notifications. Each tick we
 * therefore re-set the span at its existing range, which fires
 * `SpanWatcher.onSpanChanged` and triggers a redraw with the new alpha.
 */
class CursorBlinkAnimator(
  textView: TextView,
) {
  private val viewRef = WeakReference(textView)
  private var span: AnimatedCursorSpan? = null
  private var startTimeNanos: Long = 0L
  private var frameCallbackRegistered = false

  /** Whether the animator currently has an attached cursor span. */
  val isActive: Boolean get() = span != null

  /**
   * Begin animating [span]. Captures the current time as t=0 so the cursor
   * fades in from fully transparent. The base color is read off the span.
   */
  fun start(span: AnimatedCursorSpan) {
    this.span = span
    startTimeNanos = System.nanoTime()
    // Start fully transparent so the cursor fades in cleanly on the next
    // frame instead of flashing at full opacity.
    span.alpha = 0f
    ensureFrameCallback()
  }

  fun stop() {
    span = null
    if (frameCallbackRegistered) {
      Choreographer.getInstance().removeFrameCallback(frameCallback)
      frameCallbackRegistered = false
    }
  }

  private val frameCallback =
    Choreographer.FrameCallback {
      frameCallbackRegistered = false
      tick()
    }

  private fun ensureFrameCallback() {
    if (!frameCallbackRegistered) {
      frameCallbackRegistered = true
      Choreographer.getInstance().postFrameCallback(frameCallback)
    }
  }

  private fun tick() {
    val sp = span ?: return
    val tv = viewRef.get()
    if (tv == null) {
      stop()
      return
    }
    val text = tv.text as? Spannable
    if (text == null) {
      stop()
      return
    }
    val start = text.getSpanStart(sp)
    val end = text.getSpanEnd(sp)
    if (start < 0 || end <= start) {
      // Span got detached (text was replaced); nothing to animate.
      stop()
      return
    }

    val elapsedSec = (System.nanoTime() - startTimeNanos) / 1_000_000_000.0
    val phase = (elapsedSec / PERIOD_SEC) % 1.0
    // Triangle wave 0 → 1 → 0, then smoothstep to approximate easeInOut.
    // Capped at MAX_ALPHA so the cursor reads as subtle rather than fully
    // opaque at peak.
    val tri = if (phase < 0.5) phase * 2.0 else (1.0 - phase) * 2.0
    val alpha = (tri * tri * (3.0 - 2.0 * tri) * MAX_ALPHA).toFloat()

    sp.alpha = alpha
    // Re-set the span at the same range to fire SpanWatcher.onSpanChanged,
    // which is what triggers the TextView to redraw with the new alpha.
    text.setSpan(sp, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)

    ensureFrameCallback()
  }

  companion object {
    private const val PERIOD_SEC = 1.6
    private const val MAX_ALPHA = 0.85
  }
}

/**
 * Replacement span that paints the trailing cursor as a vertical bar.
 *
 * Inherits the surrounding paint's font metrics in [getSize] so the line
 * containing the cursor matches the line height of the rest of the
 * paragraph. The width is proportional to the surrounding text size to
 * mimic the visual weight of a block cursor.
 *
 * [alpha] is mutated by [CursorBlinkAnimator] to drive the blink.
 */
class AnimatedCursorSpan(
  var baseColor: Int,
) : ReplacementSpan() {
  /** Multiplier applied to the base color's alpha channel, in [0, 1]. */
  var alpha: Float = 1f

  private val drawPaint =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
    }

  override fun getSize(
    paint: Paint,
    text: CharSequence,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    if (fm != null) {
      val pfm = paint.fontMetricsInt
      fm.ascent = pfm.ascent
      fm.descent = pfm.descent
      fm.top = pfm.top
      fm.bottom = pfm.bottom
      fm.leading = pfm.leading
    }
    return (paint.textSize * CURSOR_WIDTH_RATIO).toInt().coerceAtLeast(2)
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
    val baseAlpha = Color.alpha(baseColor)
    val effective = (baseAlpha * alpha.coerceIn(0f, 1f)).toInt().coerceIn(0, 255)
    if (effective <= 0) return
    drawPaint.color =
      Color.argb(
        effective,
        Color.red(baseColor),
        Color.green(baseColor),
        Color.blue(baseColor),
      )
    val width = (paint.textSize * CURSOR_WIDTH_RATIO).coerceAtLeast(2f)
    val pfm = paint.fontMetricsInt
    // Span the font's ascent..descent so the bar visually fills the text
    // band of the line, like a block cursor — without exceeding it.
    val cursorTop = (y + pfm.ascent).toFloat()
    val cursorBottom = (y + pfm.descent).toFloat()
    canvas.drawRect(x, cursorTop, x + width, cursorBottom, drawPaint)
  }

  companion object {
    private const val CURSOR_WIDTH_RATIO = 0.5f
  }
}
