package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Canvas
import android.text.Layout
import android.text.Selection
import android.text.Spannable
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.ViewConfiguration
import androidx.appcompat.widget.AppCompatTextView
import com.swmansion.enriched.markdown.accessibility.MarkdownAccessibilityHelper
import com.swmansion.enriched.markdown.spoiler.SpoilerCapable
import com.swmansion.enriched.markdown.spoiler.SpoilerMode
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayDrawer
import com.swmansion.enriched.markdown.utils.text.interaction.CheckboxTouchHelper
import com.swmansion.enriched.markdown.utils.text.view.LinkLongPressMovementMethod
import com.swmansion.enriched.markdown.utils.text.view.applySelectableState
import com.swmansion.enriched.markdown.utils.text.view.cancelJSTouchForCheckboxTap
import com.swmansion.enriched.markdown.utils.text.view.cancelJSTouchForLinkTap
import com.swmansion.enriched.markdown.utils.text.view.charOffsetAt
import com.swmansion.enriched.markdown.utils.text.view.createSelectionActionModeCallback
import com.swmansion.enriched.markdown.utils.text.view.isInteractiveOffset
import com.swmansion.enriched.markdown.utils.text.view.setupAsMarkdownTextView
import com.swmansion.enriched.markdown.views.BlockSegmentView

class EnrichedMarkdownInternalText
  @JvmOverloads
  constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
  ) : AppCompatTextView(context, attrs, defStyleAttr),
    BlockSegmentView,
    SpoilerCapable {
    private val accessibilityHelper = MarkdownAccessibilityHelper(this)

    var lastElementMarginBottom: Float = 0f

    private val checkboxTouchHelper = CheckboxTouchHelper(this)

    // Swipe detection to prevent Editor from starting text selection during scrolling
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var isScrollGesture = false

    var onTaskListItemPressCallback: ((taskIndex: Int, checked: Boolean, itemText: String) -> Unit)?
      get() = checkboxTouchHelper.onCheckboxTap
      set(value) {
        checkboxTouchHelper.onCheckboxTap = value
      }

    override val segmentMarginBottom: Int get() = lastElementMarginBottom.toInt()

    override var spoilerOverlayDrawer: SpoilerOverlayDrawer? = null
      private set
    var spoilerMode: SpoilerMode = SpoilerMode.PARTICLES
    private var contextMenuItemTexts: List<String> = emptyList()
    private var onContextMenuItemPress: ((itemText: String, selectedText: String, selectionStart: Int, selectionEnd: Int) -> Unit)? = null

    init {
      setupAsMarkdownTextView(accessibilityHelper)
      customSelectionActionModeCallback =
        createSelectionActionModeCallback(
          this,
          getCustomItemTexts = { contextMenuItemTexts },
          onCustomItemPress = { itemText, selectedText, start, end ->
            onContextMenuItemPress?.invoke(itemText, selectedText, start, end)
          },
        )
    }

    fun applyStyledText(styledText: CharSequence) {
      // Use BufferType.EDITABLE so the text buffer uses DynamicLayout, which
      // watches for span changes. Editable extends Spannable, so the movement
      // method also works (TextView checks mText instanceof Spannable).
      setText(styledText, android.widget.TextView.BufferType.EDITABLE)

      if (movementMethod !is LinkLongPressMovementMethod) {
        movementMethod = LinkLongPressMovementMethod.createInstance()
      }

      spoilerOverlayDrawer = SpoilerOverlayDrawer.setupIfNeeded(this, styledText, spoilerOverlayDrawer, spoilerMode)
      accessibilityHelper.invalidateAccessibilityItems()
    }

    override fun onDraw(canvas: Canvas) {
      super.onDraw(canvas)
      spoilerOverlayDrawer?.draw(canvas)
    }

    override fun onDetachedFromWindow() {
      spoilerOverlayDrawer?.stop()
      spoilerOverlayDrawer = null
      super.onDetachedFromWindow()
    }

    fun setIsSelectable(selectable: Boolean) {
      applySelectableState(selectable)
    }

    fun setContextMenuItems(
      items: List<String>,
      onPress: (itemText: String, selectedText: String, selectionStart: Int, selectionEnd: Int) -> Unit,
    ) {
      contextMenuItemTexts = items
      onContextMenuItemPress = onPress
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
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

    fun setJustificationMode(needsJustify: Boolean) {
      if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
        justificationMode =
          if (needsJustify) {
            Layout.JUSTIFICATION_MODE_INTER_WORD
          } else {
            Layout.JUSTIFICATION_MODE_NONE
          }
      }
    }
  }
