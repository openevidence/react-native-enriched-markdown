package com.swmansion.enriched.markdown.styles

import com.facebook.react.bridge.ReadableMap

data class CitationStyle(
  val backgroundColor: Int,
  val color: Int,
  val fontSize: Float,
  val borderRadius: Float,
) {
  companion object {
    fun fromReadableMap(
      map: ReadableMap,
      parser: StyleParser,
    ): CitationStyle {
      val backgroundColor = parser.parseColor(map, "backgroundColor")
      val color = parser.parseColor(map, "color")
      val fontSize = parser.parseOptionalDouble(map, "fontSize").toFloat()
      val borderRadius = parser.parseOptionalDouble(map, "borderRadius", 4.0).toFloat()
      return CitationStyle(backgroundColor, color, fontSize, borderRadius)
    }
  }
}
