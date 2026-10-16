package sk.radioplayer.app.data

import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.builtins.ListSerializer

/**
 * Obľúbené rádiá (v poradí od používateľa) a naposledy hrané rádio.
 * Zdieľa ich UI aj prehrávacia služba (Android Auto) v rámci jedného procesu.
 */
class FavoritesRepository(
    directory: File,
    private val scope: CoroutineScope,
) {
    private val favoritesFile = File(directory, "favorites.json")
    private val lastStationFile = File(directory, "last-station.json")
    private val writeMutex = Mutex()

    private val _favorites = MutableStateFlow(readFavorites())
    val favorites: StateFlow<List<Station>> = _favorites.asStateFlow()

    var lastStation: Station? = readLastStation()
        private set

    fun isFavorite(id: String): Boolean = _favorites.value.any { it.id == id }

    fun toggle(station: Station) = mutate { list ->
        if (list.any { it.id == station.id }) list.filterNot { it.id == station.id } else list + station
    }

    fun remove(id: String) = mutate { list -> list.filterNot { it.id == id } }

    fun move(from: Int, to: Int) = mutate { list ->
        if (from !in list.indices || to !in list.indices) return@mutate list
        list.toMutableList().apply { add(to, removeAt(from)) }
    }

    /** Pridá stanice, ktoré ešte nie sú v obľúbených, a vráti ich počet. */
    fun merge(stations: List<Station>): Int {
        var added = 0
        mutate { list ->
            val ids = list.map { it.id }.toMutableSet()
            val fresh = stations.filter { ids.add(it.id) }
            added = fresh.size
            list + fresh
        }
        return added
    }

    /** Obnoví adresy a ikony z databázy, ponechá názvy a poradie. */
    fun refresh(fresh: List<Station>) = mutate { list ->
        val byId = fresh.associateBy { it.id }
        list.map { station -> byId[station.id]?.let(station::refreshedFrom) ?: station }
    }

    fun setLastStation(station: Station) {
        lastStation = station
        scope.launch(Dispatchers.IO) {
            writeMutex.withLock {
                lastStationFile.writeText(AppJson.encodeToString(Station.serializer(), station))
            }
        }
    }

    private fun mutate(transform: (List<Station>) -> List<Station>) {
        _favorites.update(transform)
        val snapshot = _favorites.value
        scope.launch(Dispatchers.IO) {
            writeMutex.withLock {
                val temp = File(favoritesFile.parentFile, "${favoritesFile.name}.tmp")
                temp.writeText(AppJson.encodeToString(ListSerializer(Station.serializer()), snapshot))
                temp.renameTo(favoritesFile)
            }
        }
    }

    private fun readFavorites(): List<Station> = runCatching {
        FavoritesBackup.decode(favoritesFile.readText())
    }.getOrDefault(emptyList())

    private fun readLastStation(): Station? = runCatching {
        AppJson.decodeFromString(Station.serializer(), lastStationFile.readText())
    }.getOrNull()
}

/**
 * Pamäť staníc, ktoré sa práve zobrazujú (hľadanie, populárne, žánre). Prehrávacia služba
 * podľa nej preloží ID z Android Auto alebo z ovládača späť na adresu streamu.
 */
class StationRegistry {
    private val stations = ConcurrentHashMap<String, Station>()
    private val lists = ConcurrentHashMap<String, List<Station>>()

    fun remember(stations: List<Station>) {
        stations.forEach { this.stations[it.id] = it }
    }

    fun remember(listId: String, stations: List<Station>) {
        remember(stations)
        lists[listId] = stations
    }

    operator fun get(id: String): Station? = stations[id]

    fun list(listId: String): List<Station>? = lists[listId]
}
