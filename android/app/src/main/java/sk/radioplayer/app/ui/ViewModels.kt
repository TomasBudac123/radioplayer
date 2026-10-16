package sk.radioplayer.app.ui

import androidx.annotation.StringRes
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import sk.radioplayer.app.AppContainer
import sk.radioplayer.app.R
import sk.radioplayer.app.data.Country
import sk.radioplayer.app.data.FavoritesBackup
import sk.radioplayer.app.data.Station
import sk.radioplayer.app.data.StationQuery
import sk.radioplayer.app.playback.MediaIds

class FavoritesViewModel(private val container: AppContainer) : ViewModel() {
    val favorites = container.favorites.favorites
    val playback = container.player.playback

    private val _isEditing = MutableStateFlow(false)
    val isEditing: StateFlow<Boolean> = _isEditing.asStateFlow()

    init {
        refresh()
    }

    fun tileTapped(station: Station) {
        val playback = playback.value
        if (playback.isCurrent(station) && playback.status != sk.radioplayer.app.playback.Playback.Status.Failed) {
            container.player.togglePlayPause()
        } else {
            container.player.play(station, MediaIds.FAVORITES, favorites.value)
        }
    }

    fun editTapped() = _isEditing.update { true }

    fun doneTapped() = _isEditing.update { false }

    fun remove(station: Station) {
        container.favorites.remove(station.id)
        if (favorites.value.isEmpty()) _isEditing.value = false
    }

    fun move(from: Int, to: Int) = container.favorites.move(from, to)

    /** Obnoví údaje obľúbených z databázy (nové ikony, zmenené adresy streamov). */
    private fun refresh() {
        val ids = favorites.value.filterNot { it.isManual }.map { it.id }
        if (ids.isEmpty()) return
        viewModelScope.launch {
            runCatching { container.api.stations(ids) }.onSuccess(container.favorites::refresh)
        }
    }
}

data class SearchState(
    val query: String = "",
    val countryCode: String? = null,
    val genreTag: String? = null,
    val countries: List<Country> = emptyList(),
    val results: List<Station> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val canLoadMore: Boolean = false,
    @StringRes val errorMessage: Int? = null,
) {
    val selectedCountry: Country? get() = countries.firstOrNull { it.code == countryCode }
    val stationQuery: StationQuery get() = StationQuery(name = query, countryCode = countryCode, tag = genreTag)
    @get:StringRes val resultsTitle: Int get() = if (stationQuery.isFiltered) R.string.search_results else R.string.search_most_popular
}

@OptIn(FlowPreview::class)
class SearchViewModel(private val container: AppContainer) : ViewModel() {
    private val _state = MutableStateFlow(SearchState())
    val state: StateFlow<SearchState> = _state.asStateFlow()
    val favorites = container.favorites.favorites
    val playback = container.player.playback

    private var searchJob: Job? = null
    private var nextOffset = 0
    private var lastSearchedQuery: String? = null

    init {
        search()
        viewModelScope.launch {
            runCatching { container.api.countries() }.onSuccess { countries -> _state.update { it.copy(countries = countries) } }
        }
        viewModelScope.launch {
            _state.map { it.query }.distinctUntilChanged().drop(1).debounce(450).collect { query ->
                if (query != lastSearchedQuery) search()
            }
        }
    }

    fun queryChanged(query: String) = _state.update { it.copy(query = query) }

    /** Hlasom vyslovený názov sa hneď vyhľadá, bez čakania na debounce. */
    fun voiceQueryRecognized(query: String) {
        _state.update { it.copy(query = query) }
        search()
    }

    fun countrySelected(code: String?) {
        _state.update { it.copy(countryCode = code) }
        search()
    }

    fun genreSelected(tag: String?) {
        _state.update { it.copy(genreTag = tag) }
        search()
    }

    fun clearFilters() {
        _state.update { it.copy(countryCode = null, genreTag = null) }
        search()
    }

    fun retry() = search()

    fun resultTapped(station: Station) {
        val playback = playback.value
        if (playback.isCurrent(station) && playback.status != sk.radioplayer.app.playback.Playback.Status.Failed) {
            container.player.togglePlayPause()
        } else {
            container.registry.remember(MediaIds.SEARCH, state.value.results)
            container.player.play(station, MediaIds.SEARCH, state.value.results)
        }
    }

    fun favoriteTapped(station: Station) = container.favorites.toggle(station)

    fun loadMore() {
        val current = _state.value
        if (!current.canLoadMore || current.isLoading || current.isLoadingMore) return
        _state.update { it.copy(isLoadingMore = true) }
        searchJob = viewModelScope.launch {
            load(current.stationQuery.copy(offset = nextOffset), append = true)
        }
    }

    fun search() {
        lastSearchedQuery = _state.value.query
        searchJob?.cancel()
        nextOffset = 0
        _state.update { it.copy(isLoading = true, errorMessage = null) }
        searchJob = viewModelScope.launch { load(_state.value.stationQuery, append = false) }
    }

    private suspend fun load(query: StationQuery, append: Boolean) {
        try {
            val stations = container.api.search(query)
            container.registry.remember(stations)
            _state.update { state ->
                // Odstránime duplicity (rovnaký stream pod viacerými záznamami).
                val seenUrls = (if (append) state.results.map { it.url } else emptyList()).toMutableSet()
                val seenIds = (if (append) state.results.map { it.id } else emptyList()).toMutableSet()
                val fresh = stations.filter { seenUrls.add(it.url) && seenIds.add(it.id) }
                state.copy(
                    results = if (append) state.results + fresh else fresh,
                    isLoading = false,
                    isLoadingMore = false,
                    canLoadMore = stations.size == query.limit,
                    errorMessage = null,
                )
            }
            nextOffset = query.offset + query.limit
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            _state.update {
                it.copy(
                    isLoading = false,
                    isLoadingMore = false,
                    errorMessage = R.string.search_offline_message,
                )
            }
        }
    }
}

class SettingsViewModel(private val container: AppContainer) : ViewModel() {
    val favorites = container.favorites.favorites

    fun exportJson(): String = FavoritesBackup.encode(favorites.value)

    /** Vráti počet pridaných rádií, alebo `null` pri neplatnom súbore. */
    fun import(text: String): Int? = runCatching { FavoritesBackup.decode(text) }
        .getOrNull()
        ?.let(container.favorites::merge)

    fun addManual(name: String, url: String): Station? {
        val trimmedName = name.trim()
        val trimmedUrl = url.trim()
        if (trimmedName.isEmpty() || !isValidStreamUrl(trimmedUrl)) return null
        val station = Station(id = "manual-${java.util.UUID.randomUUID()}", name = trimmedName, url = trimmedUrl)
        container.favorites.merge(listOf(station))
        return station
    }

    companion object {
        fun isValidStreamUrl(text: String): Boolean {
            val uri = runCatching { java.net.URI(text.trim()) }.getOrNull() ?: return false
            return uri.scheme?.lowercase() in setOf("http", "https") && !uri.host.isNullOrBlank()
        }
    }
}
