package sk.tomasbudac.airwaves.ui

import androidx.annotation.StringRes
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import sk.tomasbudac.airwaves.AppContainer
import sk.tomasbudac.airwaves.R
import sk.tomasbudac.airwaves.ui.theme.AirwavesTheme
import sk.tomasbudac.airwaves.ui.theme.Spacing

enum class Tab(@StringRes val title: Int, val icon: Int) {
    Favorites(R.string.tab_favorites, R.drawable.ic_star),
    Search(R.string.tab_search, R.drawable.ic_search),
    Settings(R.string.tab_settings, R.drawable.ic_settings),
}

@Composable
fun AirwavesApp(container: AppContainer, onFirstPlay: () -> Unit) {
    val colors = AirwavesTheme.colors
    val favoritesViewModel = viewModel { FavoritesViewModel(container) }
    val searchViewModel = viewModel { SearchViewModel(container) }
    val settingsViewModel = viewModel { SettingsViewModel(container) }

    val favorites by favoritesViewModel.favorites.collectAsStateWithLifecycle()
    val playback by container.player.playback.collectAsStateWithLifecycle()
    // Bez obľúbených začíname hľadaním, rovnako ako web a iOS.
    var tab by rememberSaveable { mutableStateOf(if (favorites.isEmpty()) Tab.Search else Tab.Favorites) }
    var isNowPlayingOpen by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(playback.isActive) {
        if (playback.isActive) onFirstPlay()
    }
    BackHandler(enabled = tab != Tab.Favorites && favorites.isNotEmpty()) { tab = Tab.Favorites }

    Scaffold(
        containerColor = colors.background,
        bottomBar = {
            Column {
                AnimatedVisibility(
                    visible = playback.station != null,
                    enter = slideInVertically { it },
                    exit = slideOutVertically { it },
                ) {
                    MiniPlayer(
                        playback = playback,
                        onOpen = { isNowPlayingOpen = true },
                        onTogglePlay = container.player::togglePlayPause,
                        modifier = Modifier.padding(bottom = Spacing.xs),
                    )
                }
                NavigationBar(containerColor = colors.background, tonalElevation = 0.dp) {
                    Tab.entries.forEach { item ->
                        NavigationBarItem(
                            selected = tab == item,
                            onClick = { tab = item },
                            icon = { Icon(painterResource(item.icon), contentDescription = null) },
                            label = { Text(stringResource(item.title)) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = colors.textPrimary,
                                selectedTextColor = colors.textPrimary,
                                indicatorColor = colors.surfaceMuted,
                                unselectedIconColor = colors.textTertiary,
                                unselectedTextColor = colors.textTertiary,
                            ),
                        )
                    }
                }
            }
        },
    ) { padding ->
        val contentPadding = PaddingValues(bottom = padding.calculateBottomPadding())
        Box(Modifier.fillMaxSize().statusBarsPadding()) {
            when (tab) {
                Tab.Favorites -> {
                    val isEditing by favoritesViewModel.isEditing.collectAsStateWithLifecycle()
                    FavoritesScreen(
                        favorites = favorites,
                        playback = playback,
                        isEditing = isEditing,
                        contentPadding = contentPadding,
                        onTileTap = favoritesViewModel::tileTapped,
                        onEdit = favoritesViewModel::editTapped,
                        onDone = favoritesViewModel::doneTapped,
                        onRemove = favoritesViewModel::remove,
                        onMove = favoritesViewModel::move,
                        onFindStations = { tab = Tab.Search },
                    )
                }
                Tab.Search -> {
                    val state by searchViewModel.state.collectAsStateWithLifecycle()
                    SearchScreen(
                        state = state,
                        favorites = favorites,
                        playback = playback,
                        contentPadding = contentPadding,
                        onQueryChange = searchViewModel::queryChanged,
                        onSubmit = searchViewModel::search,
                        onCountrySelected = searchViewModel::countrySelected,
                        onGenreSelected = searchViewModel::genreSelected,
                        onClearFilters = searchViewModel::clearFilters,
                        onResultTap = searchViewModel::resultTapped,
                        onFavoriteTap = searchViewModel::favoriteTapped,
                        onLoadMore = searchViewModel::loadMore,
                        onRetry = searchViewModel::retry,
                        onVoiceResult = searchViewModel::voiceQueryRecognized,
                    )
                }
                Tab.Settings -> SettingsScreen(settingsViewModel, contentPadding)
            }
        }
    }

    if (isNowPlayingOpen && playback.station != null) {
        val station = playback.station!!
        NowPlayingSheet(
            playback = playback,
            isFavorite = favorites.any { it.id == station.id },
            onDismiss = { isNowPlayingOpen = false },
            onTogglePlay = container.player::togglePlayPause,
            onNext = container.player::next,
            onPrevious = container.player::previous,
            onToggleFavorite = { container.favorites.toggle(station) },
        )
    }
}
