package sk.tomasbudac.airwaves

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import sk.tomasbudac.airwaves.data.FavoritesBackup
import sk.tomasbudac.airwaves.data.Station
import sk.tomasbudac.airwaves.playback.MediaIds
import sk.tomasbudac.airwaves.ui.SettingsViewModel

class StationTest {
    @Test
    fun decodesWebBackupAndSkipsBrokenEntries() {
        val json = """
            {
              "app": "radio", "version": 1,
              "favorites": [
                { "id": "960e57c5", "name": "Rádio Expres", "url": "https://stream.example/expres.mp3",
                  "url2": "http://stream.example/expres.mp3", "favicon": "", "country": "Slovakia",
                  "countrycode": "SK", "tags": "pop", "codec": "MP3", "bitrate": 128, "hls": false, "homepage": "" },
                { "id": "manual-1712345678901", "name": "Moje rádio", "url": "https://example.com/stream", "url2": "" },
                { "id": "broken" }
              ]
            }
        """.trimIndent()

        val stations = FavoritesBackup.decode(json)

        assertEquals(listOf("960e57c5", "manual-1712345678901"), stations.map { it.id })
        assertEquals("http://stream.example/expres.mp3", stations[0].url2)
        assertTrue(stations[1].isManual)
        assertNull(stations[1].url2)
    }

    @Test
    fun decodesBareArrayAndRoundTrips() {
        val station = Station(id = "a", name = "A", url = "https://a.example/stream", bitrate = 64)
        val decoded = FavoritesBackup.decode(FavoritesBackup.encode(listOf(station)))
        assertEquals(listOf(station), decoded)
        assertEquals(1, FavoritesBackup.decode("""[{"id":"b","url":"https://b.example"}]""").size)
    }

    @Test
    fun streamCandidatesSkipDuplicates() {
        val station = Station(id = "a", url = "https://a.example", url2 = "https://a.example")
        assertEquals(listOf("https://a.example"), station.streamCandidates)
    }

    @Test
    fun initials() {
        assertEquals("RE", Station(id = "a", name = "Rádio Expres!", url = "x").initials)
        assertEquals("?", Station(id = "b", name = "***", url = "x").initials)
    }

    @Test
    fun mediaIdsRoundTrip() {
        val id = MediaIds.station(MediaIds.genre("top 40"), "uuid-1")
        assertEquals("genre:top 40" to "uuid-1", MediaIds.parse(id))
        assertEquals("top 40", MediaIds.genreTag("genre:top 40"))
        assertNull(MediaIds.parse(MediaIds.FAVORITES))
    }

    @Test
    fun manualUrlValidation() {
        assertTrue(SettingsViewModel.isValidStreamUrl("https://example.com/live"))
        assertFalse(SettingsViewModel.isValidStreamUrl("nie je adresa"))
        assertFalse(SettingsViewModel.isValidStreamUrl("ftp://example.com/live"))
    }
}
