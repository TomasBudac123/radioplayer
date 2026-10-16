package sk.radioplayer.app

import android.Manifest
import android.app.SearchManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import sk.radioplayer.app.ui.RadioApp
import sk.radioplayer.app.ui.theme.RadioTheme

class MainActivity : ComponentActivity() {
    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val container = (application as RadioApplication).container
        container.player.connect(container.favorites.lastStation) {
            container.favorites.favorites.value.map { it.id }.toSet()
        }
        setContent {
            RadioTheme {
                RadioApp(container, onFirstPlay = ::requestNotificationPermission)
            }
        }
        handleVoiceSearch(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleVoiceSearch(intent)
    }

    /** „Hey Google, pusti … v Rádiu“ – Asistent pošle hľadaný výraz ako MEDIA_PLAY_FROM_SEARCH. */
    private fun handleVoiceSearch(intent: Intent?) {
        if (intent?.action != MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH) return
        val query = intent.getStringExtra(SearchManager.QUERY).orEmpty()
        (application as RadioApplication).container.player.playFromSearch(query)
        // Rovnaký príkaz sa nesmie spustiť znova po otočení obrazovky.
        intent.action = null
    }

    /** Notifikácia s ovládaním prehrávania potrebuje na Androide 13+ povolenie. */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}

object BuildConfigInfo {
    fun versionName(context: Context): String = runCatching {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        "${info.versionName} (${info.longVersionCodeCompat})"
    }.getOrDefault("1.0")

    @Suppress("DEPRECATION")
    private val android.content.pm.PackageInfo.longVersionCodeCompat: Long
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) longVersionCode else versionCode.toLong()
}
