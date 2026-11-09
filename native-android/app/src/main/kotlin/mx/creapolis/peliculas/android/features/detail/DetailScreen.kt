package mx.creapolis.peliculas.android.features.detail

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.automirrored.filled.PlaylistAdd
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.LiveTv
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.StarHalf
import androidx.compose.material.icons.filled.Tv
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import mx.creapolis.peliculas.android.LocalAppContainer
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.AppConfig
import mx.creapolis.peliculas.android.core.network.TmdbClient
import mx.creapolis.peliculas.android.core.network.TmdbPerson
import mx.creapolis.peliculas.android.core.network.TmdbProvider
import mx.creapolis.peliculas.android.features.ads.AdBannerView
import mx.creapolis.peliculas.android.features.home.SectionHeader
import mx.creapolis.peliculas.android.features.upnext.UpNextStore
import mx.creapolis.peliculas.android.ui.components.PosterCard
import mx.creapolis.peliculas.android.ui.components.RemoteImage
import mx.creapolis.peliculas.android.ui.components.shareItem
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * Detalle (port de `DetailView` en iOS): cabecera a sangre que se estira,
 * acciones de biblioteca + listas, nota y reseña, dirección/creador, sinopsis
 * plegable, temporadas y episodios, tráiler, dónde verla, reparto y similares.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailScreen(
  item: MediaItem,
  library: LibraryStore,
  onOpenPerson: (id: Int, name: String) -> Unit,
  onOpenItem: (MediaItem) -> Unit,
  onBack: (() -> Unit)? = null,
  vm: DetailViewModel = viewModel(key = item.key.description, factory = DetailViewModelFactory(item, library)),
) {
  val container = LocalAppContainer.current
  val proStore = container.proStore
  val context = LocalContext.current
  val haptics = LocalHapticFeedback.current
  val state by vm.state.collectAsState()
  val lib by library.state.collectAsState()
  val pro by proStore.state.collectAsState()
  var showTrailer by rememberSaveable { mutableStateOf(false) }
  var editingReview by rememberSaveable { mutableStateOf(false) }
  var reviewDraft by rememberSaveable { mutableStateOf("") }
  var overviewExpanded by rememberSaveable { mutableStateOf(false) }
  var moreOpen by remember { mutableStateOf(false) }
  var creatingList by remember { mutableStateOf(false) }

  if (state.detail == null) {
    Box(Modifier.fillMaxSize()) {
      if (state.failed) {
        Column(
          Modifier.fillMaxSize().padding(24.dp),
          horizontalAlignment = Alignment.CenterHorizontally,
          verticalArrangement = Arrangement.Center,
        ) {
          Icon(Icons.Filled.WifiOff, null, Modifier.size(44.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
          Text(
            stringResource(R.string.detail_error),
            style = MaterialTheme.typography.titleSmall,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 12.dp),
          )
          Button(onClick = vm::reload, modifier = Modifier.padding(top = 12.dp)) {
            Text(stringResource(R.string.retry))
          }
        }
      } else {
        CircularProgressIndicator(Modifier.align(Alignment.Center))
      }
      if (onBack != null) FloatingBack(onBack, Modifier.align(Alignment.TopStart))
    }
    return
  }

  // La foto rica: lo que se guarde desde aquí sube con título y póster.
  val current = state.item
  val listState = rememberLazyListState()
  val headerHeight = 460.dp
  val headerPx = with(LocalDensity.current) { headerHeight.toPx() }

  Box(Modifier.fillMaxSize()) {
    PullToRefreshBox(isRefreshing = state.refreshing, onRefresh = vm::reload) {
      LazyColumn(state = listState, modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 32.dp)) {
        // ---- Cabecera a sangre (parallax al subir, como el StretchyHeader de iOS) ----
        item(key = "header") {
          val offset by remember {
            derivedStateOf { if (listState.firstVisibleItemIndex == 0) listState.firstVisibleItemScrollOffset else headerPx.toInt() }
          }
          Header(
            item = current,
            tagline = state.detail?.tagline,
            statusRes = state.statusRes,
            meta = detailMeta(state, current),
            height = headerHeight,
            scrollOffset = offset,
          )
        }

        // ---- Acciones (Watchlist + favorito + visto + más) ----
        item(key = "actions") {
          Row(
            Modifier
              .fillMaxWidth()
              .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
          ) {
            val inWatchlist = lib.contains(current.key, LibraryStore.Kind.WATCHLIST)
            Button(
              onClick = {
                library.toggle(current, LibraryStore.Kind.WATCHLIST)
                haptics.performHapticFeedback(if (inWatchlist) HapticFeedbackType.ToggleOff else HapticFeedbackType.ToggleOn)
              },
              shape = RoundedCornerShape(24.dp),
              colors = ButtonDefaults.buttonColors(
                containerColor = if (inWatchlist) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.primary,
                contentColor = if (inWatchlist) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onPrimary,
              ),
              modifier = Modifier.weight(1f).height(48.dp),
              contentPadding = PaddingValues(horizontal = 16.dp),
            ) {
              Icon(if (inWatchlist) Icons.Filled.Check else Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(18.dp))
              Spacer(Modifier.width(6.dp))
              Text(
                stringResource(if (inWatchlist) R.string.in_watchlist else R.string.add_watchlist),
                style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
                maxLines = 1,
              )
            }

            val isFav = lib.contains(current.key, LibraryStore.Kind.FAVORITE)
            CircularAction(
              icon = if (isFav) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
              tint = if (isFav) Color(0xFFFF2D55) else MaterialTheme.colorScheme.onSurface,
              label = stringResource(if (isFav) R.string.remove_favorite else R.string.favorite),
            ) {
              library.toggle(current, LibraryStore.Kind.FAVORITE)
              haptics.performHapticFeedback(if (isFav) HapticFeedbackType.ToggleOff else HapticFeedbackType.ToggleOn)
            }

            val watched = lib.contains(current.key, LibraryStore.Kind.WATCHED)
            CircularAction(
              icon = if (watched) Icons.Filled.Visibility else Icons.Outlined.Visibility,
              tint = if (watched) Color(0xFF34C759) else MaterialTheme.colorScheme.onSurface,
              label = stringResource(if (watched) R.string.mark_unwatched else R.string.mark_watched),
            ) {
              library.toggle(current, LibraryStore.Kind.WATCHED)
              haptics.performHapticFeedback(if (watched) HapticFeedbackType.ToggleOff else HapticFeedbackType.ToggleOn)
            }

            Box {
              CircularAction(
                icon = Icons.Filled.MoreHoriz,
                tint = MaterialTheme.colorScheme.onSurface,
                label = stringResource(R.string.more_options),
              ) { moreOpen = true }
              DropdownMenu(expanded = moreOpen, onDismissRequest = { moreOpen = false }) {
                lib.visibleLists.forEach { list ->
                  val inList = lib.isInList(list.id, current.key)
                  DropdownMenuItem(
                    text = { Text(list.name) },
                    leadingIcon = { Icon(if (inList) Icons.Filled.Check else Icons.AutoMirrored.Filled.PlaylistAdd, null) },
                    onClick = {
                      library.toggleInList(current, list.id)
                      moreOpen = false
                    },
                  )
                }
                if (lib.visibleLists.isNotEmpty()) HorizontalDivider()
                val limitReason = stringResource(R.string.list_pro_unlimited)
                DropdownMenuItem(
                  text = { Text(stringResource(R.string.list_new_ellipsis)) },
                  leadingIcon = { Icon(Icons.Filled.Add, null) },
                  onClick = {
                    moreOpen = false
                    if (pro.isPro || lib.visibleLists.size < AppConfig.Pro.FREE_LIST_LIMIT) {
                      creatingList = true
                    } else {
                      proStore.presentPaywall(limitReason)
                    }
                  },
                )
                DropdownMenuItem(
                  text = { Text(stringResource(R.string.share)) },
                  leadingIcon = { Icon(Icons.Filled.Share, null) },
                  onClick = {
                    moreOpen = false
                    shareItem(context, current)
                  },
                )
              }
            }
          }
        }

        // ---- Dirección / creador ----
        if (state.creditNames != null) {
          item(key = "credit") {
            Row(Modifier.padding(horizontal = 20.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
              Text(
                stringResource(if (current.kind == MediaKind.TV) R.string.created_by else R.string.directed_by),
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
              Text(state.creditNames.orEmpty(), style = MaterialTheme.typography.bodyMedium)
            }
          }
        }

        // ---- Tu nota + reseña ----
        item(key = "rating") {
          Column(
            Modifier
              .fillMaxWidth()
              .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
          ) {
            Row(
              modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))
                .padding(start = 14.dp, end = 6.dp, top = 2.dp, bottom = 2.dp),
              verticalAlignment = Alignment.CenterVertically,
            ) {
              Text(
                stringResource(R.string.your_rating),
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
              )
              RatingStars(score = lib.score(current.key)) {
                library.rate(current, it)
                haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
              }
            }
            ReviewSection(
              review = lib.review(current.key).orEmpty(),
              editing = editingReview,
              draft = reviewDraft,
              onDraft = { reviewDraft = it },
              onEdit = {
                reviewDraft = lib.review(current.key).orEmpty()
                editingReview = true
              },
              onCancel = { editingReview = false },
              onSave = {
                library.setReview(current, reviewDraft)
                editingReview = false
              },
            )
          }
        }

        // ---- Sinopsis plegable ----
        if (current.overview.isNotEmpty()) {
          item(key = "overview") {
            Column(Modifier.padding(horizontal = 20.dp, vertical = 8.dp).animateContentSize()) {
              Text(
                current.overview,
                style = MaterialTheme.typography.bodyLarge,
                maxLines = if (overviewExpanded) Int.MAX_VALUE else 4,
                overflow = TextOverflow.Ellipsis,
              )
              if (current.overview.length > 220) {
                TextButton(onClick = { overviewExpanded = !overviewExpanded }, contentPadding = PaddingValues(0.dp)) {
                  Text(stringResource(if (overviewExpanded) R.string.less else R.string.more), fontWeight = FontWeight.SemiBold)
                }
              }
            }
          }
        }

        // ---- Temporadas y episodios ----
        if (current.kind == MediaKind.TV && state.seasons.isNotEmpty()) {
          item(key = "episodes-header") {
            val aired = state.episodes.filter { it.hasAired }.map { it.number }
            Row(
              Modifier.fillMaxWidth().padding(start = 20.dp, end = 8.dp, top = 16.dp),
              verticalAlignment = Alignment.CenterVertically,
            ) {
              Text(
                stringResource(R.string.episodes),
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                modifier = Modifier.weight(1f).semantics { heading() },
              )
              if (aired.isNotEmpty()) {
                val watched = lib.seasonWatchedCount(current.id, state.selectedSeason)
                Text(
                  "${minOf(watched, aired.size)}/${aired.size}",
                  style = MaterialTheme.typography.labelLarge,
                  color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                TextButton(onClick = {
                  library.toggleSeason(current.id, state.selectedSeason, aired)
                  haptics.performHapticFeedback(HapticFeedbackType.Confirm)
                }) {
                  Text(stringResource(if (watched >= aired.size) R.string.unmark_all else R.string.mark_all), fontWeight = FontWeight.SemiBold)
                }
              }
            }
          }
          item(key = "seasons") {
            LazyRow(
              contentPadding = PaddingValues(horizontal = 20.dp),
              horizontalArrangement = Arrangement.spacedBy(8.dp),
              modifier = Modifier.padding(vertical = 8.dp),
            ) {
              items(state.seasons, key = { it.seasonNumber }) { season ->
                val selected = season.seasonNumber == state.selectedSeason
                FilterChip(
                  selected = selected,
                  onClick = { vm.selectSeason(season.seasonNumber) },
                  label = { Text(season.name ?: stringResource(R.string.season_n, season.seasonNumber)) },
                  shape = CircleShape,
                  colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.onSurface,
                    selectedLabelColor = MaterialTheme.colorScheme.surface,
                  ),
                )
              }
            }
          }
          if (state.loadingEpisodes && state.episodes.isEmpty()) {
            item(key = "episodes-loading") {
              Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            }
          }
          items(state.episodes, key = { "ep-${state.selectedSeason}-${it.id}" }) { ep ->
            EpisodeRow(
              ep = ep,
              watched = lib.isEpisodeWatched(current.id, state.selectedSeason, ep.number),
              onToggle = {
                library.toggleEpisode(current.id, state.selectedSeason, ep.number)
                haptics.performHapticFeedback(HapticFeedbackType.ToggleOn)
              },
            )
          }
        }

        // ---- Tráiler ----
        state.trailerKey?.let { key ->
          item(key = "trailer") {
            Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
              SectionTitle(stringResource(R.string.trailer))
              TrailerCard(videoKey = key) { showTrailer = true }
            }
          }
        }

        // ---- Dónde verla ----
        if (state.providers.isNotEmpty()) {
          item(key = "providers") {
            Column(Modifier.padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
              SectionTitle(stringResource(R.string.where_to_watch), Modifier.padding(horizontal = 20.dp))
              LazyRow(
                contentPadding = PaddingValues(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
              ) {
                items(state.providers, key = { it.providerId }) { provider ->
                  ProviderBadge(provider) { ProviderLinks.open(context, provider, current.title, TmdbClient.userRegion) }
                }
              }
              val region = TmdbClient.userRegion
              val regionName = Locale("", region).getDisplayCountry(Locale.getDefault()).ifEmpty { region }
              Text(
                stringResource(R.string.providers_attribution, regionName),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp),
              )
            }
          }
        }

        // ---- Reparto ----
        if (state.cast.isNotEmpty()) {
          item(key = "cast") {
            Column(Modifier.padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
              SectionTitle(stringResource(R.string.cast), Modifier.padding(horizontal = 20.dp))
              LazyRow(
                contentPadding = PaddingValues(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
              ) {
                items(state.cast) { person ->
                  CastCard(person) { onOpenPerson(person.id, person.name.orEmpty()) }
                }
              }
            }
          }
        }

        // ---- Te puede gustar ----
        if (state.similar.isNotEmpty()) {
          item(key = "similar-h") { SectionHeader(stringResource(R.string.similar)) }
          item(key = "similar") {
            LazyRow(
              contentPadding = PaddingValues(horizontal = 20.dp),
              horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
              items(state.similar, key = { it.key.description }) { PosterCard(it) { onOpenItem(it) } }
            }
          }
        }

        // ---- Fallo parcial: la ficha se ve, pero algo no cargó ----
        if (state.failed) {
          item(key = "partial-error") {
            Column(
              Modifier.fillMaxWidth().padding(16.dp),
              horizontalAlignment = Alignment.CenterHorizontally,
            ) {
              Text(
                stringResource(R.string.detail_partial_error),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
              TextButton(onClick = vm::reload) { Text(stringResource(R.string.retry), fontWeight = FontWeight.SemiBold) }
            }
          }
        }

        item(key = "ad") { AdBannerView(proStore = proStore) }
      }
    }
    // Velo bajo la barra de estado al pasar la cabecera (en iOS ahí aparece la barra de navegación).
    val scrolledPastHeader by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 } }
    if (scrolledPastHeader) {
      Box(
        Modifier
          .fillMaxWidth()
          .windowInsetsTopHeight(WindowInsets.statusBars)
          .background(MaterialTheme.colorScheme.background.copy(alpha = 0.92f)),
      )
    }
    if (onBack != null) FloatingBack(onBack, Modifier.align(Alignment.TopStart))
  }

  if (showTrailer && state.trailerKey != null) {
    TrailerFullscreen(videoKey = state.trailerKey.orEmpty(), onDismiss = { showTrailer = false })
  }

  if (creatingList) {
    NewListDialog(
      onDismiss = { creatingList = false },
      onCreate = { name ->
        val id = library.createList(name)
        library.toggleInList(current, id)
        creatingList = false
      },
    )
  }
}

