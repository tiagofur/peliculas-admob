package mx.creapolis.peliculas.android.features.widget

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import mx.creapolis.peliculas.android.MainActivity
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.core.network.TmdbClient
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * Widget de pantalla de inicio con Glance (port de `TrendingWidget` en iOS).
 * - Pequeño (2×2): el póster de la película nº 1 de hoy con su título encima.
 * - Mediano (4×2 o más ancho): los 3 primeros pósters, numerados.
 * - Cada póster abre su ficha mediante App Link.
 * - Sin conexión: estado "Sin conexión" honesto (nunca datos falsos).
 */
class TrendingWidget : GlanceAppWidget() {

  override val sizeMode: SizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM))

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    val entries = withContext(Dispatchers.IO) { load() }

    provideContent {
      GlanceTheme {
        if (LocalSize.current.width >= MEDIUM.width) MediumContent(entries) else SmallContent(entries.firstOrNull())
      }
    }
  }

  /** Un título con su póster ya descargado (`null` si no tiene o falló la descarga). */
  private class Entry(val item: TrendItem, val poster: Bitmap?)

  private suspend fun load(): List<Entry> = coroutineScope {
    val items = runCatching {
      TrendItems.from(TmdbClient.pagedList(MediaListSource.Trending(MediaKind.MOVIE, "day"), 1).results)
    }.getOrDefault(emptyList())
    items.mapIndexed { i, item ->
      // El primero va a sangre en el tamaño pequeño: necesita más resolución.
      async { Entry(item, item.posterUrl(if (i == 0) "w342" else "w185")?.let(::download)) }
    }.awaitAll()
  }

  private fun download(url: String): Bitmap? = runCatching {
    http.newCall(Request.Builder().url(url).build()).execute().use { res ->
      if (!res.isSuccessful) return@use null
      res.body?.byteStream()?.let(BitmapFactory::decodeStream)
    }
  }.getOrNull()

  @Composable
  private fun SmallContent(entry: Entry?) {
    val context = LocalContext.current
    if (entry == null) {
      Frame(open(context, TrendItems.FALLBACK_LINK), padded = true) { Offline(context, compact = true) }
      return
    }
    Frame(open(context, entry.item.link), padded = entry.poster == null) {
      if (entry.poster != null) {
        Image(
          provider = ImageProvider(entry.poster),
          contentDescription = entry.item.title,
          contentScale = ContentScale.Crop,
          modifier = GlanceModifier.fillMaxSize(),
        )
        // Degradado inferior para que el título se lea sobre cualquier póster.
        Column(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.Vertical.Bottom) {
          Column(
            modifier = GlanceModifier
              .fillMaxWidth()
              .background(ImageProvider(R.drawable.widget_scrim))
              .padding(start = 12.dp, end = 12.dp, top = 28.dp, bottom = 10.dp),
          ) {
            Header(context.getString(R.string.widget_trending_today), size = 11)
            Spacer(GlanceModifier.height(2.dp))
            Title(entry.item.title, size = 14, maxLines = 2)
          }
        }
      } else {
        Column(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.Vertical.CenterVertically) {
          Header(context.getString(R.string.widget_trending_today), size = 12)
          Spacer(GlanceModifier.height(6.dp))
          Title(entry.item.title, size = 15, maxLines = 2)
          if (entry.item.meta.isNotEmpty()) {
            Spacer(GlanceModifier.height(4.dp))
            Text(entry.item.meta, style = TextStyle(color = ColorProvider(Muted), fontSize = 11.sp))
          }
        }
      }
    }
  }

  @Composable
  private fun MediumContent(entries: List<Entry>) {
    val context = LocalContext.current
    Frame(open(context, TrendItems.FALLBACK_LINK), padded = true) {
      Column(modifier = GlanceModifier.fillMaxSize()) {
        Header(context.getString(R.string.widget_trending_today_plural), size = 12)
        Spacer(GlanceModifier.height(8.dp))
        if (entries.isEmpty()) {
          Offline(context, compact = false)
        } else {
          Row(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
            entries.forEachIndexed { i, entry ->
              if (i > 0) Spacer(GlanceModifier.width(10.dp))
              Column(
                modifier = GlanceModifier
                  .defaultWeight()
                  .fillMaxHeight()
                  .clickable(open(context, entry.item.link)),
              ) {
                val poster = GlanceModifier.fillMaxWidth().defaultWeight().cornerRadius(8.dp)
                if (entry.poster != null) {
                  Image(
                    provider = ImageProvider(entry.poster),
                    contentDescription = entry.item.title,
                    contentScale = ContentScale.Crop,
                    modifier = poster,
                  )
                } else {
                  Box(modifier = poster.background(ImageProvider(R.drawable.widget_poster_placeholder))) {}
                }
                Spacer(GlanceModifier.height(4.dp))
                Title("${i + 1}. ${entry.item.title}", size = 11, maxLines = 1)
              }
            }
          }
        }
      }
    }
  }

  /** Fondo, esquinas y pulsación comunes a todos los tamaños. */
  @Composable
  private fun Frame(onClick: Action, padded: Boolean, content: @Composable () -> Unit) {
    Box(
      modifier = GlanceModifier
        .fillMaxSize()
        .background(ColorProvider(Background))
        .cornerRadius(20.dp)
        .clickable(onClick)
        .padding(if (padded) 12.dp else 0.dp),
    ) { content() }
  }

  @Composable
  private fun Header(text: String, size: Int) {
    Text(
      text = "🔥 $text",
      style = TextStyle(color = ColorProvider(Accent), fontSize = size.sp, fontWeight = FontWeight.Bold),
      maxLines = 1,
    )
  }

  @Composable
  private fun Title(text: String, size: Int, maxLines: Int) {
    Text(
      text = text,
      style = TextStyle(color = ColorProvider(Color.White), fontSize = size.sp, fontWeight = FontWeight.Bold),
      maxLines = maxLines,
    )
  }

  /** Sin red o sin respuesta del servidor: no fingir datos. */
  @Composable
  private fun Offline(context: Context, compact: Boolean) {
    Column(
      modifier = GlanceModifier.fillMaxSize(),
      horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
      verticalAlignment = Alignment.Vertical.CenterVertically,
    ) {
      Title(context.getString(R.string.offline_title), size = 13, maxLines = 1)
      Spacer(GlanceModifier.height(4.dp))
      Text(
        text = context.getString(R.string.widget_tap_to_open),
        style = TextStyle(color = ColorProvider(Muted), fontSize = 11.sp),
        maxLines = if (compact) 2 else 1,
      )
    }
  }

  private fun open(context: Context, link: String): Action =
    actionStartActivity(
      Intent(Intent.ACTION_VIEW, Uri.parse(link)).apply {
        setClass(context, MainActivity::class.java)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
      },
    )

  private companion object {
    val SMALL = DpSize(140.dp, 110.dp)
    val MEDIUM = DpSize(250.dp, 110.dp)

    val Background = Color(0xFF1B1210)
    val Accent = Color(0xFFFF9800)
    val Muted = Color.White.copy(alpha = 0.7f)

    /** Tiempos cortos: el sistema da pocos segundos a la actualización de un widget. */
    val http: OkHttpClient by lazy {
      OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .callTimeout(10, TimeUnit.SECONDS)
        .build()
    }
  }
}

/** Receptor de actualizaciones del widget para el launcher de Android. */
class TrendingWidgetReceiver : GlanceAppWidgetReceiver() {
  override val glanceAppWidget: GlanceAppWidget = TrendingWidget()
}
