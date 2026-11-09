package mx.creapolis.peliculas.android.ui.root

import android.content.Context
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.automirrored.filled.LibraryBooks
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.PlayCircle
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.automirrored.outlined.LibraryBooks
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import mx.creapolis.peliculas.android.LocalAppContainer
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.library.LibraryStore
import mx.creapolis.peliculas.android.core.model.MediaItem
import mx.creapolis.peliculas.android.core.model.MediaKind
import mx.creapolis.peliculas.android.core.network.MediaListSource
import mx.creapolis.peliculas.android.features.auth.AccountScreen
import mx.creapolis.peliculas.android.features.auth.SignInScreen
import mx.creapolis.peliculas.android.features.detail.DetailScreen
import mx.creapolis.peliculas.android.features.gamification.AchievementToast
import mx.creapolis.peliculas.android.features.gamification.AchievementsScreen
import mx.creapolis.peliculas.android.features.gamification.LibraryCounts
import mx.creapolis.peliculas.android.features.home.HomeScreen
import mx.creapolis.peliculas.android.features.home.SeeAllScreen
import mx.creapolis.peliculas.android.features.library.HistoryScreen
import mx.creapolis.peliculas.android.features.library.LibraryGridScreen
import mx.creapolis.peliculas.android.features.library.LibraryNav
import mx.creapolis.peliculas.android.features.library.LibraryScreen
import mx.creapolis.peliculas.android.features.library.ListItemsScreen
import mx.creapolis.peliculas.android.features.library.ListsScreen
import mx.creapolis.peliculas.android.features.library.RatedGridScreen
import mx.creapolis.peliculas.android.features.onboarding.OnboardingScreen
import mx.creapolis.peliculas.android.features.people.ActorScreen
import mx.creapolis.peliculas.android.features.pro.PaywallScreen
import mx.creapolis.peliculas.android.features.search.Mood
import mx.creapolis.peliculas.android.features.search.ResultsScreen
import mx.creapolis.peliculas.android.features.search.SearchNav
import mx.creapolis.peliculas.android.features.search.SearchScreen
import mx.creapolis.peliculas.android.features.stats.StatsScreen
import mx.creapolis.peliculas.android.features.upnext.UpNextScreen
import mx.creapolis.peliculas.android.ui.navigation.DeepLinkRouter
import mx.creapolis.peliculas.android.ui.navigation.DeepLinkTarget
import mx.creapolis.peliculas.android.ui.navigation.SeeAllRoute

/** Destinos raíz (espejo de `AppTab` en iOS). */
enum class AppTab(val route: String) {
  HOME("home"),
  UP_NEXT("upnext"),
  LIBRARY("library"),
  SEARCH("search"),
}

/** Ruta de detalle para un título. */
private fun detailRoute(item: MediaItem): String = "detail/${item.kind.rawValue}/${item.id}"

private const val PREFS = "peliculas.app.v1"
private const val KEY_ONBOARDED = "onboarded.v2"