/** "2024 · 2 h 10 min · Drama, Crimen" (port de `meta` de `DetailLoader`). */
@Composable
private fun detailMeta(state: DetailViewModel.UiState, item: MediaItem): List<String> = buildList {
  val d = state.detail ?: return@buildList
  if (item.year.isNotEmpty()) add(item.year)
  d.runtime?.takeIf { it > 0 && item.kind == MediaKind.MOVIE }?.let {
    add(if (it >= 60) stringResource(R.string.runtime_hm, it / 60, it % 60) else stringResource(R.string.runtime_m, it))
  }
  d.numberOfSeasons?.takeIf { it > 0 && item.kind == MediaKind.TV }?.let {
    add(if (it == 1) stringResource(R.string.one_season) else stringResource(R.string.n_seasons_fmt, it))
  }
  d.genres?.take(2)?.map { it.name }?.takeIf { it.isNotEmpty() }?.let { add(it.joinToString(", ")) }
}

@Composable
private fun Header(
  item: MediaItem,
  tagline: String?,
  statusRes: Int?,
  meta: List<String>,
  height: androidx.compose.ui.unit.Dp,
  scrollOffset: Int,
) {
  val background = MaterialTheme.colorScheme.background
  val gradient = remember(background) {
    Brush.verticalGradient(
      0.00f to Color.Black.copy(alpha = 0.45f),
      0.25f to Color.Transparent,
      0.45f to Color.Transparent,
      0.85f to background.copy(alpha = 0.9f),
      1.00f to background,
    )
  }
  Box(Modifier.fillMaxWidth().height(height).clipToBounds()) {
    RemoteImage(
      path = item.backdropPath.ifEmpty { item.posterPath },
      size = "w1280",
      modifier = Modifier
        .fillMaxSize()
        // Parallax suave al subir (la imagen va a media velocidad).
        .graphicsLayer { translationY = scrollOffset * 0.5f },
    )
    Box(Modifier.fillMaxSize().background(gradient))
    Column(
      Modifier
        .align(Alignment.BottomStart)
        .padding(horizontal = 20.dp)
        .padding(bottom = 12.dp),
      verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
      Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(
          stringResource(if (item.kind == MediaKind.TV) R.string.badge_show else R.string.badge_movie).uppercase(),
          style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp),
          modifier = Modifier
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.6f))
            .padding(horizontal = 10.dp, vertical = 5.dp),
        )
        if (statusRes != null) {
          Text(
            stringResource(statusRes).uppercase(),
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
          )
        }
      }
      Text(
        item.title.ifEmpty { " " },
        style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Black),
        maxLines = 3,
        overflow = TextOverflow.Ellipsis,
        color = MaterialTheme.colorScheme.onBackground,
        modifier = Modifier.semantics { heading() },
      )
      if (!tagline.isNullOrEmpty()) {
        Text(
          tagline,
          style = MaterialTheme.typography.bodyMedium.copy(fontStyle = FontStyle.Italic),
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          maxLines = 2,
        )
      }
      Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        if (item.rating > 0) {
          Icon(Icons.Filled.Star, contentDescription = null, tint = Color(0xFFFFC94D), modifier = Modifier.size(16.dp))
          Text(
            "%.1f".format(item.rating),
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = Color(0xFFFFC94D),
          )
        }
        if (meta.isNotEmpty()) {
          Text(
            meta.joinToString(" · "),
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
          )
        }
      }
    }
  }
}

