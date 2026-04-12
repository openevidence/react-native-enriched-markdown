package com.swmansion.enriched.markdown.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event
import org.json.JSONArray
import org.json.JSONObject

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
      val jsonArray = JSONArray()
      for (frame in citations) {
        val obj = JSONObject()
        obj.put("x", frame.x.toDouble())
        obj.put("y", frame.y.toDouble())
        obj.put("width", frame.width.toDouble())
        obj.put("height", frame.height.toDouble())
        obj.put("numbers", frame.numbers)
        jsonArray.put(obj)
      }
      putString("citationsJson", jsonArray.toString())
    }

  companion object {
    const val EVENT_NAME: String = "onCitationLayout"
  }
}