@Composable
fun RootScaffold() {
  val navController = rememberNavController()
  val backStack by navController.currentBackStackEntryAsState()
  // Pestaña dueña de la pila actual (un detalle abierto desde Biblioteca sigue en Biblioteca).
  val current = remember(backStack) {
    navController.currentBackStack.value
      .mapNotNull { entry -> AppTab.entries.firstOrNull { it.route == entry.destination.route } }
      .lastOrNull() ?: AppTab.HOME
  }
  val context = LocalContext.current
  val container = LocalAppContainer.current
  val library = container.library
  val session = container.session
  val achievements = container.achievements
  val proStore = container.proStore
  val libraryState by library.state.collectAsState()
  val sessionState by session.state.collectAsState()
  val proState by proStore.state.collectAsState()

  val appPrefs = remember { context.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }
  var onboarded by remember { mutableStateOf(appPrefs.getBoolean(KEY_ONBOARDED, false)) }
  fun setOnboarded(value: Boolean) {
    appPrefs.edit().putBoolean(KEY_ONBOARDED, value).apply()
    onboarded = value
  }

  fun openTab(tab: AppTab) {
    navController.navigate(tab.route) {
      popUpTo(navController.graph.findStartDestination().id) { saveState = true }
      launchSingleTop = true
      restoreState = true
    }
  }
  val openItem: (MediaItem) -> Unit = { navController.navigate(detailRoute(it)) }
  val openAccount: () -> Unit = { navController.navigate("account") { launchSingleTop = true } }
  val openSignIn: () -> Unit = { navController.navigate("signin") { launchSingleTop = true } }

  // Logros: se evalúan con cada cambio relevante de la biblioteca y celebran
  // lo nuevo (como `achievements.check` en el onChange de iOS).
  val counts = LibraryCounts.from(library, libraryState)
  LaunchedEffect(counts) {
    achievements.check(counts)
    container.reminders.reschedule(counts.watchlist)
  }

  // "Siguiente" se recalcula al marcar episodios o seguir series, desde donde sea
  // (detalle, Inicio o la propia pestaña). Con caché: sin peticiones de más.
  LaunchedEffect(libraryState.watchedEpisodeCount, libraryState.followedKey(), sessionState.isSignedIn) {
    container.upNext.load()
  }

  // Deep links / App Links entrantes (port de `DeepLinkRouter.open`).
  LaunchedEffect(Unit) {
    DeepLinkRouter.targets.collect { target ->
      when (target) {
        DeepLinkTarget.Home -> openTab(AppTab.HOME)
        DeepLinkTarget.Search -> openTab(AppTab.SEARCH)
        DeepLinkTarget.Library -> openTab(AppTab.LIBRARY)
        DeepLinkTarget.UpNext -> openTab(AppTab.UP_NEXT)
        DeepLinkTarget.Account -> openAccount()
        DeepLinkTarget.Pro -> proStore.presentPaywall()
        is DeepLinkTarget.Detail -> navController.navigate("detail/${target.kind.rawValue}/${target.id}")
      }
      DeepLinkRouter.consume()
    }
  }

  // El contenido llega bajo la barra de estado (héroe y cabecera a sangre, como iOS);
  // cada pantalla pone su propio margen superior (TopAppBar / RootTitleBar).
  Scaffold(
    contentWindowInsets = WindowInsets(0, 0, 0, 0),
    bottomBar = {
      NavigationBar(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f), tonalElevation = 0.dp) {
        AppTab.entries.forEach { tab ->
          val selected = tab == current
          NavigationBarItem(
            selected = selected,
            onClick = {
              // Tocar la pestaña activa vuelve a su raíz (como iOS).
              if (tab == current) navController.popBackStack(tab.route, inclusive = false) else openTab(tab)
            },
            icon = { Icon(if (selected) tab.filledIcon else tab.outlinedIcon, contentDescription = null) },
            label = { Text(stringResource(tab.labelRes)) },
            colors = NavigationBarItemDefaults.colors(
              selectedIconColor = MaterialTheme.colorScheme.primary,
              selectedTextColor = MaterialTheme.colorScheme.primary,
              indicatorColor = MaterialTheme.colorScheme.primaryContainer,
            ),
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
            onOpenItem = openItem,
            onOpenAccount = openAccount,
          )
        }
        composable(AppTab.UP_NEXT.route) {
          UpNextScreen(onOpenItem = openItem, onSearchSeries = { openTab(AppTab.SEARCH) }, onOpenAccount = openAccount)
        }
        composable(AppTab.LIBRARY.route) {
          LibraryScreen(
            library = library,
            signedIn = sessionState.isSignedIn,
            nav = LibraryNav(
              openStats = { navController.navigate("stats") },
              openAchievements = { navController.navigate("achievements") },
              openHistory = { navController.navigate("history") },
              openAccount = openAccount,
              openSignIn = openSignIn,
              openGrid = { kind -> navController.navigate("library/grid/${kind.name}") },
              openRated = { navController.navigate("library/rated") },
              openLists = { navController.navigate("library/lists") },
              openList = { id, name -> navController.navigate("library/list/$id/${android.net.Uri.encode(name)}") },
              openItem = openItem,
              explore = { openTab(AppTab.HOME) },
            ),
          )
        }
        composable(AppTab.SEARCH.route) {
          SearchScreen(
            nav = SearchNav(
              openGenre = { kind, genre ->
                navController.navigate("results/genre/${kind.rawValue}/${genre.id}/${android.net.Uri.encode(genre.name)}")
              },
              openMood = { mood -> navController.navigate("results/mood/${mood.name}") },
              openPerson = { id, name -> navController.navigate("person/$id/${android.net.Uri.encode(name)}") },
            ),
            onOpenItem = openItem,
            onOpenAccount = openAccount,
          )
        }

        composable("library/grid/{kind}") { entry ->
          val kind = runCatching { LibraryStore.Kind.valueOf(entry.arguments?.getString("kind") ?: "WATCHLIST") }
            .getOrDefault(LibraryStore.Kind.WATCHLIST)
          val title = stringResource(
            when (kind) {
              LibraryStore.Kind.WATCHLIST -> R.string.cat_watchlist
              LibraryStore.Kind.FAVORITE -> R.string.cat_favorites
              LibraryStore.Kind.WATCHED -> R.string.cat_watched
            },
          )
          BarScreen(title, navController) { LibraryGridScreen(kind = kind, library = library, onOpenItem = openItem) }
        }
        composable("library/rated") {
          BarScreen(stringResource(R.string.cat_rated), navController) { RatedGridScreen(library, onOpenItem = openItem) }
        }
        composable("library/lists") {
          BarScreen(stringResource(R.string.cat_lists), navController) {
            ListsScreen(library = library, onOpenList = { id, name ->
              navController.navigate("library/list/$id/${android.net.Uri.encode(name)}")
            })
          }
        }
        composable("library/list/{id}/{name}") { entry ->
          val id = entry.arguments?.getString("id").orEmpty()
          // El nombre vivo (si se renombra o sincroniza mientras está abierta).
          val name = libraryState.lists[id]?.name ?: entry.arguments?.getString("name").orEmpty()
          BarScreen(name, navController) { ListItemsScreen(listId = id, library = library, onOpenItem = openItem) }
        }
        composable("stats") {
          BarScreen(stringResource(R.string.stats_title), navController) { StatsScreen(library = library) }
        }
        composable("achievements") {
          BarScreen(stringResource(R.string.achievements_title), navController) {
            AchievementsScreen(store = achievements, onBack = { navController.popBackStack() })
          }
        }
        composable("history") {
          BarScreen(stringResource(R.string.history_title), navController) {
            HistoryScreen(library = library, onBack = { navController.popBackStack() }, onOpenItem = openItem)
          }
        }
        composable("signin") {
          BarScreen("", navController) {
            SignInScreen(session = session, onDone = { navController.popBackStack() })
          }
        }
        composable("account") {
          BarScreen(stringResource(R.string.account), navController) {
            AccountScreen(
              onSignIn = openSignIn,
              onOpenAchievements = { navController.navigate("achievements") },
              onReplayOnboarding = {
                navController.popBackStack()
                setOnboarded(false)
              },
            )
          }
        }

        composable("detail/{kind}/{id}") { entry ->
          val kind = runCatching { MediaKind.valueOf((entry.arguments?.getString("kind") ?: "movie").uppercase()) }
            .getOrDefault(MediaKind.MOVIE)
          val id = entry.arguments?.getString("id")?.toIntOrNull() ?: 0
          // Si la biblioteca ya conoce el título, la cabecera se pinta al instante.
          val known = library.item(mx.creapolis.peliculas.android.core.model.MediaKey(kind, id))
          DetailScreen(
            item = known ?: MediaItem(id = id, title = "", kind = kind),
            library = library,
            onBack = { navController.popBackStack() },
            onOpenPerson = { pid, name -> navController.navigate("person/$pid/${android.net.Uri.encode(name)}") },
            onOpenItem = openItem,
          )
        }
        composable("seeall/{key}") { entry ->
          SeeAllRoute.fromKey(entry.arguments?.getString("key").orEmpty())?.let { route ->
            BarScreen(stringResource(route.titleRes), navController) { SeeAllScreen(route, openItem) }
          }
        }
        composable("results/genre/{kind}/{genreId}/{name}") { entry ->
          val kind = runCatching { MediaKind.valueOf((entry.arguments?.getString("kind") ?: "movie").uppercase()) }
            .getOrDefault(MediaKind.MOVIE)
          val genreId = entry.arguments?.getString("genreId")?.toIntOrNull() ?: 0
          val name = entry.arguments?.getString("name").orEmpty()
          BarScreen(name, navController) {
            ResultsScreen(
              title = name,
              baseSource = MediaListSource.Genre(kind, genreId),
              filtersEnabled = true,
              emptyMessage = stringResource(R.string.genre_empty),
              onOpenItem = openItem,
            )
          }
        }
        composable("results/mood/{mood}") { entry ->
          entry.arguments?.getString("mood")?.let { runCatching { Mood.valueOf(it) }.getOrNull() }?.let { mood ->
            val title = stringResource(mood.titleRes)
            BarScreen(title, navController) { ResultsScreen(title = title, baseSource = mood.source, onOpenItem = openItem) }
          }
        }
        composable("person/{id}/{name}") { entry ->
          val id = entry.arguments?.getString("id")?.toIntOrNull() ?: 0
          val name = entry.arguments?.getString("name").orEmpty()
          BarScreen(name, navController) { ActorScreen(personId = id, fallbackName = name, onOpenItem = openItem) }
        }
      }

      val toastState by achievements.state.collectAsState()
      AchievementToast(achievement = toastState.toast, onDismiss = achievements::dismissToast)

      if (!onboarded) {
        Dialog(onDismissRequest = {}, properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnBackPress = false)) {
          OnboardingScreen(
            onDone = { setOnboarded(true) },
            onSignIn = {
              setOnboarded(true)
              openSignIn()
            },
          )
        }
      }

      if (proState.showingPaywall) {
        Dialog(
          onDismissRequest = proStore::dismissPaywall,
          properties = DialogProperties(usePlatformDefaultWidth = false),
        ) {
          PaywallScreen(proStore = proStore, onDismiss = proStore::dismissPaywall)
        }
      }

      proState.message?.let { msg ->
        AlertDialog(
          onDismissRequest = proStore::clearMessage,
          text = { Text(msg) },
          confirmButton = { TextButton(onClick = proStore::clearMessage) { Text(stringResource(R.string.dialog_ok)) } },
        )
      }
    }
  }
}

