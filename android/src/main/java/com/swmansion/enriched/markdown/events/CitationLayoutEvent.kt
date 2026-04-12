package com.swmansion.enriched.markdown.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

/**
 * Carries the layout frames of every citation placeholder span in the rendered text.
 * JS uses these frames to overlay React Native CitationElement views at the correct positions.
 */
class CitationLayoutEvent(
  surfaceId: Int,
  viewId: Int,
  private val citations: List<CitationFrame>,
) : Event<CitationLayoutEvent>(surfaceId, viewId) {
  data class CitationFrame(
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float,
    val numbers: String,
  )

  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap =
    Arguments.createMap().apply {
      val arr = Arguments.createArray()
      for (frame in citations) {
        val map = Arguments.createMap()
        map.putDouble("x", frame.x.toDouble())
        map.putDouble("y", frame.y.toDouble())
        map.putDouble("width", frame.width.toDouble())
        map.putDouble("height", frame.height.toDouble())
        map.putString("numbers", frame.numbers)
        arr.pushMap(map)
      }
      putArray("citations", arr)
    }

  companion object {
    const val EVENT_NAME: String = "onCitationLayout"
  }
}
