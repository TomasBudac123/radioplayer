@file:OptIn(UnstableApi::class)

package sk.radioplayer.app.playback

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.os.Bundle
import androidx.annotation.DrawableRes
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaConstants
import sk.radioplayer.app.data.AppJson
import sk.radioplayer.app.data.Station

/**
 * ID položiek v knižnici (Android Auto, ovládač v appke).
 * Prehrateľná položka má tvar `<zoznam>|<id rádia>`, aby sme vedeli, v ktorom zozname
 * sa má prepínať dopredu/dozadu.
 */
object MediaIds {
    const val ROOT = "root"
    const val FAVORITES = "favorites"
    const val POPULAR = "popular"
    const val GENRES = "genres"
    const val SEARCH = "search"
    private const val GENRE_PREFIX = "genre:"
    private const val SEPARATOR = "|"

    fun genre(tag: String) = "$GENRE_PREFIX$tag"
    fun genreTag(mediaId: String): String? = mediaId.removePrefix(GENRE_PREFIX).takeIf { mediaId.startsWith(GENRE_PREFIX) }

    fun station(listId: String, stationId: String) = "$listId$SEPARATOR$stationId"

    /** Rozloží ID prehrateľnej položky na (zoznam, id rádia). */
    fun parse(mediaId: String): Pair<String, String>? {
        val index = mediaId.lastIndexOf(SEPARATOR)
        if (index <= 0 || index == mediaId.lastIndex) return null
        return mediaId.substring(0, index) to mediaId.substring(index + 1)
    }
}

private const val EXTRA_STATION = "sk.radioplayer.station"

fun Station.toMediaItem(listId: String, groupTitle: String? = null): MediaItem {
    val extras = Bundle().apply {
        putString(EXTRA_STATION, AppJson.encodeToString(Station.serializer(), this@toMediaItem))
        groupTitle?.let { putString(MediaConstants.EXTRAS_KEY_CONTENT_STYLE_GROUP_TITLE, it) }
    }
    val metadata = MediaMetadata.Builder()
        .setTitle(name)
        .setArtist(details.ifBlank { tags })
        .setStation(name)
        .setGenre(tags)
        .setArtworkUri(ArtworkProvider.uriFor(this))
        .setIsBrowsable(false)
        .setIsPlayable(true)
        .setMediaType(MediaMetadata.MEDIA_TYPE_RADIO_STATION)
        .setExtras(extras)
        .build()
    return MediaItem.Builder()
        .setMediaId(MediaIds.station(listId, id))
        .setUri(url)
        .apply { if (hls) setMimeType(MimeTypes.APPLICATION_M3U8) }
        .setMediaMetadata(metadata)
        .build()
}

/** Rádio uložené v položke (prežije aj prenos medzi procesmi, na rozdiel od URI). */
val MediaItem.station: Station?
    get() = mediaMetadata.extras?.getString(EXTRA_STATION)?.let {
        runCatching { AppJson.decodeFromString(Station.serializer(), it) }.getOrNull()
    }

fun browsableItem(
    context: Context,
    mediaId: String,
    title: String,
    @DrawableRes icon: Int? = null,
    childrenStyle: Int = MediaConstants.EXTRAS_VALUE_CONTENT_STYLE_LIST_ITEM,
): MediaItem {
    val extras = Bundle().apply {
        putInt(MediaConstants.EXTRAS_KEY_CONTENT_STYLE_PLAYABLE, childrenStyle)
        putInt(MediaConstants.EXTRAS_KEY_CONTENT_STYLE_BROWSABLE, MediaConstants.EXTRAS_VALUE_CONTENT_STYLE_LIST_ITEM)
    }
    val metadata = MediaMetadata.Builder()
        .setTitle(title)
        .setIsBrowsable(true)
        .setIsPlayable(false)
        .setMediaType(MediaMetadata.MEDIA_TYPE_FOLDER_RADIO_STATIONS)
        .setExtras(extras)
        .apply { icon?.let { setArtworkUri(resourceUri(context, it)) } }
        .build()
    return MediaItem.Builder().setMediaId(mediaId).setMediaMetadata(metadata).build()
}

private fun resourceUri(context: Context, @DrawableRes id: Int): Uri =
    Uri.Builder()
        .scheme(ContentResolver.SCHEME_ANDROID_RESOURCE)
        .authority(context.packageName)
        .appendPath(context.resources.getResourceTypeName(id))
        .appendPath(context.resources.getResourceEntryName(id))
        .build()