/** Clave de las series seguidas: si cambia, "Siguiente" tiene series nuevas que pedir. */
private fun LibraryStore.State.followedKey(): Int {
  val shows = listOf(LibraryStore.Kind.WATCHLIST, LibraryStore.Kind.FAVORITE).flatMap { kind ->
    marks[kind].orEmpty().filter { it.key.kind == MediaKind.TV && !it.value.deleted }.keys
  }
  return shows.toSet().hashCode()
}

/** Pantalla empujada con barra superior y botón Atrás (patrón de navegación de Android). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BarScreen(title: String, navController: NavHostController, content: @Composable () -> Unit) {
  Column(Modifier.fillMaxSize()) {
    TopAppBar(
      title = { Text(title, maxLines = 1) },
      navigationIcon = {
        IconButton(onClick = { navController.popBackStack() }) {
          Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
        }
      },
    )
    Box(Modifier.weight(1f)) { content() }
  }
}

/** Etiqueta localizada de cada pestaña. */
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
    AppTab.LIBRARY -> Icons.AutoMirrored.Filled.LibraryBooks
    AppTab.SEARCH -> Icons.Filled.Search
  }

private val AppTab.outlinedIcon
  get() = when (this) {
    AppTab.HOME -> Icons.Outlined.Home
    AppTab.UP_NEXT -> Icons.Outlined.PlayCircle
    AppTab.LIBRARY -> Icons.AutoMirrored.Outlined.LibraryBooks
    AppTab.SEARCH -> Icons.Outlined.Search
  }
