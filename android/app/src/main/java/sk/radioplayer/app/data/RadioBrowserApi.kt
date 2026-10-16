package sk.radioplayer.app.data

import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request

/** Verejná databáza ~60 000 rádií z celého sveta – https://www.radio-browser.info */
interface RadioBrowser {
    suspend fun search(query: StationQuery): List<Station>
    suspend fun stations(ids: List<String>): List<Station>
    suspend fun countries(): List<Country>
    suspend fun reportClick(stationId: String)
}

/**
 * Radio Browser beží na viacerých zrkadlách – ak jedno neodpovedá, skúsime ďalšie
 * a úspešné si zapamätáme ako prvé.
 */
class RadioBrowserApi(
    baseClient: OkHttpClient,
    /** Názov pre rádiá bez mena, v jazyku zariadenia. */
    private val untitled: () -> String,
) : RadioBrowser {
    private val client = baseClient.newBuilder()
        .callTimeout(10, TimeUnit.SECONDS)
        .addInterceptor { chain ->
            chain.proceed(chain.request().newBuilder().header("User-Agent", "RadioApp-Android/1.0").build())
        }
        .build()
    private val mutex = Mutex()
    private var servers: List<String>? = null

    override suspend fun search(query: StationQuery): List<Station> {
        val params = buildMap {
            put("hidebroken", "true")
            put("order", "clickcount")
            put("reverse", "true")
            put("limit", query.limit.toString())
            put("offset", query.offset.toString())
            query.name.trim().takeIf { it.isNotEmpty() }?.let { put("name", it) }
            query.tag?.let { put("tag", it) }
            query.countryCode?.let { put("countrycode", it) }
        }
        return decodeStations(get("stations/search", params))
    }

    override suspend fun stations(ids: List<String>): List<Station> {
        if (ids.isEmpty()) return emptyList()
        return decodeStations(get("stations/byuuid", mapOf("uuids" to ids.joinToString(","))))
    }

    override suspend fun countries(): List<Country> {
        val raw = AppJson.decodeFromString(ListSerializer(RawCountry.serializer()), get("countries", mapOf("hidebroken" to "true")))
        // Tá istá krajina môže byť v dátach viackrát – zlúčime.
        val merged = linkedMapOf<String, Country>()
        for (country in raw) {
            if (country.stationcount <= 0 || country.iso_3166_1.length != 2) continue
            val code = country.iso_3166_1.uppercase()
            val existing = merged[code]
            merged[code] = if (existing != null) {
                existing.copy(stationCount = existing.stationCount + country.stationcount)
            } else {
                val name = Station.countryDisplayName(code).ifBlank { country.name }
                Country(code, name, country.stationcount)
            }
        }
        val collator = java.text.Collator.getInstance()
        return merged.values.sortedWith { a, b -> collator.compare(a.name, b.name) }
    }

    override suspend fun reportClick(stationId: String) {
        runCatching { get("url/$stationId") }
    }

    private suspend fun get(path: String, params: Map<String, String> = emptyMap()): String =
        withContext(Dispatchers.IO) {
            val list = resolveServers()
            var lastError: Exception = IOException("No Radio Browser server responded")
            for ((index, server) in list.withIndex()) {
                val url = HttpUrl.Builder()
                    .scheme("https")
                    .host(server)
                    .addPathSegments("json/$path")
                    .apply { params.toSortedMap().forEach { (key, value) -> addQueryParameter(key, value) } }
                    .build()
                try {
                    client.newCall(Request.Builder().url(url).build()).execute().use { response ->
                        if (!response.isSuccessful) throw IOException("HTTP ${response.code}")
                        val body = response.body.string()
                        if (index > 0) mutex.withLock { servers = listOf(server) + list.filter { it != server } }
                        return@withContext body
                    }
                } catch (error: IOException) {
                    lastError = error
                }
            }
            throw lastError
        }

    private suspend fun resolveServers(): List<String> = mutex.withLock {
        servers ?: run {
            val resolved = runCatching {
                val request = Request.Builder().url("https://all.api.radio-browser.info/json/servers").build()
                client.newCall(request).execute().use { response ->
                    AppJson.decodeFromString(ListSerializer(RawServer.serializer()), response.body.string())
                        .map { it.name }
                        .distinct()
                }
            }.getOrNull()?.takeIf { it.isNotEmpty() } ?: FALLBACK_SERVERS
            resolved.shuffled().also { servers = it }
        }
    }

    private fun decodeStations(text: String): List<Station> =
        AppJson.decodeFromString(ListSerializer(RawStation.serializer()), text).mapNotNull { it.toStation(untitled) }

    private companion object {
        val FALLBACK_SERVERS = listOf("de1.api.radio-browser.info", "de2.api.radio-browser.info", "fi1.api.radio-browser.info")
    }
}

@Serializable
private data class RawServer(val name: String)

@Suppress("PropertyName")
@Serializable
private data class RawCountry(val name: String = "", val iso_3166_1: String = "", val stationcount: Int = 0)

@Suppress("PropertyName")
@Serializable
private data class RawStation(
    val stationuuid: String,
    val name: String? = null,
    val url: String? = null,
    val url_resolved: String? = null,
    val favicon: String? = null,
    val homepage: String? = null,
    val country: String? = null,
    val countrycode: String? = null,
    val tags: String? = null,
    val codec: String? = null,
    val bitrate: Int? = null,
    val hls: Int? = null,
) {
    fun toStation(untitled: () -> String): Station? {
        val resolved = url_resolved?.takeIf { it.isNotBlank() } ?: url?.takeIf { it.isNotBlank() } ?: return null
        return Station(
            id = stationuuid,
            name = name?.trim()?.takeIf { it.isNotEmpty() } ?: untitled(),
            url = resolved,
            url2 = url?.takeIf { it.isNotBlank() && it != resolved },
            favicon = favicon.orEmpty(),
            homepage = homepage.orEmpty(),
            country = country.orEmpty(),
            countrycode = countrycode.orEmpty(),
            tags = tags.orEmpty().split(',').filter { it.isNotBlank() }.take(3).joinToString(", "),
            codec = codec.orEmpty(),
            bitrate = bitrate ?: 0,
            hls = hls == 1,
        )
    }
}
