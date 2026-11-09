package mx.creapolis.peliculas.android.features.detail

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.StarHalf
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.TmdbImage
import mx.creapolis.peliculas.android.ui.components.BackdropImage
import mx.creapolis.peliculas.android.ui.components.BottomScrim
import mx.creapolis.peliculas.android.ui.components.PosterCard

/**
 * Detalle (port de `DetailView` en iOS): header con backdrop, acciones de
 * biblioteca, nota+reseña, dirección/creador, temporadas y episodios,
 * tráiler embebido, dónde verla, reparto y similares.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailScreen(
  item: MediaItem,
  library: LibraryStore,
  onOpenPerson: (id: Int, name: String) -> Unit,
  onOpenItem: (MediaItem) -> Unit,
  onBack: (() -> Unit)? = null,
  proStore: mx.creapolis.peliculas.android.features.pro.ProStore? = null,
  vm: DetailViewModel = viewModel(key = item.key.description, factory = DetailViewModelFactory(item, library)),
) {
  val context = LocalContext.current
  val activeProStore = proStore ?: (context.applicationContext as? mx.creapolis.peliculas.android.PeliculasApp)?.container?.proStore
  val state by vm.state.collectAsState()
  val lib by library.state.collectAsState()
  var showTrailer by remember { mutableStateOf(false) }
  var editingReview by remember { mutableStateOf(false) }
  var reviewDraft by remember { mutableStateOf("") }

  if (state.detail == null) {
    if (state.failed) {
      Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
      ) {
        Text(
          stringResource(R.string.detail_error),
          style = MaterialTheme.typography.titleSmall,
          textAlign = TextAlign.Center,
        )
        Button(onClick = vm::reload, modifier = Modifier.padding(top = 12.dp)) {
          Text(stringResource(R.string.retry))
        }
      }
    } else {
      Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
      }
    }
    return
  }

  val backgroundColor = MaterialTheme.colorScheme.background
  val detailGradient = remember(backgroundColor) {
    Brush.verticalGradient(
      0.00f to Color.Black.copy(alpha = 0.45f),
      0.25f to Color.Transparent,
      0.45f to Color.Transparent,
      0.80f to backgroundColor.copy(alpha = 0.88f),
      1.00f to backgroundColor,
    )
  }

  LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 32.dp)) {
    // ---- Header a sangre con botón flotante ----
    item {
      Box(Modifier.fillMaxWidth().height(380.dp)) {
        BackdropImage(
          path = state.item.backdropPath.ifEmpty { state.item.posterPath },
          modifier = Modifier.fillMaxSize(),
        )
        Box(Modifier.fillMaxSize().background(detailGradient))
        if (onBack != null) {
          IconButton(
            onClick = onBack,
            modifier = Modifier
              .statusBarsPadding()
              .padding(start = 16.dp, top = 8.dp)
              .size(40.dp)
              .clip(CircleShape)
              .background(Color.Black.copy(alpha = 0.45f)),
          ) {
            Icon(
              Icons.AutoMirrored.Filled.ArrowBack,
              contentDescription = stringResource(R.string.back),
              tint = Color.White,
            )
          }
        }
        Column(
          Modifier
            .align(Alignment.BottomStart)
            .padding(horizontal = 20.dp, vertical = 16.dp),
          verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
          Box(
            modifier = Modifier
              .clip(RoundedCornerShape(12.dp))
              .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f))
              .padding(horizontal = 8.dp, vertical = 3.dp),
          ) {
            Text(
              if (item.kind == MediaKind.TV) stringResource(R.string.badge_show).uppercase() else stringResource(R.string.badge_movie).uppercase(),
              style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp),
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
          Text(
            state.item.title,
            style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Black),
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onBackground,
          )
          val meta = buildList {
            state.item.year.takeIf { it.isNotEmpty() }?.let { add(it) }
            state.detail?.runtime?.takeIf { it > 0 && item.kind == MediaKind.MOVIE }?.let {
              add(if (it >= 60) "${it / 60} h ${it % 60} min" else "$it min")
            }
            state.detail?.numberOfSeasons?.takeIf { it > 0 && item.kind == MediaKind.TV }?.let {
              add(if (it == 1) stringResource(R.string.one_season) else stringResource(R.string.n_seasons_fmt, it))
            }
            state.detail?.genres?.take(2)?.map { it.name }?.takeIf { it.isNotEmpty() }?.let { add(it.joinToString(", ")) }
          }
          if (meta.isNotEmpty()) {
            Text(
              meta.joinToString(" · "),
              style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
      }
    }

    // ---- Acciones estilo iOS (Píldora Watchlist + Botones circulares con icono) ----
    item {
      Row(
        Modifier
          .fillMaxWidth()
          .padding(horizontal = 20.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        val inWatchlist = lib.contains(item.key, LibraryStore.Kind.WATCHLIST)
        Button(
          onClick = { library.toggle(item, LibraryStore.Kind.WATCHLIST) },
          shape = RoundedCornerShape(24.dp),
          colors = ButtonDefaults.buttonColors(
            containerColor = if (inWatchlist) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.primary,
            contentColor = if (inWatchlist) MaterialTheme.colorScheme.primary else Color.White,
          ),
          modifier = Modifier.weight(1f),
          contentPadding = PaddingValues(horizontal = 16.dp, vertical = 10.dp),
        ) {
          Icon(
            if (inWatchlist) Icons.Filled.Check else Icons.Filled.Add,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
          )
          Spacer(Modifier.width(6.dp))
          Text(
            if (inWatchlist) stringResource(R.string.in_watchlist) else stringResource(R.string.add_watchlist),
            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
            maxLines = 1,
          )
        }

        val isFav = lib.contains(item.key, LibraryStore.Kind.FAVORITE)
        CircularAction(
          icon = if (isFav) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
          tint = if (isFav) Color(0xFFFF2D55) else MaterialTheme.colorScheme.onSurfaceVariant,
          label = stringResource(R.string.favorite),
          onClick = { library.toggle(item, LibraryStore.Kind.FAVORITE) },
        )

        val watched = lib.contains(item.key, LibraryStore.Kind.WATCHED)
        CircularAction(
          icon = if (watched) Icons.Filled.Visibility else Icons.Filled.VisibilityOff,
          tint = if (watched) Color(0xFF34C759) else MaterialTheme.colorScheme.onSurfaceVariant,
          label = stringResource(R.string.watched),
          onClick = { library.toggle(item, LibraryStore.Kind.WATCHED) },
        )

        if (state.trailerKey != null) {
          CircularAction(
            icon = Icons.Filled.PlayArrow,
            tint = MaterialTheme.colorScheme.primary,
            label = stringResource(R.string.trailer),
            onClick = { showTrailer = true },
          )
        }

        CircularAction(
          icon = Icons.Filled.Share,
          tint = MaterialTheme.colorScheme.onSurfaceVariant,
          label = stringResource(R.string.share),
          onClick = {
            val sendIntent = android.content.Intent().apply {
              action = android.content.Intent.ACTION_SEND
              putExtra(android.content.Intent.EXTRA_TEXT, item.shareText)
              type = "text/plain"
            }
            context.startActivity(android.content.Intent.createChooser(sendIntent, null))
          },
        )
      }
    }

    // ---- Nota + reseña en tarjeta redondeada ----
    item {
      Column(
        Modifier
          .fillMaxWidth()
          .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
      ) {
        Row(
          modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))
            .padding(horizontal = 16.dp, vertical = 10.dp),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Text(
            stringResource(R.string.your_rating),
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
          )
          RatingStars(
            score = lib.score(item.key),
            onRate = { library.rate(item, it) },
          )
        }
        val review = lib.review(item.key).orEmpty()
        if (editingReview) {
          OutlinedTextField(
            value = reviewDraft,
            onValueChange = { reviewDraft = it },
            placeholder = { Text(stringResource(R.string.review_prompt)) },
            modifier = Modifier.fillMaxWidth(),
            minLines = 3,
          )
          Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.align(Alignment.End)) {
            TextButton(onClick = { editingReview = false }) { Text(stringResource(R.string.cancel)) }
            TextButton(onClick = {
              library.setReview(item, reviewDraft)
              editingReview = false
            }) { Text(stringResource(R.string.save)) }
          }
        } else {
          if (review.isNotEmpty()) {
            Text(
              review,
              style = MaterialTheme.typography.bodyMedium,
              modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(12.dp),
            )
          }
          TextButton(onClick = {
            reviewDraft = review
            editingReview = true
          }) {
            Text(if (review.isEmpty()) stringResource(R.string.review_write) else stringResource(R.string.review_edit))
          }
        }
      }
    }

    // ---- Dirección / creador ----
    if (state.creditNames != null) {
      item {
        Row(
          Modifier.padding(horizontal = 20.dp),
          horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
          Text(
            state.creditLabel.orEmpty(),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
          )
          Text(state.creditNames.orEmpty(), style = MaterialTheme.typography.bodyMedium)
        }
      }
    }

    // ---- Sinopsis ----
    if (state.item.overview.isNotEmpty()) {
      item {
        Text(
          state.item.overview,
          style = MaterialTheme.typography.bodyMedium,
          modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
        )
      }
    }

    // ---- Temporadas y episodios (series) ----
    if (item.kind == MediaKind.TV && state.seasons.isNotEmpty()) {
      item {
        LazyRow(
          contentPadding = PaddingValues(horizontal = 20.dp),
          horizontalArrangement = Arrangement.spacedBy(8.dp),
          modifier = Modifier.padding(vertical = 8.dp),
        ) {
          items(state.seasons) { season ->
            val selected = season.seasonNumber == state.selectedSeason
            TextButton(onClick = { vm.selectSeason(season.seasonNumber) }) {
              Text(
                season.name ?: stringResource(R.string.season_n, season.seasonNumber),
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
              )
            }
          }
        }
      }

      val aired = state.episodes.filter { it.hasAired }.map { it.number }
      if (aired.isNotEmpty()) {
        item {
          Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
          ) {
            Text(
              stringResource(R.string.episodes),
              style = MaterialTheme.typography.titleMedium,
              modifier = Modifier.weight(1f),
            )
            val watched = lib.seasonWatchedCount(item.id, state.selectedSeason)
            Text(
              "$watched/${aired.size}",
              style = MaterialTheme.typography.labelLarge,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            TextButton(onClick = { library.toggleSeason(item.id, state.selectedSeason, aired) }) {
              Text(if (watched >= aired.size) stringResource(R.string.unmark_all) else stringResource(R.string.mark_all))
            }
          }
        }
        itemsIndexed(state.episodes) { _, ep ->
          EpisodeRow(
            ep = ep,
            watched = lib.isEpisodeWatched(item.id, state.selectedSeason, ep.number),
            onToggle = { library.toggleEpisode(item.id, state.selectedSeason, ep.number) },
          )
        }
      }
    }

    // ---- Dónde verla ----
    if (state.providers.isNotEmpty()) {
      item {
        Text(
          stringResource(R.string.where_to_watch),
          style = MaterialTheme.typography.titleMedium,
          modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
        )
      }
      item {
        LazyRow(
          contentPadding = PaddingValues(horizontal = 20.dp),
          horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
          items(state.providers) { provider ->
            ProviderBadge(provider, state.providerLink, item.title, context)
          }
        }
      }
    }

    // ---- Reparto ----
    if (state.cast.isNotEmpty()) {
      item {
        Text(
          stringResource(R.string.cast),
          style = MaterialTheme.typography.titleMedium,
          modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
        )
      }
      item {
        LazyRow(
          contentPadding = PaddingValues(horizontal = 20.dp),
          horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
          items(state.cast) { person ->
            CastCard(person) { onOpenPerson(person.id, person.name ?: "") }
          }
        }
      }
    }

    // ---- Similares ----
    if (state.similar.isNotEmpty()) {
      item {
        Text(
          stringResource(R.string.similar),
          style = MaterialTheme.typography.titleMedium,
          modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
        )
      }
      item {
        LazyRow(
          contentPadding = PaddingValues(horizontal = 20.dp),
          horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
          items(state.similar) { PosterCard(it, Modifier.clickable { onOpenItem(it) }) }
        }
      }
    }

    if (activeProStore != null) {
      item {
        mx.creapolis.peliculas.android.features.ads.AdBannerView(
          proStore = activeProStore,
          modifier = Modifier.padding(horizontal = 20.dp),
        )
      }
    }
  }

  if (showTrailer && state.trailerKey != null) {
    ModalBottomSheet(onDismissRequest = { showTrailer = false }) {
      Box(
        Modifier
          .fillMaxWidth()
          .height(230.dp)
          .padding(bottom = 24.dp),
      ) {
        TrailerWebView(videoKey = state.trailerKey.orEmpty(), modifier = Modifier.fillMaxSize())
      }
    }
  }
}

@Composable
private fun CircularAction(
  icon: androidx.compose.ui.graphics.vector.ImageVector,
  tint: Color,
  label: String,
  onClick: () -> Unit,
) {
  IconButton(
    onClick = onClick,
    modifier = Modifier
      .size(44.dp)
      .clip(CircleShape)
      .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.65f)),
  ) {
    Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(22.dp))
  }
}

@Composable
private fun RatingStars(score: Double?, onRate: (Double?) -> Unit) {
  val mine = score ?: 0.0
  Row {
    (1..5).forEach { i ->
      val full = mine >= i * 2.0
      val half = mine >= i * 2.0 - 1.0 && !full
      androidx.compose.material3.IconButton(
        onClick = { onRate(if (mine == i * 2.0) null else i * 2.0) },
        modifier = Modifier.size(38.dp),
      ) {
        Icon(
          imageVector = when {
            full -> Icons.Filled.Star
            half -> Icons.Filled.StarHalf
            else -> Icons.Filled.StarBorder
          },
          contentDescription = "$i/5",
          tint = if (full || half) Color(0xFFFFC94D) else MaterialTheme.colorScheme.outlineVariant,
        )
      }
    }
  }
}

/** Fila de episodio: fotograma + número + título + check de visto. */
@Composable
private fun EpisodeRow(ep: DetailViewModel.EpisodeRow, watched: Boolean, onToggle: () -> Unit) {
  Row(
    Modifier
      .fillMaxWidth()
      .clickable(onClick = onToggle)
      .padding(horizontal = 20.dp, vertical = 8.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Box(
      Modifier
        .width(96.dp)
        .height(54.dp)
        .clip(RoundedCornerShape(8.dp))
        .background(MaterialTheme.colorScheme.surfaceVariant),
    ) {
      if (ep.stillPath.isNotEmpty()) {
        AsyncImage(
          model = TmdbImage.url(ep.stillPath, "w185"),
          contentDescription = null,
          contentScale = ContentScale.Crop,
          modifier = Modifier.fillMaxSize(),
        )
      }
    }
    Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
      Text(
        "${ep.number}. ${ep.title}",
        style = MaterialTheme.typography.bodyMedium,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
      Text(
        ep.airDate.takeIf { it.isNotEmpty() } ?: "",
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
    Icon(
      imageVector = if (watched) Icons.Filled.Check else Icons.Outlined.StarOutline,
      contentDescription = stringResource(R.string.mark_watched),
      tint = if (watched) Color(0xFF66BB6A) else MaterialTheme.colorScheme.outlineVariant,
      modifier = Modifier.size(22.dp),
    )
  }
}

@Composable
private fun ProviderBadge(
  provider: mx.creapolis.peliculas.android.core.network.TmdbProvider,
  link: String?,
  title: String,
  context: Context,
) {
  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    modifier = Modifier
      .width(72.dp)
      .clickable { ProviderLinks.open(context, provider.providerId, title, link) },
  ) {
    AsyncImage(
      model = TmdbImage.url(provider.logoPath, "w92"),
      contentDescription = provider.providerName,
      contentScale = ContentScale.Crop,
      modifier = Modifier
        .size(48.dp)
        .clip(RoundedCornerShape(10.dp))
        .background(MaterialTheme.colorScheme.surfaceVariant),
    )
    Text(
      provider.providerName,
      style = MaterialTheme.typography.labelSmall,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
      textAlign = TextAlign.Center,
    )
  }
}

@Composable
private fun CastCard(person: mx.creapolis.peliculas.android.core.network.TmdbPerson, onClick: () -> Unit) {
  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    modifier = Modifier
      .width(84.dp)
      .clickable(onClick = onClick),
  ) {
    AsyncImage(
      model = TmdbImage.url(person.profilePath, "w185"),
      contentDescription = person.name,
      contentScale = ContentScale.Crop,
      modifier = Modifier
        .size(64.dp)
        .clip(CircleShape)
        .background(MaterialTheme.colorScheme.surfaceVariant),
    )
    Text(
      person.name ?: "",
      style = MaterialTheme.typography.labelMedium,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
    )
    person.character?.takeIf { it.isNotEmpty() }?.let {
      Text(
        it,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
    }
  }
}

/** Tráiler embebido con el iframe player de YouTube (como iOS). */
@Composable
private fun TrailerWebView(videoKey: String, modifier: Modifier = Modifier) {
  AndroidView(
    modifier = modifier,
    factory = { ctx ->
      android.webkit.WebView(ctx).apply {
        settings.javaScriptEnabled = true
        settings.mediaPlaybackRequiresUserGesture = false
        loadUrl(
          "https://www.youtube.com/embed/$videoKey?autoplay=1&playsinline=1&rel=0" +
            "&modestbranding=1",
        )
        webViewClient = android.webkit.WebViewClient()
      }
    },
  )
}
