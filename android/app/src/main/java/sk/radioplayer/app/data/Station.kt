package sk.radioplayer.app.data

import java.util.Locale
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonArray

/**
 * Internetové rádio. JSON kľúče sú zhodné s webovou a iOS aplikáciou,
 * aby sa dali prenášať zálohy obľúbených.
 */
@Serializable
data class Station(
    val id: String,
    val name: String = "",
    val url: String,
    val url2: String? = null,
    val favicon: String = "",
    val homepage: String = "",
    val country: String = "",
    val countrycode: String = "",
    val tags: String = "",
    val codec: String = "",
    val bitrate: Int = 0,
    val hls: Boolean = false,
) {
    /** Ručne pridané rádio nemá záznam v databáze Radio Browser. */
    val isManual: Boolean get() = id.startsWith("manual-")

    /** Adresy streamu v poradí, v akom ich skúšame prehrať. */
    val streamCandidates: List<String>
        get() = listOfNotNull(url, url2).filter { it.isNotBlank() }.distinct()

    /** Iniciály pre náhradné logo, napr. „Rádio Expres“ → „RE“. */
    val initials: String
        get() {
            val words = name.filter { it.isLetterOrDigit() || it == ' ' }.split(' ').filter { it.isNotBlank() }
            val letters = words.take(2).map { it.first() }.joinToString("")
            return letters.ifEmpty { "?" }.uppercase()
        }

    /** Názov krajiny v jazyku zariadenia. */
    val countryName: String
        get() {
            if (countrycode.length == 2) {
                val name = countryDisplayName(countrycode)
                if (name.isNotBlank() && name != countrycode) return name
            }
            return country
        }

    /** Krátky popis do zoznamov: „SK · pop, rock · 128 kbps“. */
    val subtitle: String
        get() = listOf(countrycode, tags, if (bitrate > 0) "$bitrate kbps" else "")
            .filter { it.isNotBlank() }
            .joinToString(" · ")

    /** Popis pod názvom v prehrávači. */
    val details: String
        get() = listOf(countryName, if (bitrate > 0) "$bitrate kbps" else "")
            .filter { it.isNotBlank() }
            .joinToString(" · ")

    /** Aktualizuje údaje, ktoré sa v databáze menia, a ponechá názov od používateľa. */
    fun refreshedFrom(fresh: Station): Station = copy(
        url = fresh.url,
        url2 = fresh.url2,
        favicon = fresh.favicon,
        homepage = fresh.homepage,
        bitrate = fresh.bitrate,
        codec = fresh.codec,
        hls = fresh.hls,
    )

    companion object {
        /** Názov krajiny podľa ISO kódu v jazyku zariadenia, napr. „SK“ → „Slovensko“ / „Slovakia“. */
        fun countryDisplayName(code: String): String =
            runCatching { Locale.Builder().setRegion(code).build().getDisplayCountry(Locale.getDefault()) }.getOrDefault("")
    }
}

/**
 * Kandidáti na logo v poradí: ikona z databázy (najprv https), ikona z webu rádia
 * a nakoniec favicon služba. Rovnaké poradie ako web a iOS.
 */
fun Station.iconCandidates(): List<String> = buildList {
    val icon = favicon.trim()
    when {
        icon.startsWith("https://") -> add(icon)
        icon.startsWith("http://") -> {
            add(icon.replaceFirst("http://", "https://"))
            add(icon)
        }
    }
    val host = runCatching { java.net.URI(homepage.ifBlank { url }.trim()).host }.getOrNull()
    if (!host.isNullOrBlank() && host.any { it.isLetter() }) {
        if (homepage.isNotBlank()) add("https://$host/apple-touch-icon.png")
        add("https://www.google.com/s2/favicons?domain=${host.removePrefix("www.")}&sz=256")
    }
}

/** Formát zálohy, kompatibilný s webovou a iOS aplikáciou. */
@Serializable
data class FavoritesBackup(
    val app: String = "radio",
    val version: Int = 1,
    val favorites: List<Station>,
) {
    companion object {
        /** Akceptuje `{ favorites: [...] }` aj holé pole; pokazené záznamy preskočí. */
        fun decode(text: String): List<Station> {
            val root = AppJson.parseToJsonElement(text)
            val items: JsonArray = when (root) {
                is JsonArray -> root
                is JsonObject -> root["favorites"]?.jsonArray ?: error("Missing favorites list")
                else -> error("Invalid backup")
            }
            return items.mapNotNull { element ->
                runCatching { AppJson.decodeFromJsonElement<Station>(element) }.getOrNull()
            }.map { it.copy(url2 = it.url2?.takeIf(String::isNotBlank)) }
        }

        fun encode(favorites: List<Station>): String =
            PrettyJson.encodeToString(serializer(), FavoritesBackup(favorites = favorites))
    }
}

val AppJson = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
    explicitNulls = false
}

private val PrettyJson = Json(AppJson) { prettyPrint = true }
