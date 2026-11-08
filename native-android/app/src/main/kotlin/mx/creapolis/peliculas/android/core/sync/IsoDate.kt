package mx.creapolis.peliculas.android.core.sync

import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

/**
 * RFC 3339 con y sin fracciones de segundo (Go envía nanosegundos).
 * Port de `ISO8601` en iOS.
 */
object IsoDate {
  fun parse(s: String): Instant? = try {
    Instant.parse(s)
  } catch (_: Exception) {
    try {
      OffsetDateTime.parse(s).toInstant()
    } catch (_: Exception) {
      null
    }
  }

  fun format(instant: Instant): String =
    DateTimeFormatter.ISO_INSTANT.format(instant)
}