@Composable
private fun FloatingBack(onBack: () -> Unit, modifier: Modifier = Modifier) {
  IconButton(
    onClick = onBack,
    modifier = modifier
      .statusBarsPadding()
      .padding(start = 12.dp, top = 8.dp)
      .size(40.dp)
      .clip(CircleShape)
      .background(Color.Black.copy(alpha = 0.45f)),
  ) {
    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back), tint = Color.White)
  }
}

@Composable
private fun SectionTitle(text: String, modifier: Modifier = Modifier) {
  Text(
    text,
    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
    modifier = modifier.semantics { heading() },
  )
}

@Composable
private fun CircularAction(icon: ImageVector, tint: Color, label: String, onClick: () -> Unit) {
  IconButton(
    onClick = onClick,
    modifier = Modifier
      .size(48.dp)
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
      IconButton(onClick = { onRate(if (mine == i * 2.0) null else i * 2.0) }, modifier = Modifier.size(40.dp)) {
        Icon(
          imageVector = when {
            full -> Icons.Filled.Star
            half -> Icons.Filled.StarHalf
            else -> Icons.Filled.StarBorder
          },
          contentDescription = stringResource(R.string.n_of_5_stars, i),
          tint = if (full || half) Color(0xFFFFC94D) else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
        )
      }
    }
  }
}

