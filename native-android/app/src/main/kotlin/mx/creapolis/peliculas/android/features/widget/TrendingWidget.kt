package mx.creapolis.peliculas.android.features.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import mx.creapolis.peliculas.android.MainActivity
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.core.network.TmdbClient
import mx.creapolis.peliculas.android.core.network.TmdbMovie

/**
 * Widget de pantalla de inicio con Glance (port de `TrendingWidget` en iOS).
 * - Muestra la película en tendencia hoy.
 * - Al pulsar, abre la ficha correspondiente mediante App Link.
 * - Si no hay conexión, muestra estado "Sin conexión" honesto (nunca datos falsos).
 */
class TrendingWidget : GlanceAppWidget() {

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    val trending = withContext(Dispatchers.IO) {
      runCatching {
        TmdbClient.pagedList(MediaListSource.Trending(MediaKind.MOVIE, "day"), 1).results.firstOrNull()
      }.getOrNull()
    }

    provideContent {
      GlanceTheme {
        WidgetContent(context = context, movie = trending)
      }
    }
  }

  @Composable
  private fun WidgetContent(context: Context, movie: TmdbMovie?) {
    val intent = if (movie != null && movie.id > 0) {
      Intent(Intent.ACTION_VIEW, Uri.parse("https://peliculas.creapolis.dev/movie/${movie.id}")).apply {
        setClass(context, MainActivity::class.java)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
      }
    } else {
      Intent(Intent.ACTION_VIEW, Uri.parse("https://peliculas.creapolis.dev/trending")).apply {
        setClass(context, MainActivity::class.java)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
      }
    }

    Box(
      modifier = GlanceModifier
        .fillMaxSize()
        .background(ColorProvider(Color(0xFF1B1210)))
        .clickable(actionStartActivity(intent))
        .padding(14.dp),
    ) {
      if (movie != null) {
        Column(
          modifier = GlanceModifier.fillMaxSize(),
          verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
          Text(
            text = "🔥 " + context.getString(R.string.widget_trending_today),
            style = TextStyle(
              color = ColorProvider(Color(0xFFFF9800)),
              fontSize = 12.sp,
              fontWeight = FontWeight.Bold,
            ),
          )
          Spacer(GlanceModifier.height(6.dp))
          Text(
            text = movie.title ?: movie.name ?: "",
            style = TextStyle(
              color = ColorProvider(Color.White),
              fontSize = 15.sp,
              fontWeight = FontWeight.Bold,
            ),
            maxLines = 2,
          )
          Spacer(GlanceModifier.height(4.dp))
          val rating = movie.voteAverage ?: 0.0
          val year = (movie.releaseDate ?: movie.firstAirDate ?: "").take(4)
          val meta = listOfNotNull(year.takeIf { it.isNotEmpty() }, if (rating > 0) "★ %.1f".format(rating) else null)
          if (meta.isNotEmpty()) {
            Text(
              text = meta.joinToString(" · "),
              style = TextStyle(
                color = ColorProvider(Color.White.copy(alpha = 0.7f)),
                fontSize = 11.sp,
              ),
            )
          }
        }
      } else {
        Column(
          modifier = GlanceModifier.fillMaxSize(),
          horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
          verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
          Text(
            text = context.getString(R.string.offline_title),
            style = TextStyle(
              color = ColorProvider(Color.White),
              fontSize = 13.sp,
              fontWeight = FontWeight.Bold,
            ),
          )
          Spacer(GlanceModifier.height(4.dp))
          Text(
            text = context.getString(R.string.widget_tap_to_open),
            style = TextStyle(
              color = ColorProvider(Color.White.copy(alpha = 0.6f)),
              fontSize = 11.sp,
            ),
          )
        }
      }
    }
  }
}

/** Receptor de actualizaciones del widget para el launcher de Android. */
class TrendingWidgetReceiver : GlanceAppWidgetReceiver() {
  override val glanceAppWidget: GlanceAppWidget = TrendingWidget()
}
