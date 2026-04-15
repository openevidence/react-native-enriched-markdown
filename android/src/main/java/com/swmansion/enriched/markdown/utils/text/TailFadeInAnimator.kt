package com.swmansion.enriched.markdown.utils.text

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.text.Layout
import android.view.Choreographer
import android.widget.TextView
import java.lang.ref.WeakReference

/**
 * Fades in newly appended text by drawing an opaque overlay (in the background
 * color) on top of the tail region, then progressively making it transparent.
 *
 * This approach bypasses the Android span/layout system entirely — the text is
 * rendered at full opacity by the normal draw path, and we simply cover it with
 * a fading rectangle. This is reliable across all Android versions and layout
 * types (StaticLayout, DynamicLayout).
 *
 * The caller must invoke [drawOverlay] from the view's `onDraw` after
 * `super.onDraw()`.
 */
class TailFadeInAnimator(
  textView: TextView,
) {
  private val viewRef = WeakReference(textView)
  private val activeGroups = mutableListOf<FadeGroup>()
  private var frameCallbackRegistered = false
  private val overlayPaint = Paint()

  /** Whether there are active animations that need drawing. */
  val hasActiveAnimations: Boolean get() = activeGroups.isNotEmpty()

  /**
   * Start a fade-in animation for a new tail range.
   * Call AFTER setText so the layout is available for coordinate calculations.
   */
  fun animate(tailStart: Int, tailEnd: Int) {
    if (tailEnd <= tailStart) return
    activeGroups.add(FadeGroup(tailStart, tailEnd, System.nanoTime()))
    ensureFrameCallback()
  }

  /**
   * Draw the fade overlay on top of the already-drawn text. Call this from
   * `onDraw` after `super.onDraw(canvas)`.
   *
   * @param canvas The canvas from onDraw
   * @param layout The text layout
   * @param bgColor The background color to use for the overlay
   * @param paddingLeft Left padding of the text view
   * @param paddingTop Top padding of the text view
   */
  fun drawOverlay(
    canvas: Canvas,
    layout: Layout,
    bgColor: Int,
    paddingLeft: Int,
    paddingTop: Int,
  ) {
    if (activeGroups.isEmpty()) return

    val now = System.nanoTime()

    for (group in activeGroups) {
      val t = clamp((now - group.startTimeNanos) / FADE_DURATION_NANOS.toFloat())
      val alpha = smoothstep(t)
      // Overlay opacity: 1.0 at start (fully covering text), 0.0 at end (text revealed)
      val overlayAlpha = ((1f - alpha) * 255).toInt()
      if (overlayAlpha <= 0) continue

      overlayPaint.color = bgColor
      overlayPaint.alpha = overlayAlpha

      // Draw rectangles covering each line in the tail range
      val startLine = layout.getLineForOffset(group.tailStart.coerceAtMost(layout.text.length))
      val endLine = layout.getLineForOffset((group.tailEnd - 1).coerceIn(0, layout.text.length - 1))

      for (line in startLine..endLine) {
        val lineTop = layout.getLineTop(line).toFloat() + paddingTop
        val lineBottom = layout.getLineBottom(line).toFloat() + paddingTop

        val left: Float
        val right: Float
        if (line == startLine && line == endLine) {
          // Single line: cover from tail start to tail end
          left = layout.getPrimaryHorizontal(group.tailStart.coerceAtMost(layout.text.length)) + paddingLeft
          right = layout.getPrimaryHorizontal(group.tailEnd.coerceAtMost(layout.text.length)) + paddingLeft
        } else if (line == startLine) {
          // First line: cover from tail start to end of line
          left = layout.getPrimaryHorizontal(group.tailStart.coerceAtMost(layout.text.length)) + paddingLeft
          right = layout.getLineRight(line) + paddingLeft
        } else if (line == endLine) {
          // Last line: cover from start of line to tail end
          left = layout.getLineLeft(line) + paddingLeft
          right = layout.getPrimaryHorizontal(group.tailEnd.coerceAtMost(layout.text.length)) + paddingLeft
        } else {
          // Middle line: cover the entire line
          left = layout.getLineLeft(line) + paddingLeft
          right = layout.getLineRight(line) + paddingLeft
        }

        if (right > left) {
          canvas.drawRect(left, lineTop, right, lineBottom, overlayPaint)
        }
      }
    }
  }

  fun cancelAll() {
    activeGroups.clear()
    if (frameCallbackRegistered) {
      Choreographer.getInstance().removeFrameCallback(frameCallback)
      frameCallbackRegistered = false
    }
  }

  // --- Choreographer frame callback ---

  private val frameCallback = Choreographer.FrameCallback {
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
    val now = System.nanoTime()
    // Remove completed groups
    activeGroups.removeAll { (now - it.startTimeNanos) >= FADE_DURATION_NANOS }

    val tv = viewRef.get()
    if (tv != null && activeGroups.isNotEmpty()) {
      tv.invalidate()
      ensureFrameCallback()
    }
  }

  companion object {
    private const val FADE_DURATION_MS = 600L
    private const val FADE_DURATION_NANOS = FADE_DURATION_MS * 1_000_000L

    private fun smoothstep(t: Float): Float = t * t * (3f - 2f * t)
    private fun clamp(value: Float): Float = value.coerceIn(0f, 1f)
  }

  private data class FadeGroup(
    val tailStart: Int,
    val tailEnd: Int,
    val startTimeNanos: Long,
  )
}
