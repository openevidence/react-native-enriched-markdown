package com.swmansion.enriched.markdown.utils.text

import android.graphics.Color
import android.text.TextPaint
import android.text.style.CharacterStyle
import android.text.style.UpdateAppearance
import android.view.Choreographer
import android.widget.TextView
import java.lang.ref.WeakReference

/**
 * Drives a fade in/out animation on the foreground color alpha of a single
 * character range inside a TextView. Used to render the trailing block
 * cursor (▌) during streaming idle.
 *
 * The animation matches the web typewriter cursor: 1.25s period with a
 * smoothstep-eased fade 0 → 1 → 0, repeated infinitely. We update the
 * cursor's [AnimatedColorSpan] each Choreographer frame and call
 * [TextView.invalidate] so the next draw picks up the new color.
 */
class CursorBlinkAnimator(
  textView: TextView,
) {
  private val viewRef = WeakReference(textView)
  private var span: AnimatedColorSpan? = null
  private var startTimeNanos: Long = 0L
  private var frameCallbackRegistered = false

  /** Whether the animator currently has an attached cursor span. */
  val isActive: Boolean get() = span != null

  /**
   * Begin animating [span]. Captures the current time as t=0 so the cursor
   * fades in from fully transparent. The base color is read off the span.
   */
  fun start(span: AnimatedColorSpan) {
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

    val elapsedSec = (System.nanoTime() - startTimeNanos) / 1_000_000_000.0
    val phase = (elapsedSec / PERIOD_SEC) % 1.0
    // Triangle wave 0 → 1 → 0, then smoothstep to approximate easeInOut.
    val tri = if (phase < 0.5) phase * 2.0 else (1.0 - phase) * 2.0
    val alpha = (tri * tri * (3.0 - 2.0 * tri)).toFloat()

    sp.alpha = alpha
    tv.invalidate()

    ensureFrameCallback()
  }

  companion object {
    private const val PERIOD_SEC = 1.6
  }
}

/**
 * Foreground color span whose alpha can be mutated frame-by-frame without
 * re-running text layout. The TextView re-applies the span's draw state on
 * every redraw, so updating [alpha] and invalidating the view is enough to
 * make the rendered character fade.
 */
class AnimatedColorSpan(
  var baseColor: Int,
) : CharacterStyle(),
  UpdateAppearance {
  /** Multiplier applied to the base color's alpha channel, in [0, 1]. */
  var alpha: Float = 1f

  override fun updateDrawState(tp: TextPaint) {
    val baseAlpha = Color.alpha(baseColor)
    val effective = (baseAlpha * alpha.coerceIn(0f, 1f)).toInt().coerceIn(0, 255)
    tp.color =
      Color.argb(
        effective,
        Color.red(baseColor),
        Color.green(baseColor),
        Color.blue(baseColor),
      )
  }
}
