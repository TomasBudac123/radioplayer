package sk.radioplayer.app

import android.app.Application
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import coil3.request.crossfade
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import okhttp3.OkHttpClient
import sk.radioplayer.app.data.FavoritesRepository
import sk.radioplayer.app.data.RadioBrowser
import sk.radioplayer.app.data.RadioBrowserApi
import sk.radioplayer.app.data.StationRegistry
import sk.radioplayer.app.playback.ArtworkProvider
import sk.radioplayer.app.playback.PlayerConnection

class RadioApplication : Application(), SingletonImageLoader.Factory {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        ArtworkProvider.install(this)
        container = AppContainer(this)
    }

    override fun newImageLoader(context: PlatformContext): ImageLoader =
        ImageLoader.Builder(context)
            .components { add(OkHttpNetworkFetcherFactory(callFactory = { container.httpClient })) }
            .crossfade(true)
            .build()
}

/** Závislosti zdieľané obrazovkami aj prehrávacou službou (jeden proces). */
class AppContainer(application: Application) {
    val scope = CoroutineScope(SupervisorJob())
    val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()
    val api: RadioBrowser = RadioBrowserApi(httpClient) { application.getString(R.string.station_untitled) }
    val favorites = FavoritesRepository(application.filesDir, scope)
    val registry = StationRegistry()
    val player = PlayerConnection(application, scope)
}
