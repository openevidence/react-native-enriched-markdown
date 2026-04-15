package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.text.style.ReplacementSpan
import android.util.Log
import android.view.View.MeasureSpec
import com.agog.mathdisplay.MTMathView
import kotlin.math.roundToInt

class MathInlineSpan(
  private val context: Context,
  internal val latex: String,
  internal val fontSize: Float,
  private val textColor: Int,
  /** If true, scale the bitmap to fit the text view width during draw. */
  private val scaleToFit: Boolean = false,
) : ReplacementSpan() {
  private var cachedBitmap: Bitmap? = null
  private var naturalWidth = 0
  private var cachedWidth = 0
  private var naturalAscent = 0f
  private var naturalDescent = 0f
  private var mathAscent = 0f
  private var mathDescent = 0f
  private var renderFailed = false
  private var scaleFactor = 1f
  private var viewRef: java.lang.ref.WeakReference<android.widget.TextView>? = null

  fun registerTextView(view: android.widget.TextView) {
    viewRef = java.lang.ref.WeakReference(view)
  }

  private fun prepareResources() {
    if (cachedBitmap != null && !cachedBitmap!!.isRecycled) return
    if (renderFailed) return

    try {
      val mathView =
        MTMathView(context).apply {
          labelMode = MTMathView.MTMathViewMode.KMTMathViewModeText
          textAlignment = MTMathView.MTTextAlignment.KMTTextAlignmentLeft
          this.fontSize = this@MathInlineSpan.fontSize
          this.textColor = this@MathInlineSpan.textColor
          this.latex = this@MathInlineSpan.latex
        }

      val spec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
      mathView.measure(spec, spec)

      val width = mathView.measuredWidth.coerceAtLeast(1)
      val height = mathView.measuredHeight.coerceAtLeast(1)

      calculateMetrics(mathView, height)

      mathView.layout(0, 0, width, height)

      val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
      mathView.draw(Canvas(bitmap))
      cachedBitmap = bitmap
      naturalWidth = width
      cachedWidth = width
      naturalAscent = mathAscent
      naturalDescent = mathDescent
    } catch (e: Exception) {
      Log.e(TAG, "MathInlineSpan render failed for latex='$latex': ${e.message}", e)
      renderFailed = true
      val estimatedHeight = fontSize * 1.2f
      cachedWidth = (fontSize * latex.length * 0.6f).toInt().coerceAtLeast(1)
      mathAscent = estimatedHeight * 0.7f
      mathDescent = estimatedHeight * 0.3f
    }
  }

  private fun calculateMetrics(
    view: MTMathView,
    height: Int,
  ) {
    try {
      val dl = DISPLAY_LIST_FIELD?.get(view)
      if (dl != null) {
        mathAscent = GET_ASCENT_METHOD?.invoke(dl) as? Float ?: (height * 0.7f)
        mathDescent = GET_DESCENT_METHOD?.invoke(dl) as? Float ?: (height * 0.3f)
      } else {
        mathAscent = height * 0.7f
        mathDescent = height * 0.3f
      }
    } catch (e: Exception) {
      mathAscent = height * 0.7f
      mathDescent = height * 0.3f
    }
  }

  /**
   * Computes the scale factor so the bitmap fits within the given [availableWidth].
   * Only applied when [scaleToFit] is true.
   */
  private fun computeScale(availableWidth: Int) {
    if (!scaleToFit || naturalWidth <= 0 || availableWidth <= 0 || naturalWidth <= availableWidth) {
      scaleFactor = 1f
      cachedWidth = naturalWidth
      mathAscent = naturalAscent
      mathDescent = naturalDescent
      return
    }
    scaleFactor = availableWidth.toFloat() / naturalWidth
    cachedWidth = availableWidth
    mathAscent = naturalAscent * scaleFactor
    mathDescent = naturalDescent * scaleFactor
  }

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    prepareResources()

    // Compute scale using the text view's content width so the layout
    // system knows the actual (scaled) width for positioning.
    if (scaleToFit && naturalWidth > 0) {
      val tv = viewRef?.get()
      if (tv != null) {
        val availableWidth = tv.width - tv.totalPaddingLeft - tv.totalPaddingRight
        computeScale(availableWidth)
      }
    }

    fm?.apply {
      ascent = -mathAscent.roundToInt()
      top = ascent
      descent = mathDescent.roundToInt()
      bottom = descent
    }

    return cachedWidth
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence?,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    prepareResources()
    val bmp = cachedBitmap
    if (bmp != null) {
      val bitmapY = y - mathAscent
      if (scaleFactor < 1f) {
        canvas.save()
        canvas.translate(x, bitmapY)
        canvas.scale(scaleFactor, scaleFactor)
        canvas.drawBitmap(bmp, 0f, 0f, paint)
        canvas.restore()
      } else {
        canvas.drawBitmap(bmp, x, bitmapY, paint)
      }
    } else if (renderFailed) {
      canvas.drawText(latex, x, y.toFloat(), paint)
    }
  }

  companion object {
    private const val TAG = "MathInlineSpan"

    private val DISPLAY_LIST_FIELD =
      runCatching {
        MTMathView::class.java.getDeclaredField("displayList").apply { isAccessible = true }
      }.getOrNull()

    private val GET_ASCENT_METHOD =
      runCatching {
        DISPLAY_LIST_FIELD?.type?.getMethod("getAscent")
      }.getOrNull()

    private val GET_DESCENT_METHOD =
      runCatching {
        DISPLAY_LIST_FIELD?.type?.getMethod("getDescent")
      }.getOrNull()
  }
}