@Composable
private fun ReviewSection(
  review: String,
  editing: Boolean,
  draft: String,
  onDraft: (String) -> Unit,
  onEdit: () -> Unit,
  onCancel: () -> Unit,
  onSave: () -> Unit,
) {
  Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
    Row(verticalAlignment = Alignment.CenterVertically) {
      Text(
        stringResource(R.string.your_review),
        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.weight(1f),
      )
      if (!editing) {
        TextButton(onClick = onEdit) {
          Icon(Icons.Filled.Edit, null, Modifier.size(16.dp))
          Spacer(Modifier.width(6.dp))
          Text(stringResource(if (review.isEmpty()) R.string.review_write else R.string.review_edit), fontWeight = FontWeight.SemiBold)
        }
      }
    }
    if (editing) {
      OutlinedTextField(
        value = draft,
        onValueChange = onDraft,
        placeholder = { Text(stringResource(R.string.review_prompt)) },
        modifier = Modifier.fillMaxWidth(),
        minLines = 3,
        maxLines = 6,
        shape = RoundedCornerShape(16.dp),
      )
      Row(Modifier.align(Alignment.End), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        TextButton(onClick = onCancel) { Text(stringResource(R.string.cancel)) }
        TextButton(onClick = onSave) { Text(stringResource(R.string.save), fontWeight = FontWeight.SemiBold) }
      }
    } else if (review.isNotEmpty()) {
      Text(
        review,
        style = MaterialTheme.typography.bodyMedium,
        modifier = Modifier
          .fillMaxWidth()
          .clip(RoundedCornerShape(16.dp))
          .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))
          .padding(12.dp),
      )
    }
  }
}

