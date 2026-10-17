package sk.tomasbudac.airwaves.data

import java.text.Normalizer

/**
 * Porovnávanie hlasových príkazov („pusti Expres“, „jazz“) s rádiami a žánrami.
 * Rovnaké pravidlá ako `VoiceQuery` v iOS aplikácii.
 */
object VoiceQuery {
    /** Sila zhody pre presne zhodný názov. */
    const val EXACT = 3

    private val fillerWords = setOf(
        "radio", "radia", "radiu", "radiom", "station", "stanica", "stanicu", "sender", "emisora", "stazione",
        "stacja", "stacje", "allomas", "the",
    )

    /** Malé písmená bez diakritiky a bez slov ako „rádio“, ktoré asistent často pridá. */
    fun normalize(text: String): String {
        val folded = Normalizer.normalize(text.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "")
        val words = folded.split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }
        val meaningful = words.filterNot { it in fillerWords }
        // Rádio s názvom „Rádio FM“ nesmie skončiť ako prázdny reťazec.
        return (meaningful.ifEmpty { words }).joinToString(" ")
    }

    /** Najlepšie zodpovedajúce obľúbené rádio, ak je zhoda dostatočne istá. */
    fun bestFavorite(query: String, favorites: List<Station>): Station? = bestFavoriteMatch(query, favorites)?.first

    /** Obľúbené rádio aj sila zhody (3 = presná, 2 = čiastočná, 1 = slová). */
    fun bestFavoriteMatch(query: String, favorites: List<Station>): Pair<Station, Int>? {
        val needle = normalize(query)
        if (needle.isEmpty()) return null
        var best: Pair<Station, Int>? = null
        for (station in favorites) {
            val score = score(needle, normalize(station.name))
            if (score > (best?.second ?: 0)) best = station to score
        }
        return best
    }

    /** Žáner, ktorého názov (v jazyku zariadenia alebo anglický tag) zodpovedá príkazu. */
    fun genre(query: String, localizedName: (Genre) -> String): Genre? {
        val needle = normalize(query)
        if (needle.isEmpty()) return null
        return Genre.all.firstOrNull { normalize(localizedName(it)) == needle || normalize(it.tag) == needle }
    }

    /** 3 = presná zhoda, 2 = jeden názov obsahuje druhý, 1 = všetky slová príkazu sú v názve. */
    internal fun score(needle: String, name: String): Int {
        if (name.isEmpty()) return 0
        if (needle == name) return 3
        if (name.contains(needle) || needle.contains(name)) return 2
        val nameWords = name.split(" ").toSet()
        return if (needle.split(" ").all { it in nameWords }) 1 else 0
    }
}
