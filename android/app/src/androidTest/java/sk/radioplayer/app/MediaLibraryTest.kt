package sk.radioplayer.app

import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.session.MediaBrowser
import androidx.media3.session.SessionToken
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import sk.radioplayer.app.playback.MediaIds
import sk.radioplayer.app.playback.PlaybackService

/**
 * Pripojí sa k prehrávacej službe presne ako Android Auto (MediaBrowser) a prejde
 * strom knižnice, prehrávanie z neho a tlačidlo obľúbených.
 */
@RunWith(AndroidJUnit4::class)
class MediaLibraryTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()

    /**
     * Android 15+ dá audio focus len appke v popredí alebo s bežiacou foreground službou.
     * V aute je v popredí Android Auto / médiové centrum, v teste to zastúpi otvorená appka.
     */
    @get:Rule
    val activity = ActivityScenarioRule(MainActivity::class.java)

    @Test
    fun browseAndPlayLikeAndroidAuto() = runBlocking {
        withContext(Dispatchers.Main) {
            val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
            val browser = MediaBrowser.Builder(context, token).buildAsync().await()
            try {
                val root = browser.getLibraryRoot(null).await().value!!
                val tabs = browser.getChildren(root.mediaId, 0, 10, null).await().value!!
                log("root", tabs)
                assertEquals(listOf(MediaIds.FAVORITES, MediaIds.POPULAR, MediaIds.GENRES), tabs.map { it.mediaId })
                assertTrue(tabs.all { it.mediaMetadata.isBrowsable == true })

                val genres = browser.getChildren(MediaIds.GENRES, 0, 100, null).await().value!!
                log("genres", genres.take(5))
                assertTrue(genres.size >= 40)

                val jazz = browser.getChildren(MediaIds.genre("jazz"), 0, 10, null).await().value!!
                log("genre:jazz", jazz)
                assertTrue(jazz.isNotEmpty())

                val popular = browser.getChildren(MediaIds.POPULAR, 0, 100, null).await().value!!
                log("popular", popular.take(5))
                assertTrue(popular.isNotEmpty())
                assertTrue(popular.all { it.mediaMetadata.isPlayable == true })

                // Android Auto pošle len ID položky – služba doplní stream aj celý zoznam.
                browser.setMediaItem(MediaItem.Builder().setMediaId(popular[1].mediaId).build())
                browser.prepare()
                browser.play()
                val started = withTimeoutOrNull(60_000) {
                    while (!browser.isPlaying) delay(250)
                }
                if (started == null) {
                    Log.e(
                        TAG,
                        "not playing: state=${browser.playbackState} pwr=${browser.playWhenReady} " +
                            "error=${browser.playerError?.errorCodeName} item=${browser.currentMediaItem?.mediaId} " +
                            "count=${browser.mediaItemCount}",
                    )
                    error("Stanica sa nespustila")
                }
                Log.i(TAG, "playing ${browser.currentMediaItem?.mediaMetadata?.title} " +
                    "(${browser.currentMediaItemIndex + 1}/${browser.mediaItemCount})")
                assertEquals(popular.size, browser.mediaItemCount)
                assertEquals(1, browser.currentMediaItemIndex)

                browser.seekToNextMediaItem()
                assertEquals(2, browser.currentMediaItemIndex)

                // Hviezdička v aute pridá rádio do obľúbených.
                val favoriteButton = browser.mediaButtonPreferences.first { it.sessionCommand != null }
                Log.i(TAG, "button: ${favoriteButton.displayName}")
                val before = browser.getChildren(MediaIds.FAVORITES, 0, 100, null).await().value!!.size
                browser.sendCustomCommand(favoriteButton.sessionCommand!!, Bundle.EMPTY).await()
                val favorites = browser.getChildren(MediaIds.FAVORITES, 0, 100, null).await().value!!
                log("favorites", favorites)
                assertTrue(favorites.size != before)
                // Vrátime späť.
                browser.sendCustomCommand(favoriteButton.sessionCommand!!, Bundle.EMPTY).await()

                val search = browser.search("jazz", null).await()
                Log.i(TAG, "search result code ${search.resultCode}")

                // Pauza živého rádia zastaví sťahovanie streamu (stav sa prenesie asynchrónne).
                browser.pause()
                withTimeout(5_000) {
                    while (browser.playbackState != Player.STATE_IDLE) delay(100)
                }
            } finally {
                browser.release()
            }
        }
    }

    /** „Hey Google, pusti jazz v Rádiu“ – Asistent pošle len hľadaný výraz. */
    @Test
    fun voiceSearchPlaysGenreAndStation() = runBlocking {
        withContext(Dispatchers.Main) {
            val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
            val browser = MediaBrowser.Builder(context, token).buildAsync().await()
            try {
                for (query in listOf("jazz", "BBC World Service")) {
                    val request = MediaItem.RequestMetadata.Builder().setSearchQuery(query).build()
                    browser.setMediaItem(MediaItem.Builder().setRequestMetadata(request).build())
                    browser.prepare()
                    browser.play()
                    withTimeout(30_000) {
                        while (!browser.isPlaying) delay(250)
                    }
                    val current = browser.currentMediaItem!!
                    Log.i(TAG, "voice '$query' → ${current.mediaMetadata.title} [${current.mediaId}] (${browser.mediaItemCount})")
                    assertTrue(browser.mediaItemCount > 0)
                    if (query == "jazz") assertTrue(current.mediaId.startsWith(MediaIds.genre("jazz")))
                    browser.pause()
                }
            } finally {
                browser.release()
            }
        }
    }

    private fun log(title: String, items: List<MediaItem>) {
        Log.i(TAG, "$title: " + items.joinToString { "${it.mediaMetadata.title} [${it.mediaId}]" })
    }

    private companion object {
        const val TAG = "MediaLibraryTest"
    }
}
