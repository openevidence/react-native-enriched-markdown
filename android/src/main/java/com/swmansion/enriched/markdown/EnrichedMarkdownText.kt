package com.swmansion.enriched.markdown

import android.content.Context
import android.content.res.Configuration
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.Layout
import android.text.Selection
import android.text.Spannable
import android.util.AttributeSet
import android.util.Log
import android.view.MotionEvent
import android.view.ViewConfiguration
import androidx.appcompat.widget.AppCompatTextView
import com.facebook.react.bridge.ReadableMap
import com.swmansion.enriched.markdown.accessibility.MarkdownAccessibilityHelper
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.spoiler.SpoilerCapable
import com.swmansion.enriched.markdown.spoiler.SpoilerMode
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayDrawer
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.TailFadeInAnimator
import com.swmansion.enriched.markdown.utils.text.interaction.CheckboxTouchHelper
import com.swmansion.enriched.markdown.utils.text.view.LinkLongPressMovementMethod
import com.swmansion.enriched.markdown.utils.text.view.applySelectableState
import com.swmansion.enriched.markdown.utils.text.view.cancelJSTouchForCheckboxTap
import com.swmansion.enriched.markdown.utils.text.view.cancelJSTouchForLinkTap
import com.swmansion.enriched.markdown.utils.text.view.charOffsetAt
import com.swmansion.enriched.markdown.utils.text.view.createSelectionActionModeCallback
import com.swmansion.enriched.markdown.utils.text.view.emitCitationPressEvent
import com.swmansion.enriched.markdown.utils.text.view.emitLinkLongPressEvent
import com.swmansion.enriched.markdown.utils.text.view.emitLinkPressEvent
import com.swmansion.enriched.markdown.utils.text.view.isInteractiveOffset
import com.swmansion.enriched.markdown.utils.text.view.setupAsMarkdownTextView
import java.util.concurrent.Executors

/**
 * EnrichedMarkdownText that handles Markdown parsing and rendering on a background thread.
 * View starts invisible and becomes visible after render completes to avoid layout shift.
 */
