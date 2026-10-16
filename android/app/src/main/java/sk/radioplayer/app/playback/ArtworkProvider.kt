package sk.radioplayer.app.playback

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileNotFoundException
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import okhttp3.Request
import sk.radioplayer.app.RadioApplication
import sk.radioplayer.app.data.Station
import sk.radioplayer.app.data.iconCandidates

/**
 * Logá rádií pre Android Auto a Android Automotive. Auto si obrázky nesťahuje z webu,
 * načíta ich len cez `content://` – tento provider ich stiahne (skúša rovnakých kandidátov
 * ako appka), overí veľkosť a uloží do cache.
 */
class ArtworkProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("Read only")
        val context = requireNotNull(context)
        val candidates = uri.getQueryParameters(PARAM_CANDIDATE)
        // Provider je exportovaný (auto beží v inom procese) – adresy musí podpísať appka.
        if (uri.getQueryParameter(PARAM_SIGNATURE) != sign(context, candidates)) {
            throw SecurityException("Unsigned artwork URI")
        }
        if (candidates.isEmpty() || candidates.any { !it.startsWith("https://") && !it.startsWith("http://") }) {
            throw FileNotFoundException(uri.toString())
        }

        val directory = File(context.cacheDir, "artwork").apply { mkdirs() }
        val file = File(directory, sha1(candidates.joinToString("|")))
        val missing = File(directory, "${file.name}.missing")
        if (!file.exists() && !missing.exists()) {
            if (!download(candidates, file)) missing.createNewFile()
        }
        if (!file.exists()) throw FileNotFoundException(uri.toString())
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    private fun download(candidates: List<String>, target: File): Boolean {
        val client = (context?.applicationContext as? RadioApplication)?.container?.httpClient ?: return false
        for (url in candidates) {
            val bytes = runCatching {
                client.newCall(Request.Builder().url(url).build()).execute().use { response ->
                    if (response.isSuccessful) response.body.bytes() else null
                }
            }.getOrNull() ?: continue
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            // Menšie ikony (napr. 16px favicon) by boli rozmazané.
            if (minOf(bounds.outWidth, bounds.outHeight) < MIN_SIDE) continue
            val temp = File(target.parentFile, "${target.name}.tmp")
            temp.writeBytes(bytes)
            return temp.renameTo(target)
        }
        return false
    }

    override fun getType(uri: Uri): String = "image/*"
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0

    companion object {
        private const val PARAM_CANDIDATE = "c"
        private const val PARAM_SIGNATURE = "s"
        private const val MIN_SIDE = 40
        @Volatile private var key: ByteArray? = null
        private lateinit var appContext: Context

        /** Volá sa pri štarte aplikácie. */
        fun install(context: Context) {
            appContext = context.applicationContext
        }

        fun uriFor(station: Station): Uri? {
            val context = appContext
            val candidates = station.iconCandidates()
            if (candidates.isEmpty()) return null
            return Uri.Builder()
                .scheme("content")
                .authority("${context.packageName}.artwork")
                .appendPath(station.id)
                .apply { candidates.forEach { appendQueryParameter(PARAM_CANDIDATE, it) } }
                .appendQueryParameter(PARAM_SIGNATURE, sign(context, candidates))
                .build()
        }

        private fun sign(context: Context, candidates: List<String>): String {
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(signingKey(context), "HmacSHA256"))
            return mac.doFinal(candidates.joinToString("\n").toByteArray())
                .joinToString("") { "%02x".format(it) }
        }

        /** Náhodný kľúč pre túto inštaláciu. */
        private fun signingKey(context: Context): ByteArray = key ?: synchronized(this) {
            key ?: run {
                val file = File(context.noBackupFilesDir, "artwork.key")
                val stored = runCatching { file.readBytes() }.getOrNull()?.takeIf { it.size == 32 }
                (stored ?: ByteArray(32).also { SecureRandom().nextBytes(it); file.writeBytes(it) }).also { key = it }
            }
        }

        private fun sha1(text: String): String =
            MessageDigest.getInstance("SHA-1").digest(text.toByteArray()).joinToString("") { "%02x".format(it) }
    }
}
