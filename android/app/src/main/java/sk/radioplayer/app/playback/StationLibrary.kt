@file:OptIn(UnstableApi::class)

package sk.radioplayer.app.playback

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaConstants
import java.util.Locale
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import sk.radioplayer.app.R
import sk.radioplayer.app.data.FavoritesRepository
import sk.radioplayer.app.data.Genre
import sk.radioplayer.app.data.RadioBrowser
import sk.radioplayer.app.data.Station
import sk.radioplayer.app.data.StationQuery
import sk.radioplayer.app.data.StationRegistry
import sk.radioplayer.app.data.VoiceQuery

/**
 * Strom knižnice pre Android Auto:
 * ```
 * root
 * ├── Obľúbené        (mriežka log)
 * ├── Populárne       (vaša krajina + celý svet)
 * └── Žánre
 *     └── <žáner>     (rádiá)
 * ```
 */
class StationLibrary(
    private val context: Context,
    private val favorites: FavoritesRepository,
    private val registry: StationRegistry,
    private val api: RadioBrowser,
) {
    fun root(): MediaItem = browsableItem(context, MediaIds.ROOT, context.getString(R.string.app_name))

    suspend fun children(parentId: String): List<MediaItem> = when (parentId) {
        MediaIds.ROOT -> listOf(
            browsableItem(
                context, MediaIds.FAVORITES, context.getString(R.string.tab_favorites), R.drawable.ic_star,
                childrenStyle = MediaConstants.EXTRAS_VALUE_CONTENT_STYLE_GRID_ITEM,
            ),
            browsableItem(context, MediaIds.POPULAR, context.getString(R.string.tab_popular), R.drawable.ic_bar_chart),
            browsableItem(context, MediaIds.GENRES, context.getString(R.string.tab_genres), R.drawable.ic_music_note),
        )
        MediaIds.FAVORITES -> favorites.favorites.value.map { it.toMediaItem(MediaIds.FAVORITES) }
        MediaIds.POPULAR -> popular()
        MediaIds.GENRES -> Genre.all.map { browsableItem(context, MediaIds.genre(it.tag), context.getString(it.nameRes), R.drawable.ic_music_note) }
        else -> MediaIds.genreTag(parentId)?.let { genreStations(it, parentId) } ?: emptyList()
    }

    fun item(mediaId: String): MediaItem? {
        val (listId, stationId) = MediaIds.parse(mediaId) ?: return null
        return find(stationId)?.toMediaItem(listId)
    }

    suspend fun search(query: String): List<MediaItem> {
        val stations = searchStations(query)
        registry.remember(MediaIds.SEARCH, stations)
        return stations.map { it.toMediaItem(MediaIds.SEARCH) }
    }

    /** Doplní adresu streamu k položke, ktorá prišla z Android Auto alebo z ovládača. */
    suspend fun resolve(item: MediaItem): MediaItem? {
        item.station?.let { station ->
            val listId = MediaIds.parse(item.mediaId)?.first ?: MediaIds.SEARCH
            return station.toMediaItem(listId)
        }
        val (listId, stationId) = MediaIds.parse(item.mediaId) ?: return null
        val station = find(stationId) ?: runCatching { api.stations(listOf(stationId)).firstOrNull() }.getOrNull()
        return station?.toMediaItem(listId)
    }

    /**
     * Ku zvolenému rádiu pridá celý zoznam, z ktorého pochádza, aby fungovalo
     * prepínanie dopredu/dozadu (v aute, na zamknutej obrazovke, na slúchadlách).
     */
    suspend fun expand(item: MediaItem): Pair<List<MediaItem>, Int>? {
        val resolved = resolve(item) ?: return null
        val (listId, stationId) = MediaIds.parse(resolved.mediaId) ?: return listOf(resolved) to 0
        val list = when (listId) {
            MediaIds.FAVORITES -> favorites.favorites.value
            else -> registry.list(listId)
        }
        val index = list?.indexOfFirst { it.id == stationId } ?: -1
        if (list == null || index < 0) return listOf(resolved) to 0
        return list.map { if (it.id == stationId) resolved else it.toMediaItem(listId) } to index
    }

    /** Hlasové „pusti … v Airwaves“: obľúbené, potom žáner, potom databáza (rovnako ako Siri na iOS). */
    suspend fun playFromSearch(query: String): Pair<List<MediaItem>, Int>? {
        if (VoiceQuery.normalize(query).isEmpty()) {
            // „Pusti Rádio“ bez názvu – pokračuj tam, kde si skončil.
            val last = favorites.lastStation ?: favorites.favorites.value.firstOrNull() ?: return null
            return expand(last.toMediaItem(if (favorites.isFavorite(last.id)) MediaIds.FAVORITES else MediaIds.SEARCH))
        }
        // Presný názov obľúbeného rádia má prednosť, „jazz“ je však žáner, nie „101 Smooth Jazz“.
        val favorite = VoiceQuery.bestFavoriteMatch(query, favorites.favorites.value)
        if (favorite != null && favorite.second == VoiceQuery.EXACT) {
            return expand(favorite.first.toMediaItem(MediaIds.FAVORITES))
        }
        val genre = VoiceQuery.genre(query) { context.getString(it.nameRes) }
        if (genre == null && favorite != null) {
            return expand(favorite.first.toMediaItem(MediaIds.FAVORITES))
        }
        genre?.let { genre ->
            val listId = MediaIds.genre(genre.tag)
            val stations = runCatching { api.search(StationQuery(tag = genre.tag, limit = 30)) }.getOrDefault(emptyList())
            if (stations.isEmpty()) return null
            registry.remember(listId, stations)
            return stations.map { it.toMediaItem(listId) } to 0
        }
        val results = searchStations(query.trim())
        if (results.isEmpty()) return null
        registry.remember(MediaIds.SEARCH, results)
        return results.map { it.toMediaItem(MediaIds.SEARCH) } to 0
    }

    fun lastStationItem(): MediaItem? {
        val last = favorites.lastStation ?: return null
        val listId = if (favorites.isFavorite(last.id)) MediaIds.FAVORITES else MediaIds.SEARCH
        registry.remember(listOf(last))
        return last.toMediaItem(listId)
    }

    private fun find(stationId: String): Station? =
        favorites.favorites.value.firstOrNull { it.id == stationId }
            ?: registry[stationId]
            ?: favorites.lastStation?.takeIf { it.id == stationId }

    private suspend fun popular(): List<MediaItem> = coroutineScope {
        val region = Locale.getDefault().country.takeIf { it.length == 2 }
        val local = async {
            region?.let { runCatching { api.search(StationQuery(countryCode = it, limit = 25)) }.getOrNull() }.orEmpty()
        }
        val world = async { runCatching { api.search(StationQuery(limit = 25)) }.getOrDefault(emptyList()) }
        val localStations = local.await()
        val localIds = localStations.map { it.id }.toSet()
        val worldStations = world.await().filterNot { it.id in localIds }
        registry.remember(MediaIds.POPULAR, localStations + worldStations)
        val countryName = region?.let(Station::countryDisplayName)?.ifBlank { null } ?: context.getString(R.string.car_your_country)
        localStations.map { it.toMediaItem(MediaIds.POPULAR, groupTitle = countryName) } +
            worldStations.map { it.toMediaItem(MediaIds.POPULAR, groupTitle = context.getString(R.string.search_whole_world)) }
    }

    private suspend fun genreStations(tag: String, listId: String): List<MediaItem> {
        val stations = runCatching { api.search(StationQuery(tag = tag, limit = 50)) }.getOrDefault(emptyList())
        registry.remember(listId, stations)
        return stations.map { it.toMediaItem(listId) }
    }

    private suspend fun searchStations(query: String): List<Station> =
        runCatching { api.search(StationQuery(name = query, limit = 30)) }.getOrDefault(emptyList())
}
