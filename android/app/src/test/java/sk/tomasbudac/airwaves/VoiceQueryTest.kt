package sk.tomasbudac.airwaves

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import sk.tomasbudac.airwaves.data.Station
import sk.tomasbudac.airwaves.data.VoiceQuery

/** Rovnaké prípady ako VoiceQueryTests v iOS aplikácii. */
class VoiceQueryTest {
    private val favorites = listOf(
        Station(id = "expres", name = "Rádio Expres", url = "https://a.example"),
        Station(id = "fm", name = "Rádio FM", url = "https://b.example"),
        Station(id = "bbc", name = "BBC Radio 1", url = "https://c.example"),
    )

    @Test
    fun normalizeFoldsDiacriticsAndFillerWords() {
        assertEquals("expres", VoiceQuery.normalize("Rádio Expres!"))
        assertEquals("fm", VoiceQuery.normalize("Rádio FM"))
        assertEquals("bbc 1", VoiceQuery.normalize("  BBC   Radio 1 "))
    }

    @Test
    fun matchesFavoritesBySpokenName() {
        assertEquals("expres", VoiceQuery.bestFavorite("expres", favorites)?.id)
        assertEquals("expres", VoiceQuery.bestFavorite("radio expres", favorites)?.id)
        assertEquals("fm", VoiceQuery.bestFavorite("Rádio FM", favorites)?.id)
        assertNull(VoiceQuery.bestFavorite("BBC Radio One", favorites))
        assertEquals("bbc", VoiceQuery.bestFavorite("bbc", favorites)?.id)
        assertNull(VoiceQuery.bestFavorite("Jazz", favorites))
    }

    @Test
    fun matchesGenresByTagOrLocalizedName() {
        val names = mapOf("jazz" to "Jazz", "classic rock" to "Classic rock", "news" to "Správy")
        val localized: (sk.tomasbudac.airwaves.data.Genre) -> String = { names[it.tag] ?: it.tag }
        assertEquals("jazz", VoiceQuery.genre("jazz", localized)?.tag)
        assertEquals("classic rock", VoiceQuery.genre("Classic Rock", localized)?.tag)
        assertEquals("news", VoiceQuery.genre("správy", localized)?.tag)
        assertNull(VoiceQuery.genre("Expres", localized))
    }
}