class EnrichedMarkdownText
  @JvmOverloads
  constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
  ) : AppCompatTextView(context, attrs, defStyleAttr),
    SpoilerCapable {
    private val parser = Parser.shared
    private val renderer = Renderer()
    private var onLinkPressCallback: ((String) -> Unit)? = null
    private var onLinkLongPressCallback: ((String) -> Unit)? = null
    private var onCitationPressCallback: ((String) -> Unit)? = null
    private val checkboxTouchHelper = CheckboxTouchHelper(this)

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var currentRenderId = 0L

    val layoutManager = EnrichedMarkdownTextLayoutManager(this)

    // Accessibility helper for TalkBack support
    private val accessibilityHelper = MarkdownAccessibilityHelper(this)

    private var contextMenuItemTexts: List<String> = emptyList()
    var onContextMenuItemPressCallback: ((itemText: String, selectedText: String, selectionStart: Int, selectionEnd: Int) -> Unit)? = null

    var markdownStyle: StyleConfig? = null
      private set

    var currentMarkdown: String = ""
      private set

    var md4cFlags: Md4cFlags = Md4cFlags.DEFAULT
      private set

    private var lastKnownFontScale: Float = context.resources.configuration.fontScale
    private var markdownStyleMap: ReadableMap? = null

    private var allowFontScaling: Boolean = true
    private var maxFontSizeMultiplier: Float = 0f
    private var allowTrailingMargin: Boolean = false

    private var streamingAnimation: Boolean = false
    private var previousTextLength: Int = 0
    private var fadeAnimator: TailFadeInAnimator? = null

    // Swipe detection to prevent Editor from starting text selection during scrolling
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var isScrollGesture = false
    override var spoilerOverlayDrawer: SpoilerOverlayDrawer? = null
      private set
    var spoilerMode: SpoilerMode = SpoilerMode.PARTICLES

    init {
      setupAsMarkdownTextView(accessibilityHelper)
      customSelectionActionModeCallback =
        createSelectionActionModeCallback(
          this,
          getCustomItemTexts = { contextMenuItemTexts },
          onCustomItemPress = { itemText, selectedText, start, end ->
            onContextMenuItemPressCallback?.invoke(itemText, selectedText, start, end)
          },
        )
    }

    fun setMarkdownContent(markdown: String) {
      if (currentMarkdown == markdown) return
      currentMarkdown = markdown
      scheduleRender()
    }

    fun setMarkdownStyle(style: ReadableMap?) {
      markdownStyleMap = style
      // Register font scaling settings when style is set (view should have ID by now)
      updateMeasurementStoreFontScaling()
      val newStyle = style?.let { StyleConfig(it, context, allowFontScaling, maxFontSizeMultiplier) }
      if (markdownStyle == newStyle) return
      markdownStyle = newStyle
      updateJustificationMode(newStyle)
      scheduleRender()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
      super.onConfigurationChanged(newConfig)

      // Reset cached overlay color so it's re-resolved for the new theme
      fadeOverlayColor = 0

      if (!allowFontScaling) {
        return
      }

      val newFontScale = newConfig.fontScale
      if (newFontScale != lastKnownFontScale) {
        lastKnownFontScale = newFontScale
        recreateStyleConfig()
        scheduleRenderIfNeeded()
      }
    }

    fun setMd4cFlags(flags: Md4cFlags) {
      if (md4cFlags == flags) return
      md4cFlags = flags
      scheduleRenderIfNeeded()
    }

    fun setAllowFontScaling(allow: Boolean) {
      if (allowFontScaling == allow) return
      allowFontScaling = allow
      updateMeasurementStoreFontScaling()
      recreateStyleConfig()
      scheduleRenderIfNeeded()
    }

    fun setMaxFontSizeMultiplier(multiplier: Float) {
      if (maxFontSizeMultiplier == multiplier) return
      maxFontSizeMultiplier = multiplier
      updateMeasurementStoreFontScaling()
      recreateStyleConfig()
      scheduleRenderIfNeeded()
    }

    fun setAllowTrailingMargin(allow: Boolean) {
      if (allowTrailingMargin == allow) return
      allowTrailingMargin = allow
      scheduleRenderIfNeeded()
    }

    fun setStreamingAnimation(enabled: Boolean) {
      if (streamingAnimation == enabled) return
      streamingAnimation = enabled
      if (!enabled) {
        fadeAnimator?.cancelAll()
        fadeAnimator = null
      }
    }

    private fun updateMeasurementStoreFontScaling() {
      MeasurementStore.updateFontScalingSettings(id, allowFontScaling, maxFontSizeMultiplier)
    }

    private fun scheduleRenderIfNeeded() {
      if (currentMarkdown.isNotEmpty()) {
        scheduleRender()
      }
    }

    private fun recreateStyleConfig() {
      markdownStyleMap?.let { styleMap ->
        markdownStyle = StyleConfig(styleMap, context, allowFontScaling, maxFontSizeMultiplier)
        updateJustificationMode(markdownStyle)
      }
    }

    private fun updateJustificationMode(style: StyleConfig?) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        justificationMode =
          if (style?.needsJustify == true) {
            Layout.JUSTIFICATION_MODE_INTER_WORD
          } else {
            Layout.JUSTIFICATION_MODE_NONE
          }
      }
    }

    private fun scheduleRender() {
      val style = markdownStyle ?: return
      val markdown = currentMarkdown
      if (markdown.isEmpty()) return

      // The executor is shut down in release() when the view instance is
      // dropped. If a style/markdown update lands after that (e.g. during a
      // race on theme change), skip instead of crashing with
      // RejectedExecutionException.
      if (executor.isShutdown) return

      val renderId = ++currentRenderId

      executor.execute {
        try {
          val ast =
            parser.parseMarkdown(markdown, md4cFlags) ?: run {
              mainHandler.post { if (renderId == currentRenderId) text = "" }
              return@execute
            }

          renderer.configure(style, context)
          renderer.setOnCitationPress(onCitationPressCallback)
          val styledText = renderer.renderDocument(ast, onLinkPressCallback, onLinkLongPressCallback)

          mainHandler.post {
            if (renderId == currentRenderId) {
              applyRenderedText(styledText)
            }
          }
        } catch (e: Exception) {
          Log.e(TAG, "Render failed: ${e.message}", e)
          mainHandler.post { if (renderId == currentRenderId) text = "" }
        }
      }
    }

    private fun applyRenderedText(styledText: CharSequence) {
      val tailStart = previousTextLength

      // Use BufferType.EDITABLE so the text buffer implements Spannable
      // (required for the movement method — TextView checks mText instanceof
      // Spannable before calling mMovement.onTouchEvent).
      setText(styledText, android.widget.TextView.BufferType.EDITABLE)

      if (movementMethod !is LinkLongPressMovementMethod) {
        movementMethod = LinkLongPressMovementMethod.createInstance()
      }

      renderer.getCollectedImageSpans().forEach { span ->
        span.registerTextView(this)
      }

      (styledText as? android.text.Spanned)?.let { spanned ->
        spanned
          .getSpans(0, spanned.length, com.swmansion.enriched.markdown.spans.CitationChipSpan::class.java)
          .forEach { it.registerTextView(this) }
      }

      // Register MathInlineSpan views so they can compute scale-to-fit using view width.
      // Uses reflection because MathInlineSpan is in the optional math source set.
      registerMathSpans(styledText)

      spoilerOverlayDrawer = SpoilerOverlayDrawer.setupIfNeeded(this, styledText, spoilerOverlayDrawer, spoilerMode)

      layoutManager.invalidateLayout()
      accessibilityHelper.invalidateAccessibilityItems()

      // Always track text length so the tail start is correct when animation
      // is enabled mid-stream (props arrive in arbitrary order from React).
      previousTextLength = styledText.length

      // Start fade-in animation for the new tail AFTER setText so the layout
      // is available for coordinate calculations in drawOverlay.
      if (streamingAnimation && tailStart < styledText.length) {
        if (fadeAnimator == null) {
          fadeAnimator = TailFadeInAnimator(this)
        }
        fadeAnimator?.animate(tailStart, styledText.length)
      }
    }

    fun setContextMenuItems(items: List<String>) {
      contextMenuItemTexts = items
    }

    fun setIsSelectable(selectable: Boolean) {
      applySelectableState(selectable)
    }

    fun emitOnLinkPress(url: String) {
      emitLinkPressEvent(url)
    }

    fun emitOnLinkLongPress(url: String) {
      emitLinkLongPressEvent(url)
    }

    fun emitOnCitationPress(numbers: String) {
      emitCitationPressEvent(numbers)
    }

    fun setOnLinkPressCallback(callback: (String) -> Unit) {
      onLinkPressCallback = callback
    }

    fun setOnLinkLongPressCallback(callback: (String) -> Unit) {
      onLinkLongPressCallback = callback
    }

    fun setOnCitationPressCallback(callback: (String) -> Unit) {
      onCitationPressCallback = callback
    }

    fun setOnTaskListItemPressCallback(callback: ((taskIndex: Int, checked: Boolean, itemText: String) -> Unit)?) {
      checkboxTouchHelper.onCheckboxTap = callback
    }

    fun clearActiveImageSpans() {
      renderer.clearActiveImageSpans()
    }

    override fun onDetachedFromWindow() {
      fadeAnimator?.cancelAll()
      fadeAnimator = null
      stopSpoilerAnimations()
      super.onDetachedFromWindow()
    }

    /**
     * Terminal cleanup — called from ViewManager#onDropViewInstance. Safe to
     * call multiple times. Must NOT be called from onDetachedFromWindow,
     * which fires on every reparent / theme change; shutting the executor
     * down there causes RejectedExecutionException when the view is
     * re-attached and a follow-up setMarkdownStyle/setMarkdown arrives.
     */
    fun release() {
      fadeAnimator?.cancelAll()
      fadeAnimator = null
      stopSpoilerAnimations()
      if (!executor.isShutdown) {
        executor.shutdownNow()
      }
    }

    override fun onDraw(canvas: Canvas) {
      super.onDraw(canvas)
      spoilerOverlayDrawer?.draw(canvas)
      // Draw the fade-in overlay on top of the text. The overlay covers new
      // tail text with an opaque background-colored rectangle that fades out,
      // creating a reveal effect. This bypasses the span system entirely.
      val animator = fadeAnimator
      if (animator != null && animator.hasActiveAnimations) {
        val l = layout
        if (l != null) {
          animator.drawOverlay(canvas, l, resolveFadeOverlayColor(), totalPaddingLeft, totalPaddingTop)
        }
      }
    }

    /**
     * The background color used for the fade-in overlay. Resolved lazily
     * by walking up the view hierarchy to find the first opaque background.
     */
    private var fadeOverlayColor: Int = 0

    private fun resolveFadeOverlayColor(): Int {
      if (fadeOverlayColor != 0) return fadeOverlayColor
      fadeOverlayColor =
        com.swmansion.enriched.markdown.spoiler.SpoilerDrawContext
          .resolveBackgroundColor(this)
      return fadeOverlayColor
    }

    private fun stopSpoilerAnimations() {
      spoilerOverlayDrawer?.stop()
      spoilerOverlayDrawer = null
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
      // Only claim the gesture when ACTION_DOWN lands on an interactive span
      // (link or citation). This prevents the parent from intercepting before
      // we receive ACTION_UP, while still allowing scroll/swipe gestures when
      // tapping on plain text.
      if (event.action == MotionEvent.ACTION_DOWN) {
        val offset = charOffsetAt(event.x, event.y)
        if (isInteractiveOffset(offset)) {
          parent?.requestDisallowInterceptTouchEvent(true)
        }
      }
      return super.dispatchTouchEvent(event)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
      when (event.action) {
        MotionEvent.ACTION_DOWN -> {
          touchStartX = event.rawX
          touchStartY = event.rawY
          isScrollGesture = false
        }

        MotionEvent.ACTION_MOVE -> {
          val mm = movementMethod
          val linkActive = mm is LinkLongPressMovementMethod && mm.isLinkTouchActive
          if (!isScrollGesture && !hasSelection() && !linkActive) {
            val slop = ViewConfiguration.get(context).scaledTouchSlop
            if (kotlin.math.abs(event.rawY - touchStartY) > slop ||
              kotlin.math.abs(event.rawX - touchStartX) > slop
            ) {
              isScrollGesture = true
              // Release the claim so the parent can scroll
              parent?.requestDisallowInterceptTouchEvent(false)
            }
          }
          if (isScrollGesture) {
            parent?.requestDisallowInterceptTouchEvent(false)
            return true
          }
        }

        MotionEvent.ACTION_UP -> {
          if (isScrollGesture) {
            isScrollGesture = false
            (text as? Spannable)?.let { Selection.removeSelection(it) }
            return true
          }
        }

        MotionEvent.ACTION_CANCEL -> {
          isScrollGesture = false
          (text as? Spannable)?.let { Selection.removeSelection(it) }
        }
      }

      if (checkboxTouchHelper.onTouchEvent(event)) {
        if (event.action == MotionEvent.ACTION_DOWN) {
          cancelJSTouchForCheckboxTap(event)
        }
        return true
      }
      val result = super.onTouchEvent(event)
      if (event.action == MotionEvent.ACTION_DOWN) {
        cancelJSTouchForLinkTap(event)
      }
      return result
    }

    private fun registerMathSpans(styledText: CharSequence) {
      val spanned = styledText as? android.text.Spanned ?: return
      val cls = mathSpanClass ?: return
      val method = mathRegisterMethod ?: return
      try {
        val spans = spanned.getSpans(0, spanned.length, cls)
        for (span in spans) {
          method.invoke(span, this)
        }
      } catch (_: Exception) {
        // math module not available or reflection failed
      }
    }

    companion object {
      private const val TAG = "ENRM_Text"

      private val mathSpanClass: Class<*>? by lazy {
        runCatching { Class.forName("com.swmansion.enriched.markdown.spans.MathInlineSpan") }.getOrNull()
      }

      private val mathRegisterMethod: java.lang.reflect.Method? by lazy {
        mathSpanClass?.let { cls ->
          runCatching { cls.getMethod("registerTextView", android.widget.TextView::class.java) }.getOrNull()
        }
      }
    }
  }