/** Fila de episodio (port de `EpisodeCell`): fotograma, título, fecha/duración, sinopsis y check. */
@Composable
private fun EpisodeRow(ep: DetailViewModel.EpisodeRow, watched: Boolean, onToggle: () -> Unit) {
  val aired = ep.hasAired
  val subtitle = buildList {
    UpNextStore.parseDay(ep.airDate)?.let { date ->
      add(
        if (aired) {
          date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))
        } else {
          stringResource(R.string.premieres_on, date.format(DateTimeFormatter.ofPattern("d MMMM", Locale.getDefault())))
        },
      )
    }
    ep.runtime?.takeIf { it > 0 }?.let { add(stringResource(R.string.runtime_m, it)) }
  }.joinToString(" · ")
  val label = if (watched) {
    stringResource(R.string.episode_watched_unmark, ep.number)
  } else {
    stringResource(R.string.mark_episode_n_watched, ep.number)
  }
  Row(
    Modifier
      .fillMaxWidth()
      .padding(start = 20.dp, end = 8.dp, top = 7.dp, bottom = 7.dp),
    verticalAlignment = Alignment.Top,
  ) {
    RemoteImage(
      path = ep.stillPath,
      size = "w300",
      placeholder = Icons.Filled.Tv,
      modifier = Modifier
        .width(128.dp)
        .height(72.dp)
        .clip(RoundedCornerShape(10.dp))
        .alpha(if (aired) 1f else 0.5f),
    )
    Column(Modifier.weight(1f).padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
      Text(
        "${ep.number}. ${ep.title}",
        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
      )
      if (subtitle.isNotEmpty()) {
        Text(subtitle, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
      }
      if (ep.overview.isNotEmpty()) {
        Text(
          ep.overview,
          style = MaterialTheme.typography.labelMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          maxLines = 2,
          overflow = TextOverflow.Ellipsis,
        )
      }
    }
    // Solo se marcan episodios ya emitidos (como iOS).
    if (aired) {
      IconButton(onClick = onToggle, modifier = Modifier.size(44.dp)) {
        Icon(
          imageVector = if (watched) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
          contentDescription = label,
          tint = if (watched) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
          modifier = Modifier.size(28.dp),
        )
      }
    } else {
      Spacer(Modifier.width(44.dp))
    }
  }
}

