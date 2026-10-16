@file:OptIn(UnstableApi::class)

package sk.radioplayer.app.playback

import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.CommandButton
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.LibraryResult
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaSession
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionError
import androidx.media3.session.SessionResult
import com.google.common.collect.ImmutableList
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.guava.future
import kotlinx.coroutines.launch
import sk.radioplayer.app.MainActivity
import sk.radioplayer.app.R
import sk.radioplayer.app.RadioApplication

/**
 * Prehrávanie na pozadí + médiová knižnica pre Android Auto, notifikáciu,
 * zamknutú obrazovku a ovládanie zo slúchadiel.
 */
class PlaybackService : MediaLibraryService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var library: StationLibrary
    private lateinit var player: Player
    private var session: MediaLibrarySession? = null
    private var reportedStationId: String? = null
    /** Položky, pri ktorých sme už skúsili záložnú adresu streamu. */
    private val fallbackTried = mutableSetOf<String>()

    private val container get() = (application as RadioApplication).container

    override fun onCreate() {
        super.onCreate()
        library = StationLibrary(this, container.favorites, container.registry, container.api)
        player = LivePlayer(buildExoPlayer())
        player.addListener(PlayerListener())

        val sessionActivity = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        session = MediaLibrarySession.Builder(this, player, LibraryCallback())
            .setSessionActivity(sessionActivity)
            .build()
        setMediaNotificationProvider(
            DefaultMediaNotificationProvider.Builder(this).build().apply { setSmallIcon(R.drawable.ic_notification) },
        )

        // Zmena obľúbených z telefónu sa hneď prejaví v aute.
        scope.launch {
            container.favorites.favorites.drop(1).collect {
                session?.notifyChildrenChanged(MediaIds.FAVORITES, it.size, null)
                updateFavoriteButton()
            }
        }
        updateFavoriteButton()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaLibrarySession? = session

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!player.playWhenReady || player.mediaItemCount == 0) {
            pauseAllPlayersAndStopSelf()
        }
    }

    override fun onDestroy() {
        scope.cancel()
        session?.run {
            player.release()
            release()
        }
        session = null
        super.onDestroy()
    }

    private fun buildExoPlayer(): ExoPlayer {
        val http = DefaultHttpDataSource.Factory()
            .setUserAgent("Airwaves-Android/1.0")
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(10_000)
            .setReadTimeoutMs(15_000)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()
        return ExoPlayer.Builder(this)
            .setMediaSourceFactory(DefaultMediaSourceFactory(DefaultDataSource.Factory(this, http)))
            .setAudioAttributes(audioAttributes, true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
    }

    private fun updateFavoriteButton() {
        val station = player.currentMediaItem?.station
        val isFavorite = station != null && container.favorites.isFavorite(station.id)
        session?.setMediaButtonPreferences(listOf(favoriteButton(isFavorite, enabled = station != null)))
    }

    private fun favoriteButton(isFavorite: Boolean, enabled: Boolean = true): CommandButton =
        CommandButton.Builder(if (isFavorite) CommandButton.ICON_STAR_FILLED else CommandButton.ICON_STAR_UNFILLED)
            .setDisplayName(getString(if (isFavorite) R.string.favorites_remove else R.string.favorites_add))
            .setSessionCommand(TOGGLE_FAVORITE)
            .setCustomIconResId(if (isFavorite) R.drawable.ic_star else R.drawable.ic_star_outline)
            .setSlots(CommandButton.SLOT_OVERFLOW)
            .setEnabled(enabled)
            .build()

    private inner class PlayerListener : Player.Listener {
        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            // Výmena adresy (záložný stream) alebo metadát nie je nové rádio.
            if (reason == Player.MEDIA_ITEM_TRANSITION_REASON_PLAYLIST_CHANGED &&
                mediaItem?.station?.id == reportedStationId
            ) {
                return
            }
            fallbackTried.clear()
            val station = mediaItem?.station ?: return
            container.favorites.setLastStation(station)
            if (reportedStationId != station.id) {
                reportedStationId = station.id
                // Nahlásime klik – pomáha rebríčku popularity v Radio Browser.
                if (!station.isManual) scope.launch { container.api.reportClick(station.id) }
            }
            updateFavoriteButton()
        }

        override fun onPlayerError(error: PlaybackException) {
            val index = player.currentMediaItemIndex
            val item = player.currentMediaItem ?: return
            val station = item.station ?: return
            val current = item.localConfiguration?.uri?.toString()
            val next = station.streamCandidates.firstOrNull { it != current && it !in fallbackTried }
            if (next == null) return
            current?.let(fallbackTried::add)
            fallbackTried.add(next)
            player.replaceMediaItem(index, item.buildUpon().setUri(next).build())
            player.prepare()
            player.play()
        }

        override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
            // ICY metadáta: názov skladby zobrazíme ako titul, rádio ako interpreta
            // (rovnako v notifikácii, na zamknutej obrazovke aj v aute).
            val item = player.currentMediaItem ?: return
            val station = item.station ?: return
            val track = mediaMetadata.title?.toString()?.trim()?.trim('-', '–', ' ')
                ?.takeIf { it.isNotEmpty() && it != station.name && it != item.mediaMetadata.title?.toString() }
                ?: return
            val updated = item.mediaMetadata.buildUpon()
                .setTitle(track)
                .setArtist(station.name)
                .build()
            player.replaceMediaItem(player.currentMediaItemIndex, item.buildUpon().setMediaMetadata(updated).build())
        }
    }

    private inner class LibraryCallback : MediaLibrarySession.Callback {
        override fun onConnect(session: MediaSession, controller: MediaSession.ControllerInfo): MediaSession.ConnectionResult {
            val station = player.currentMediaItem?.station
            val isFavorite = station != null && container.favorites.isFavorite(station.id)
            return MediaSession.ConnectionResult.AcceptedResultBuilder(session, controller)
                .setAvailableSessionCommands(
                    MediaSession.ConnectionResult.DEFAULT_SESSION_AND_LIBRARY_COMMANDS.buildUpon()
                        .add(TOGGLE_FAVORITE)
                        .build(),
                )
                .setMediaButtonPreferences(listOf(favoriteButton(isFavorite, enabled = station != null)))
                .build()
        }

        override fun onCustomCommand(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
            customCommand: SessionCommand,
            args: Bundle,
        ): ListenableFuture<SessionResult> {
            if (customCommand != TOGGLE_FAVORITE) {
                return Futures.immediateFuture(SessionResult(SessionError.ERROR_NOT_SUPPORTED))
            }
            val station = player.currentMediaItem?.station
                ?: return Futures.immediateFuture(SessionResult(SessionError.ERROR_INVALID_STATE))
            container.favorites.toggle(station)
            updateFavoriteButton()
            return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
        }

        override fun onGetLibraryRoot(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            params: LibraryParams?,
        ): ListenableFuture<LibraryResult<MediaItem>> =
            Futures.immediateFuture(LibraryResult.ofItem(library.root(), params))

        override fun onGetItem(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            mediaId: String,
        ): ListenableFuture<LibraryResult<MediaItem>> {
            val item = library.item(mediaId)
            return Futures.immediateFuture(
                item?.let { LibraryResult.ofItem(it, null) } ?: LibraryResult.ofError(SessionError.ERROR_BAD_VALUE),
            )
        }

        override fun onGetChildren(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            parentId: String,
            page: Int,
            pageSize: Int,
            params: LibraryParams?,
        ): ListenableFuture<LibraryResult<ImmutableList<MediaItem>>> = scope.future {
            val children = library.children(parentId)
            val from = (page * pageSize).coerceAtMost(children.size)
            val to = (from + pageSize).coerceAtMost(children.size)
            LibraryResult.ofItemList(children.subList(from, to), params)
        }

        override fun onSearch(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            query: String,
            params: LibraryParams?,
        ): ListenableFuture<LibraryResult<Void>> {
            scope.launch {
                val count = library.search(query).size
                session.notifySearchResultChanged(browser, query, count, params)
            }
            return Futures.immediateFuture(LibraryResult.ofVoid())
        }

        override fun onGetSearchResult(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            query: String,
            page: Int,
            pageSize: Int,
            params: LibraryParams?,
        ): ListenableFuture<LibraryResult<ImmutableList<MediaItem>>> = scope.future {
            val results = library.search(query)
            val from = (page * pageSize).coerceAtMost(results.size)
            val to = (from + pageSize).coerceAtMost(results.size)
            LibraryResult.ofItemList(results.subList(from, to), params)
        }

        override fun onAddMediaItems(
            mediaSession: MediaSession,
            controller: MediaSession.ControllerInfo,
            mediaItems: List<MediaItem>,
        ): ListenableFuture<List<MediaItem>> = scope.future {
            mediaItems.mapNotNull { library.resolve(it) }
        }

        override fun onSetMediaItems(
            mediaSession: MediaSession,
            controller: MediaSession.ControllerInfo,
            mediaItems: List<MediaItem>,
            startIndex: Int,
            startPositionMs: Long,
        ): ListenableFuture<MediaSession.MediaItemsWithStartPosition> = scope.future {
            val single = mediaItems.singleOrNull()
            val searchQuery = single?.requestMetadata?.searchQuery
            val expanded = when {
                // Hlasový príkaz „pusti … v Airwaves“.
                single != null && single.mediaId.isEmpty() && searchQuery != null -> library.playFromSearch(searchQuery)
                // Jedno rádio z Android Auto – doplníme zoznam, z ktorého pochádza.
                single != null -> library.expand(single)
                else -> null
            }
            if (expanded != null) {
                MediaSession.MediaItemsWithStartPosition(expanded.first, expanded.second, C.TIME_UNSET)
            } else {
                val resolved = mediaItems.mapNotNull { library.resolve(it) }
                MediaSession.MediaItemsWithStartPosition(
                    resolved,
                    startIndex.coerceIn(0, (resolved.size - 1).coerceAtLeast(0)),
                    C.TIME_UNSET,
                )
            }
        }

        override fun onPlaybackResumption(
            mediaSession: MediaSession,
            controller: MediaSession.ControllerInfo,
            isForPlayback: Boolean,
        ): ListenableFuture<MediaSession.MediaItemsWithStartPosition> = scope.future {
            val last = library.lastStationItem() ?: throw UnsupportedOperationException("Nothing played yet")
            library.expand(last)?.let { (items, index) ->
                MediaSession.MediaItemsWithStartPosition(items, index, C.TIME_UNSET)
            } ?: MediaSession.MediaItemsWithStartPosition(listOf(last), 0, C.TIME_UNSET)
        }
    }

    companion object {
        val TOGGLE_FAVORITE = SessionCommand("sk.radioplayer.TOGGLE_FAVORITE", Bundle.EMPTY)
    }
}

/**
 * Živé rádio: pauza zastaví sťahovanie streamu a „prehrať“ sa pripojí nanovo,
 * aby sme po pauze neprehrávali starý záznam z vyrovnávacej pamäte.
 */
private class LivePlayer(player: ExoPlayer) : ForwardingPlayer(player) {
    override fun pause() {
        super.pause()
        super.stop()
    }

    override fun play() {
        if (playbackState == Player.STATE_IDLE) {
            if (playerError != null) seekToDefaultPosition()
            prepare()
        }
        super.play()
    }
}
