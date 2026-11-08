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
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.features.home.HomeScreen
import mx.creapolis.peliculas.android.features.home.SeeAllScreen
import mx.creapolis.peliculas.android.ui.screens.PlaceholderScreen

/** Destinos raíz (espejo de `AppTab` en iOS). */
enum class AppTab(val route: String) {
  HOME("home"),
  UP_NEXT("upnext"),
  LIBRARY("library"),
  SEARCH("search"),
}

@Composable
fun RootScaffold() {
  val navController = rememberNavController()
  val backStack by navController.currentBackStackEntryAsState()
  val current = AppTab.entries.firstOrNull { it.route == backStack?.destination?.route } ?: AppTab.HOME

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
          HomeScreen(onSeeAll = { route -> navController.navigate("seeall/${route.key}") })
        }
        composable(AppTab.UP_NEXT.route) { PlaceholderScreen(AppTab.UP_NEXT) }
        composable(AppTab.LIBRARY.route) { PlaceholderScreen(AppTab.LIBRARY) }
        composable(AppTab.SEARCH.route) {
          val searchNav = mx.creapolis.peliculas.android.features.search.SearchNav(
            openGenre = { kind, genre -> navController.navigate("results/genre/${kind.rawValue}/${genre.id}/${android.net.Uri.encode(genre.name)}") },
            openMood = { mood -> navController.navigate("results/mood/${mood.name}") },
            openPerson = { id, name -> navController.navigate("person/$id/${android.net.Uri.encode(name)}") },
          )
          mx.creapolis.peliculas.android.features.search.SearchScreen(nav = searchNav)
        }

        composable("results/genre/{kind}/{genreId}/{name}") { entry ->
          val kind = mx.creapolis.peliculas.android.core.model.MediaKind.valueOf(
            (entry.arguments?.getString("kind") ?: "movie").uppercase())
          val genreId = entry.arguments?.getString("genreId")?.toIntOrNull() ?: 0
          val name = entry.arguments?.getString("name").orEmpty()
          ResultsWithBar(
            title = name,
            baseSource = mx.creapolis.peliculas.android.core.network.MediaListSource.Genre(kind, genreId),
            filtersEnabled = true,
            onBack = { navController.popBackStack() },
          )
        }

        composable("results/mood/{mood}") { entry ->
          val mood = entry.arguments?.getString("mood")
            ?.let { runCatching { mx.creapolis.peliculas.android.features.search.Mood.valueOf(it) }.getOrNull() }
          if (mood != null) {
            val title = androidx.compose.ui.res.stringResource(mood.titleRes)
            ResultsWithBar(
              title = title,
              baseSource = mood.source,
              emptyMessage = androidx.compose.ui.res.stringResource(R.string.seeall_empty),
              onBack = { navController.popBackStack() },
            )
          }
        }

        composable("person/{id}/{name}") { entry ->
          val id = entry.arguments?.getString("id")?.toIntOrNull() ?: 0
          val name = entry.arguments?.getString("name").orEmpty()
          Column(Modifier.fillMaxSize()) {
            TopAppBar(
              title = { Text(name) },
              navigationIcon = {
                IconButton(onClick = { navController.popBackStack() }) {
                  Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                }
              },
            )
            mx.creapolis.peliculas.android.features.people.ActorScreen(personId = id, fallbackName = name)
          }
        }
        composable("seeall/{key}") { entry ->
          val key = entry.arguments?.getString("key").orEmpty()
          val route = mx.creapolis.peliculas.android.ui.navigation.SeeAllRoute.fromKey(key)
          if (route != null) {
            SeeAllWithBar(route = route, onBack = { navController.popBackStack() })
          }
        }
      }
    }
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

/** Resultados de género/mood con barra superior. */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun ResultsWithBar(
  title: String,
  baseSource: mx.creapolis.peliculas.android.core.network.MediaListSource,
  filtersEnabled: Boolean = false,
  emptyMessage: String? = null,
  onBack: () -> Unit,
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
    )
  }
}

/** "Ver todo" con barra superior (título + atrás), sin Scaffold anidado. */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun SeeAllWithBar(
  route: mx.creapolis.peliculas.android.ui.navigation.SeeAllRoute,
  onBack: () -> Unit,
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
    SeeAllScreen(route)
  }
}
