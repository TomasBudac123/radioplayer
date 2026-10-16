@file:OptIn(UnstableApi::class)

package sk.radioplayer.app.playback

import android.content.ComponentName
import android.content.Context
import android.content.res.Resources
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch
import sk.radioplayer.app.R
import sk.radioplayer.app.data.Station

/** Čo práve hrá – rovnaký model ako na iOS. */
data class Playback(
    val station: Station? = null,
    val status: Status = Status.Idle,
    /** Názov skladby zo streamu (ICY metadáta), ak ho rádio posiela. */
    val trackTitle: String? = null,
    val canSkip: Boolean = false,
) {
    enum class Status { Idle, Loading, Playing, Paused, Failed }

    val isActive: Boolean get() = status == Status.Loading || status == Status.Playing

    fun isCurrent(station: Station): Boolean = this.station?.id == station.id && status != Status.Idle

    fun statusText(resources: Resources): String = when (status) {
        Status.Idle -> station?.countryName.orEmpty()
        Status.Loading -> resources.getString(R.string.player_connecting)
        Status.Playing -> listOf(resources.getString(R.string.player_live), station?.details.orEmpty())
            .filter { it.isNotBlank() }
            .joinToString(" · ")
        Status.Paused -> resources.getString(R.string.player_paused)
        Status.Failed -> resources.getString(R.string.player_failed)
    }
}

/**
 * Pripojenie UI k prehrávacej službe cez [MediaController]. Rovnaký session používa
 * aj Android Auto, takže stav je všade zhodný.
 */
class PlayerConnection(
    private val context: Context,
    private val scope: CoroutineScope,
) {
    private val _playback = MutableStateFlow(Playback())
    val playback: StateFlow<Playback> = _playback.asStateFlow()

    private var controller: MediaController? = null
    private var hasStarted = false
    private val pending = mutableListOf<(MediaController) -> Unit>()

    /** Pripojí sa k službe (volá sa pri štarte aktivity). */
    fun connect(lastStation: Station?, favoriteIds: () -> Set<String>) {
        if (controller != null || hasStarted) return
        hasStarted = true
        scope.launch(Dispatchers.Main) {
            val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
            val controller = runCatching { MediaController.Builder(context, token).buildAsync().await() }
                .getOrElse {
                    hasStarted = false
                    return@launch
                }
            this@PlayerConnection.controller = controller
            controller.addListener(object : Player.Listener {
                override fun onEvents(player: Player, events: Player.Events) = publish(player)
            })
            // Naposledy hrané rádio je pripravené v prehrávači (bez automatického spustenia).
            if (controller.mediaItemCount == 0 && lastStation != null) {
                val listId = if (lastStation.id in favoriteIds()) MediaIds.FAVORITES else MediaIds.SEARCH
                controller.setMediaItem(lastStation.toMediaItem(listId))
            }
            publish(controller)
            pending.forEach { it(controller) }
            pending.clear()
        }
    }

    /** Prehrá rádio; `queue` je zoznam pre prepínanie dopredu/dozadu. */
    fun play(station: Station, listId: String, queue: List<Station>) = withController { controller ->
        val index = queue.indexOfFirst { it.id == station.id }
        if (index >= 0) {
            controller.setMediaItems(queue.map { it.toMediaItem(listId) }, index, 0)
        } else {
            controller.setMediaItem(station.toMediaItem(listId))
        }
        controller.prepare()
        controller.play()
    }

    /** Hlasový príkaz (Google Asistent): služba nájde rádio rovnako ako v Android Auto. */
    fun playFromSearch(query: String) = withController { controller ->
        val request = MediaItem.RequestMetadata.Builder().setSearchQuery(query).build()
        controller.setMediaItem(MediaItem.Builder().setRequestMetadata(request).build())
        controller.prepare()
        controller.play()
    }

    fun togglePlayPause() = withController { controller ->
        if (controller.playWhenReady && controller.playerError == null) controller.pause() else controller.play()
    }

    fun next() = withController { it.seekToNextMediaItem() }

    fun previous() = withController { it.seekToPreviousMediaItem() }

    private fun withController(action: (MediaController) -> Unit) {
        controller?.let(action) ?: pending.add(action)
    }

    private fun publish(player: Player) {
        val item: MediaItem? = player.currentMediaItem
        val station = item?.station
        val status = when {
            station == null -> Playback.Status.Idle
            player.playerError != null -> Playback.Status.Failed
            player.isPlaying -> Playback.Status.Playing
            player.playWhenReady && player.playbackState == Player.STATE_BUFFERING -> Playback.Status.Loading
            player.playWhenReady && player.playbackState == Player.STATE_IDLE -> Playback.Status.Loading
            player.playbackState == Player.STATE_IDLE && _playback.value.station?.id != station.id -> Playback.Status.Idle
            player.playbackState == Player.STATE_IDLE && _playback.value.status == Playback.Status.Idle -> Playback.Status.Idle
            else -> Playback.Status.Paused
        }
        val title = item?.mediaMetadata?.title?.toString()
        _playback.value = Playback(
            station = station,
            status = status,
            trackTitle = title?.takeIf { status.isLive() && it != station?.name },
            canSkip = player.mediaItemCount > 1,
        )
    }

    private fun Playback.Status.isLive() = this == Playback.Status.Playing || this == Playback.Status.Loading
}
