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
 * A [ReplacementSpan] that draws a citation chip directly, matching the iOS design.
 *
 * Dimensions scale with the surrounding text's font size. At a 17sp baseline
 * the chip is 18dp tall with a 10sp label, 6dp internal padding, a 12dp
 * favicon, a 3dp favicon gap, and a 3dp trailing buffer. All values scale
 * proportionally, and chip height is capped at the surrounding font's line
 * height so the chip never inflates the line.
 *
 * Leading separation is not baked into the span — CitationRenderer injects a
 * space before the chip so wrap boundaries are handled naturally by the
 * layout engine.
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

  private val chipBgColor = styleCache.citationBackgroundColor.takeIf { it != 0 } ?: DEFAULT_BACKGROUND_COLOR
  private val chipTextColor = styleCache.citationColor.takeIf { it != 0 } ?: DEFAULT_TEXT_COLOR

  // >0 = explicit user override (sp), 0 = auto-scale to surrounding font.
  private val configFontSizeSp = styleCache.citationFontSize

  // >0 = explicit user override (dp), 0 = pill (chipHeight / 2).
  private val configBorderRadiusDp = styleCache.citationBorderRadius

  private val hasFavicon = faviconUrl.isNotEmpty()

  // Computed per-layout in getSize(), consumed by draw().
  private var chipHeightPx = 0f
  private var chipWidth = 0f
  private var chipFontSizePx = 0f
  private var hPaddingPx = 0f
  private var faviconSizePx = 0f
  private var faviconGapPx = 0f
  private var rightMarginPx = 0f
  private var borderRadiusPx = 0f

  @Volatile private var faviconBitmap: Bitmap? = null
  private var viewRef: WeakReference<TextView>? = null
  private val mainHandler = Handler(Looper.getMainLooper())

  private val bgPaint =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = chipBgColor
      style = Paint.Style.FILL
    }

  private val textPaint =
    TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
      color = chipTextColor
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
        faviconBitmap = bitmap
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
      val start = editable.getSpanStart(this)
      val end = editable.getSpanEnd(this)
      if (start >= 0 && end >= 0) {
        val flags = editable.getSpanFlags(this)
        editable.removeSpan(this)
        editable.setSpan(this, start, end, flags)
        return
      }
    }
    tv.invalidate()
  }

  fun onClick(widget: TextView) {
    onCitationPress?.invoke(numbers)
      ?: (widget as? EnrichedMarkdownText)?.emitOnCitationPress(numbers)
  }

  /**
   * Computes chip dimensions from the surrounding paint (font size + line
   * height) and returns the total span width.
   */
  override fun getSize(
    paint: Paint,
    text: CharSequence,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    val surroundingFontPx = paint.textSize
    val paintFm = paint.fontMetricsInt
    val lineHeightPx = (paintFm.descent - paintFm.ascent).toFloat()

    val desiredHeight = surroundingFontPx * (BASE_CHIP_HEIGHT_DP / BASE_SURROUNDING_FONT_SP)
    chipHeightPx = minOf(desiredHeight, lineHeightPx)
    val scale = chipHeightPx / (BASE_CHIP_HEIGHT_DP * density)

    val autoFontPx = chipHeightPx * (BASE_CHIP_FONT_SIZE_SP / BASE_CHIP_HEIGHT_DP)
    chipFontSizePx =
      if (configFontSizeSp > 0f) {
        val explicitPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, configFontSizeSp, metrics)
        minOf(explicitPx, chipHeightPx * 0.85f)
      } else {
        autoFontPx
      }

    hPaddingPx = BASE_HORIZONTAL_PADDING_DP * density * scale
    faviconSizePx = BASE_FAVICON_SIZE_DP * density * scale
    faviconGapPx = BASE_FAVICON_GAP_DP * density * scale
    rightMarginPx = BASE_RIGHT_MARGIN_DP * density * scale

    borderRadiusPx =
      if (configBorderRadiusDp > 0f) {
        minOf(configBorderRadiusDp * density, chipHeightPx / 2f)
      } else {
        chipHeightPx / 2f
      }

    textPaint.textSize = chipFontSizePx

    val labelWidth = textPaint.measureText(label)
    chipWidth =
      if (hasFavicon) {
        hPaddingPx + faviconSizePx + faviconGapPx + labelWidth + hPaddingPx
      } else {
        hPaddingPx + labelWidth + hPaddingPx
      }

    // No line-height expansion: chipHeightPx is capped at lineHeightPx above,
    // so the chip always fits. fm (output) is left at the paint's metrics.

    return (chipWidth + rightMarginPx).roundToInt()
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
    val fm = paint.fontMetricsInt
    val fontHeight = fm.descent - fm.ascent
    val chipY = y.toFloat() + fm.ascent + (fontHeight - chipHeightPx) / 2f

    val rect = RectF(x, chipY, x + chipWidth, chipY + chipHeightPx)
    canvas.drawRoundRect(rect, borderRadiusPx, borderRadiusPx, bgPaint)

    var drawX = x + hPaddingPx

    if (hasFavicon) {
      val bitmap = faviconBitmap
      if (bitmap != null) {
        val faviconY = chipY + (chipHeightPx - faviconSizePx) / 2f
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
      drawX += faviconSizePx + faviconGapPx
    }

    val textMetrics = textPaint.fontMetrics
    val textHeight = textMetrics.descent - textMetrics.ascent
    val textY = chipY + (chipHeightPx - textHeight) / 2f - textMetrics.ascent
    canvas.drawText(label, drawX, textY, textPaint)
  }

  companion object {
    // Baseline ratios: at a 17sp surrounding font, chip is 18dp tall with a
    // 10sp label. All other dimensions are fractions of chipHeight.
    private const val BASE_SURROUNDING_FONT_SP = 17f
    private const val BASE_CHIP_HEIGHT_DP = 18f
    private const val BASE_CHIP_FONT_SIZE_SP = 11f
    private const val BASE_HORIZONTAL_PADDING_DP = 7f
    private const val BASE_FAVICON_SIZE_DP = 13f
    private const val BASE_FAVICON_GAP_DP = 3.5f
    private const val BASE_RIGHT_MARGIN_DP = 3f

    private const val DEFAULT_BACKGROUND_COLOR = 0xFFFCEDE8.toInt() // #FCEDE8
    private const val DEFAULT_TEXT_COLOR = 0xFF343231.toInt() // #343231
  }
}