/** Miniatura de YouTube con botón de play (port de `TrailerCard`): el vídeo va a pantalla completa. */
@Composable
private fun TrailerCard(videoKey: String, onPlay: () -> Unit) {
  val label = stringResource(R.string.watch_trailer)
  Box(
    Modifier
      .fillMaxWidth()
      .aspectRatio(16f / 9f)
      .clip(RoundedCornerShape(18.dp))
      .background(MaterialTheme.colorScheme.surfaceVariant)
      .clickable(onClickLabel = label, onClick = onPlay),
    contentAlignment = Alignment.Center,
  ) {
    AsyncImage(
      model = "https://img.youtube.com/vi/$videoKey/hqdefault.jpg",
      contentDescription = null,
      contentScale = androidx.compose.ui.layout.ContentScale.Crop,
      modifier = Modifier.fillMaxSize(),
    )
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.5f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.45f))))
    Box(
      Modifier
        .size(64.dp)
        .clip(CircleShape)
        .background(Color.Black.copy(alpha = 0.45f))
        .border(0.5.dp, Color.White.copy(alpha = 0.3f), CircleShape),
      contentAlignment = Alignment.Center,
    ) {
      Icon(Icons.Filled.PlayArrow, contentDescription = label, tint = Color.White, modifier = Modifier.size(36.dp))
    }
  }
}

