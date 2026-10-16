# Airwaves – Android (Compose + Media3 + Android Auto)

Natívna Android appka: Kotlin, Jetpack Compose (Material 3 s neutrálnou paletou z `design/tokens.json`),
Media3 ExoPlayer + `MediaLibraryService`, OkHttp, kotlinx.serialization, Coil.

## Spustenie

```bash
cd android && ./gradlew :app:installDebug
```

Testy:

```bash
cd android && ./gradlew :app:testDebugUnitTest
```

```bash
cd android && ./gradlew :app:connectedDebugAndroidTest
```

Inštrumentovaný test `MediaLibraryTest` sa k službe pripojí ako Android Auto (`MediaBrowser`)
a prejde strom knižnice, prehratie podľa ID, prepínanie a tlačidlo obľúbených.

## Štruktúra

| Cesta | Obsah |
| --- | --- |
| `data/` | `Station` (JSON kompatibilný s webom aj iOS), Radio Browser API so striedaním zrkadiel, obľúbené v súbore |
| `playback/PlaybackService.kt` | `MediaLibraryService` – ExoPlayer, notifikácia, záložná adresa streamu, ICY názvy skladieb, hviezdička ako tlačidlo v aute |
| `playback/StationLibrary.kt` | Strom pre Android Auto: Obľúbené (mriežka), Populárne (krajina + svet), Žánre, hlasové „pusti … v Airwaves“ |
| `playback/PlayerConnection.kt` | `MediaController` pre UI – rovnaký session ako auto |
| `ui/` | Compose obrazovky Obľúbené, Hľadať, Nastavenia, mini prehrávač a celoobrazovkový prehrávač |

## Preklady a hlas

- `res/values*/strings.xml` sa generujú z `localization/strings.json` (`python3 tools/gen-strings.py`),
  jazyk appky sa dá zvoliť aj v systémových nastaveniach Androidu 13+ (`locales_config.xml`).
- Google Asistent: „Hey Google, pusti … v Airwaves“ príde ako `MEDIA_PLAY_FROM_SEARCH` (telefón) alebo
  cez médiovú session (Android Auto); vyhľadávanie rieši `StationLibrary.playFromSearch` podľa `VoiceQuery`.
- V hľadaní je mikrofón (systémové rozpoznávanie reči).

## Android Auto

Testovanie s Desktop Head Unit (DHU):

1. V telefóne: Android Auto → nastavenia → 10× ťukni na *Verzia* → v menu *Režim pre vývojárov*
   zapni **Neznáme zdroje** a spusti **Head unit server**.
2. Na počítači:

```bash
adb forward tcp:5277 tcp:5277
```

```bash
~/Library/Android/sdk/extras/google/auto/desktop-head-unit
```

Emulátor s Google Play má Android Auto len ako „stub“ – plnú verziu treba aktualizovať z Play Store
(prihlásenie Google účtom), alebo použiť reálny telefón. Appka beží aj v Android Automotive OS
(rovnaká `MediaLibraryService`).
