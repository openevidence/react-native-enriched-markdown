package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.text.TextPaint
import android.text.style.ReplacementSpan
import android.util.TypedValue
import android.widget.TextView
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.utils.text.ImageDownloader
import java.lang.ref.WeakReference
import kotlin.math.roundToInt

/**
 * A [ReplacementSpan] that draws a citation chip directly, matching the iOS CitationChipView design.
 *
 * Layout: [4dp margin] [8dp pad] [favicon 14dp] [4dp gap] [label] [8dp pad] [2dp margin]
 *   or    [4dp margin] [8dp pad] [label] [8dp pad] [2dp margin]  when no favicon URL is provided.
 *
 * Height: 20dp.  Max chip width: 90dp.
 * Background: #FCEDE8.  Text: #343231 at 11sp system regular.
 * Favicon: 14dp circular image loaded asynchronously.
 */
class CitationChipSpan(
  private val label: String,
  private val faviconUrl: String,
  val numbers: String,
  private val onCitationPress: ((String) -> Unit)?,
  private val styleCache: SpanStyleCache,
  private val context: Context,
) : ReplacementSpan() {
  private val density = context.resources.displayMetrics.density
  private val metrics = context.resources.displayMetrics

  // dp to px
  private val chipHeightPx = (CHIP_HEIGHT_DP * density).roundToInt()
  private val hPaddingPx = HORIZONTAL_PADDING_DP * density
  private val faviconSizePx = FAVICON_SIZE_DP * density
  private val faviconGapPx = FAVICON_GAP_DP * density
  private val leftMarginPx = LEFT_MARGIN_DP * density
  private val rightMarginPx = RIGHT_MARGIN_DP * density

  // Use style config values, falling back to defaults
  private val chipBgColor = styleCache.citationBackgroundColor.takeIf { it != 0 } ?: DEFAULT_BACKGROUND_COLOR
  private val chipTextColor = styleCache.citationColor.takeIf { it != 0 } ?: DEFAULT_TEXT_COLOR
  private val chipFontSizeSp = styleCache.citationFontSize.takeIf { it > 0f } ?: DEFAULT_FONT_SIZE_SP
  private val chipBorderRadius = styleCache.citationBorderRadius

  // sp to px for font size
  private val fontSizePx = TypedValue.applyDimension(
    TypedValue.COMPLEX_UNIT_SP, chipFontSizeSp, metrics
  )

  private val hasFavicon = faviconUrl.isNotEmpty()
  @Volatile private var faviconBitmap: Bitmap? = null
  private var viewRef: WeakReference<TextView>? = null
  private val mainHandler = Handler(Looper.getMainLooper())

  // Paint objects reused across draw calls
  private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    color = chipBgColor
    style = Paint.Style.FILL
  }

  private val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
    color = chipTextColor
    textSize = fontSizePx
    typeface = Typeface.DEFAULT
  }

  private val faviconPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

  init {
    if (hasFavicon) {
      loadFavicon()
    }
  }

  private fun loadFavicon() {
    ImageDownloader.download(context, faviconUrl) { bitmap ->
      if (bitmap != null) {
        val size = faviconSizePx.roundToInt()
        val scaled = if (bitmap.width != size || bitmap.height != size) {
          Bitmap.createScaledBitmap(bitmap, size, size, true)
        } else {
          bitmap
        }
        faviconBitmap = scaled
        // Always invalidate on the main thread. The callback may arrive on a
        // background thread (synchronous ImageCache hit) or the main thread
        // (OkHttp network response). Post to main to guarantee we invalidate
        // after registerTextView has run (which also runs on main thread).
        mainHandler.post { invalidateChipDisplay() }
      }
    }
  }

  fun registerTextView(view: TextView) {
    viewRef = WeakReference(view)
    // If the favicon was already loaded, invalidate now.
    if (faviconBitmap != null) {
      invalidateChipDisplay()
    }
  }

  /**
   * Forces the text view to re-draw the chip. With DynamicLayout (EDITABLE
   * buffer), we need to poke the text so the layout re-queries spans. A plain
   * invalidate() is not enough because DynamicLayout caches span rendering.
   */
  private fun invalidateChipDisplay() {
    val tv = viewRef?.get() ?: return
    val editable = tv.text as? android.text.Editable
    if (editable != null) {
      // Find our span in the text and trigger a span change notification
      // by removing and re-adding it. DynamicLayout's SpanWatcher will
      // pick up the change and invalidate the affected line.
      val start = editable.getSpanStart(this)
      val end = editable.getSpanEnd(this)
      if (start >= 0 && end >= 0) {
        val flags = editable.getSpanFlags(this)
        editable.removeSpan(this)
        editable.setSpan(this, start, end, flags)
        return
      }
    }
    // Fallback: just invalidate the view
    tv.invalidate()
  }

  fun onClick(widget: TextView) {
    onCitationPress?.invoke(numbers)
      ?: (widget as? EnrichedMarkdownText)?.emitOnCitationPress(numbers)
  }

  /**
   * Calculates the total width of the chip + margins, and adjusts font metrics
   * so the chip is vertically centered on the line.
   */
  override fun getSize(
    paint: Paint,
    text: CharSequence,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    val chipWidth = computeChipWidth()
    val totalWidth = (leftMarginPx + chipWidth + rightMarginPx).roundToInt()

    if (fm != null) {
      // Center the chip vertically in the line
      val fontHeight = fm.descent - fm.ascent
      val diff = chipHeightPx - fontHeight
      if (diff > 0) {
        fm.ascent -= diff / 2
        fm.descent += (diff + 1) / 2
        fm.top = fm.ascent
        fm.bottom = fm.descent
      }
    }

    return totalWidth
  }

  /**
   * Draws the full chip: background pill, favicon (if loaded), and label text.
   */
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
    // Store reference to the text view for async favicon loading
    // (the draw method is called with the canvas from the TextView)

    val chipWidth = computeChipWidth()
    val chipX = x + leftMarginPx
    // Align to the text baseline: center the chip between ascent and descent.
    // Using the baseline (y param) avoids misalignment on the last line of a
    // paragraph where top/bottom include extra spacing from the text view.
    val fm = paint.fontMetricsInt
    val fontHeight = fm.descent - fm.ascent
    val chipY = y.toFloat() + fm.ascent + (fontHeight - chipHeightPx) / 2f

    // Draw pill background
    val borderRadius = if (chipBorderRadius > 0f) chipBorderRadius * density else chipHeightPx / 2f
    val rect = RectF(chipX, chipY, chipX + chipWidth, chipY + chipHeightPx)
    canvas.drawRoundRect(rect, borderRadius, borderRadius, bgPaint)

    // Current drawing X inside the chip
    var drawX = chipX + hPaddingPx

    // Draw favicon if available
    if (hasFavicon) {
      val bitmap = faviconBitmap
      if (bitmap != null) {
        val faviconY = chipY + (chipHeightPx - faviconSizePx) / 2f

        // Draw circular favicon using BitmapShader
        canvas.save()
        val shader = BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        val matrix = android.graphics.Matrix()
        val scaleX = faviconSizePx / bitmap.width
        val scaleY = faviconSizePx / bitmap.height
        matrix.setScale(scaleX, scaleY)
        matrix.postTranslate(drawX, faviconY)
        shader.setLocalMatrix(matrix)
        faviconPaint.shader = shader
        val cx = drawX + faviconSizePx / 2f
        val cy = faviconY + faviconSizePx / 2f
        canvas.drawCircle(cx, cy, faviconSizePx / 2f, faviconPaint)
        faviconPaint.shader = null
        canvas.restore()
      }
      // Always reserve space for favicon (even if not loaded yet)
      drawX += faviconSizePx + faviconGapPx
    }

    // Draw label text — no truncation needed since the chip is sized to fit
    val textMetrics = textPaint.fontMetrics
    val textHeight = textMetrics.descent - textMetrics.ascent
    val textY = chipY + (chipHeightPx - textHeight) / 2f - textMetrics.ascent
    canvas.drawText(label, drawX, textY, textPaint)
  }

  /**
   * Computes the chip width (without margins).
   * No max-width cap: the JS preprocessing already truncates labels to a
   * reasonable length (~14 chars + " + N" suffix), so the chip grows to fit.
   */
  private fun computeChipWidth(): Float {
    val labelWidth = textPaint.measureText(label)
    return if (hasFavicon) {
      hPaddingPx + faviconSizePx + faviconGapPx + labelWidth + hPaddingPx
    } else {
      hPaddingPx + labelWidth + hPaddingPx
    }
  }

  companion object {
    private const val CHIP_HEIGHT_DP = 20f
    private const val HORIZONTAL_PADDING_DP = 8f
    private const val FAVICON_SIZE_DP = 14f
    private const val FAVICON_GAP_DP = 4f
    private const val LEFT_MARGIN_DP = 4f
    private const val RIGHT_MARGIN_DP = 2f

    private const val DEFAULT_FONT_SIZE_SP = 11f
    private const val DEFAULT_BACKGROUND_COLOR = 0xFFFCEDE8.toInt() // #FCEDE8
    private const val DEFAULT_TEXT_COLOR = 0xFF343231.toInt() // #343231
  }
}