/** Reproductor a pantalla completa con "Abrir en YouTube" y cerrar (port de `TrailerFullscreenView`). */
@Composable
private fun TrailerFullscreen(videoKey: String, onDismiss: () -> Unit) {
  val context = LocalContext.current
  Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
    Box(Modifier.fillMaxSize().background(Color.Black)) {
      YouTubeEmbed(videoKey, Modifier.fillMaxWidth().aspectRatio(16f / 9f).align(Alignment.Center))
      Row(
        Modifier
          .align(Alignment.TopEnd)
          .statusBarsPadding()
          .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
      ) {
        IconButton(
          onClick = {
            context.startActivity(
              Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/watch?v=$videoKey")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
          },
          modifier = Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.15f)),
        ) {
          Icon(Icons.AutoMirrored.Filled.OpenInNew, stringResource(R.string.open_in_youtube), tint = Color.White)
        }
        IconButton(
          onClick = onDismiss,
          modifier = Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.15f)),
        ) {
          Icon(Icons.Filled.Close, stringResource(R.string.close), tint = Color.White)
        }
      }
    }
  }
}

/**
 * Iframe de youtube-nocookie con origen propio: evita el "Error 153" de los
 * embeds restringidos (mismo arreglo que iOS).
 */
@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun YouTubeEmbed(videoKey: String, modifier: Modifier = Modifier) {
  AndroidView(
    modifier = modifier,
    factory = { ctx ->
      android.webkit.WebView(ctx).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.mediaPlaybackRequiresUserGesture = false
        setBackgroundColor(android.graphics.Color.BLACK)
        webChromeClient = android.webkit.WebChromeClient()
        val html = """
          <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
          <style>html,body{margin:0;background:#000;height:100%}iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style></head>
          <body><iframe src="https://www.youtube-nocookie.com/embed/$videoKey?autoplay=1&playsinline=1&rel=0&modestbranding=1"
          allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe></body></html>
        """.trimIndent()
        loadDataWithBaseURL("https://peliculas.app", html, "text/html", "utf-8", null)
      }
    },
    onRelease = { it.destroy() },
  )
}

/** Logo del proveedor: toca y abre su app (o su web). */
@Composable
private fun ProviderBadge(provider: TmdbProvider, onOpen: () -> Unit) {
  val label = stringResource(R.string.watch_on, provider.providerName)
  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    modifier = Modifier
      .width(72.dp)
      .clickable(onClickLabel = label, onClick = onOpen),
  ) {
    RemoteImage(
      path = provider.logoPath,
      size = "w154",
      placeholder = Icons.Filled.LiveTv,
      contentDescription = label,
      modifier = Modifier
        .size(56.dp)
        .clip(RoundedCornerShape(13.dp)),
    )
    Text(
      provider.providerName,
      style = MaterialTheme.typography.labelSmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      maxLines = 2,
      overflow = TextOverflow.Ellipsis,
      textAlign = TextAlign.Center,
      modifier = Modifier.padding(top = 6.dp),
    )
  }
}

@Composable
private fun CastCard(person: TmdbPerson, onClick: () -> Unit) {
  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    modifier = Modifier
      .width(88.dp)
      .clickable(onClick = onClick),
  ) {
    RemoteImage(
      path = person.profilePath,
      size = "w185",
      placeholder = Icons.Filled.Person,
      contentDescription = person.name,
      modifier = Modifier
        .size(84.dp)
        .clip(CircleShape),
    )
    Text(
      person.name.orEmpty(),
      style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
      maxLines = 2,
      overflow = TextOverflow.Ellipsis,
      textAlign = TextAlign.Center,
      modifier = Modifier.padding(top = 6.dp),
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

@Composable
private fun NewListDialog(onDismiss: () -> Unit, onCreate: (String) -> Unit) {
  var name by remember { mutableStateOf("") }
  AlertDialog(
    onDismissRequest = onDismiss,
    title = { Text(stringResource(R.string.list_new)) },
    text = {
      OutlinedTextField(
        value = name,
        onValueChange = { name = it },
        singleLine = true,
        placeholder = { Text(stringResource(R.string.field_list_name)) },
        modifier = Modifier.fillMaxWidth(),
      )
    },
    confirmButton = {
      TextButton(enabled = name.isNotBlank(), onClick = { onCreate(name) }) { Text(stringResource(R.string.list_create_and_add)) }
    },
    dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
  )
}
