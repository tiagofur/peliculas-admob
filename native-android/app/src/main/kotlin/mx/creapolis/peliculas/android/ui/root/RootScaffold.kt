package mx.creapolis.peliculas.android.ui.root

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.LibraryBooks
import androidx.compose.material.icons.outlined.PlayCircle
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import mx.creapolis.peliculas.android.PeliculasApp
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.features.detail.DetailScreen
import mx.creapolis.peliculas.android.features.home.HomeScreen
import mx.creapolis.peliculas.android.features.home.SeeAllScreen
import mx.creapolis.peliculas.android.features.search.SearchScreen
import mx.creapolis.peliculas.android.ui.navigation.SeeAllRoute
import mx.creapolis.peliculas.android.ui.screens.PlaceholderScreen

/** Destinos raíz (espejo de `AppTab` en iOS). */
enum class AppTab(val route: String) {
  HOME("home"),
  UP_NEXT("upnext"),
  LIBRARY("library"),
  SEARCH("search"),
}

/** Ruta de detalle para un título. */
private fun detailRoute(item: MediaItem): String = "detail/${item.kind.rawValue}/${item.id}"

@Composable
fun RootScaffold() {
  val navController = rememberNavController()
  val backStack by navController.currentBackStackEntryAsState()
  val current = AppTab.entries.firstOrNull { it.route == backStack?.destination?.route } ?: AppTab.HOME
  val library = (LocalContext.current.applicationContext as PeliculasApp).container.library

  Scaffold(
    bottomBar = {
      NavigationBar {
        AppTab.entries.forEach { tab ->
          val selected = tab == current
          NavigationBarItem(
            selected = selected,
            onClick = {
              navController.navigate(tab.route) {
                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                launchSingleTop = true
                restoreState = true
              }
            },
            icon = {
              Icon(
                imageVector = if (selected) tab.filledIcon else tab.outlinedIcon,
                contentDescription = null,
              )
            },
            label = { Text(stringResource(tab.labelRes)) },
          )
        }
      }
    },
  ) { padding ->
    Box(Modifier.fillMaxSize().padding(padding)) {
      NavHost(navController = navController, startDestination = AppTab.HOME.route) {
        composable(AppTab.HOME.route) {
          HomeScreen(
            onSeeAll = { route -> navController.navigate("seeall/${route.key}") },
            onOpenItem = { item -> navController.navigate(detailRoute(item)) },
          )
        }
        composable(AppTab.UP_NEXT.route) { PlaceholderScreen(AppTab.UP_NEXT) }
        composable(AppTab.LIBRARY.route) { PlaceholderScreen(AppTab.LIBRARY) }
        composable(AppTab.SEARCH.route) {
          SearchScreen(
            nav = mx.creapolis.peliculas.android.features.search.SearchNav(
              openGenre = { kind, genre ->
                navController.navigate("results/genre/${kind.rawValue}/${genre.id}/${android.net.Uri.encode(genre.name)}")
              },
              openMood = { mood -> navController.navigate("results/mood/${mood.name}") },
              openPerson = { id, name -> navController.navigate("person/$id/${android.net.Uri.encode(name)}") },
            ),
            onOpenItem = { item -> navController.navigate(detailRoute(item)) },
          )
        }

        // ---- Detalle ----
        composable("detail/{kind}/{id}") { entry ->
          val kind = runCatching {
            MediaKind.valueOf((entry.arguments?.getString("kind") ?: "movie").uppercase())
          }.getOrDefault(MediaKind.MOVIE)
          val id = entry.arguments?.getString("id")?.toIntOrNull() ?: 0
          DetailWithBar(
            item = MediaItem(id = id, title = "", posterPath = "", backdropPath = "", rating = 0.0, kind = kind),
            library = library,
            onBack = { navController.popBackStack() },
            onOpenPerson = { pid, name -> navController.navigate("person/$pid/${android.net.Uri.encode(name)}") },
            onOpenItem = { item -> navController.navigate(detailRoute(item)) },
          )
        }

        // ---- Ver todo ----
        composable("seeall/{key}") { entry ->
          val route = SeeAllRoute.fromKey(entry.arguments?.getString("key").orEmpty())
          if (route != null) {
            SeeAllWithBar(
              route = route,
              onBack = { navController.popBackStack() },
              onOpenItem = { item -> navController.navigate(detailRoute(item)) },
            )
          }
        }

        // ---- Género / mood ----
        composable("results/genre/{kind}/{genreId}/{name}") { entry ->
          val kind = runCatching {
            MediaKind.valueOf((entry.arguments?.getString("kind") ?: "movie").uppercase())
          }.getOrDefault(MediaKind.MOVIE)
          val genreId = entry.arguments?.getString("genreId")?.toIntOrNull() ?: 0
          val name = entry.arguments?.getString("name").orEmpty()
          ResultsWithBar(
            title = name,
            baseSource = MediaListSource.Genre(kind, genreId),
            filtersEnabled = true,
            onBack = { navController.popBackStack() },
            onOpenItem = { item -> navController.navigate(detailRoute(item)) },
          )
        }

        composable("results/mood/{mood}") { entry ->
          val mood = entry.arguments?.getString("mood")
            ?.let { runCatching { mx.creapolis.peliculas.android.features.search.Mood.valueOf(it) }.getOrNull() }
          if (mood != null) {
            ResultsWithBar(
              title = stringResource(mood.titleRes),
              baseSource = mood.source,
              onBack = { navController.popBackStack() },
              onOpenItem = { item -> navController.navigate(detailRoute(item)) },
            )
          }
        }

        // ---- Persona ----
        composable("person/{id}/{name}") { entry ->
          val id = entry.arguments?.getString("id")?.toIntOrNull() ?: 0
          val name = entry.arguments?.getString("name").orEmpty()
          PersonWithBar(
            personId = id,
            name = name,
            onBack = { navController.popBackStack() },
            onOpenItem = { item -> navController.navigate(detailRoute(item)) },
          )
        }
      }
    }
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DetailWithBar(
  item: MediaItem,
  library: mx.creapolis.peliculas.android.core.library.LibraryStore,
  onBack: () -> Unit,
  onOpenPerson: (Int, String) -> Unit,
  onOpenItem: (MediaItem) -> Unit,
) {
  Column(Modifier.fillMaxSize()) {
    TopAppBar(
      title = { Text("") },
      navigationIcon = {
        IconButton(onClick = onBack) {
          Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
        }
      },
    )
    DetailScreen(item = item, library = library, onOpenPerson = onOpenPerson, onOpenItem = onOpenItem)
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SeeAllWithBar(
  route: SeeAllRoute,
  onBack: () -> Unit,
  onOpenItem: (MediaItem) -> Unit,
) {
  Column(Modifier.fillMaxSize()) {
    TopAppBar(
      title = { Text(stringResource(route.titleRes)) },
      navigationIcon = {
        IconButton(onClick = onBack) {
          Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
        }
      },
    )
    SeeAllScreen(route, onOpenItem)
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ResultsWithBar(
  title: String,
  baseSource: MediaListSource,
  filtersEnabled: Boolean = false,
  emptyMessage: String? = null,
  onBack: () -> Unit,
  onOpenItem: (MediaItem) -> Unit,
) {
  Column(Modifier.fillMaxSize()) {
    TopAppBar(
      title = { Text(title) },
      navigationIcon = {
        IconButton(onClick = onBack) {
          Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
        }
      },
    )
    mx.creapolis.peliculas.android.features.search.ResultsScreen(
      title = title,
      baseSource = baseSource,
      filtersEnabled = filtersEnabled,
      emptyMessage = emptyMessage,
      onOpenItem = onOpenItem,
    )
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PersonWithBar(
  personId: Int,
  name: String,
  onBack: () -> Unit,
  onOpenItem: (MediaItem) -> Unit,
) {
  Column(Modifier.fillMaxSize()) {
    TopAppBar(
      title = { Text(name) },
      navigationIcon = {
        IconButton(onClick = onBack) {
          Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
        }
      },
    )
    mx.creapolis.peliculas.android.features.people.ActorScreen(
      personId = personId,
      fallbackName = name,
      onOpenItem = onOpenItem,
    )
  }
}

/** Etiqueta localizada de cada pestaña (compartida con los placeholders). */
val AppTab.labelRes: Int
  get() = when (this) {
    AppTab.HOME -> R.string.tab_home
    AppTab.UP_NEXT -> R.string.tab_up_next
    AppTab.LIBRARY -> R.string.tab_library
    AppTab.SEARCH -> R.string.tab_search
  }

private val AppTab.filledIcon
  get() = when (this) {
    AppTab.HOME -> Icons.Filled.Home
    AppTab.UP_NEXT -> Icons.Filled.PlayCircle
    AppTab.LIBRARY -> Icons.Filled.LibraryBooks
    AppTab.SEARCH -> Icons.Filled.Search
  }

private val AppTab.outlinedIcon
  get() = when (this) {
    AppTab.HOME -> Icons.Outlined.Home
    AppTab.UP_NEXT -> Icons.Outlined.PlayCircle
    AppTab.LIBRARY -> Icons.Outlined.LibraryBooks
    AppTab.SEARCH -> Icons.Outlined.Search
  }
