# Airwaves – iOS (SwiftUI + TCA + CarPlay)

Natívna iOS appka postavená podľa „Point-Free Way“ (skilly `pfw-*` v `.claude/skills`):
The Composable Architecture, Dependencies, Sharing, IdentifiedCollections, SwiftNavigation, Swift Testing.

## Spustenie

```bash
cd ios && tuist generate
```

Otvor `ios/Radio.xcworkspace` (nie `.xcodeproj`), schéma **Radio**.

### Podpisovanie

- **Bezplatný osobný tím (Personal Team)** nepodporuje Siri ani CarPlay. Vygeneruj projekt bez nich,
  aby sa appka dala nahrať na iPhone (sekcia Siri sa v appke skryje):

```bash
TUIST_TEAM_ID=<ID tímu> TUIST_PERSONAL_TEAM=1 tuist generate
```

- **Platený tím (Apple Developer Program)** – Siri funguje hneď. CarPlay Audio musí Apple tímu najprv
  schváliť (developer.apple.com/contact/carplay); dovtedy na iPhone podpisuj bez CarPlay:

```bash
TUIST_TEAM_ID=<ID tímu> TUIST_CARPLAY=0 tuist generate
```

- Po schválení CarPlay (alebo pre simulátor, ktorý schválenie nepotrebuje):

```bash
TUIST_TEAM_ID=<ID tímu> tuist generate
```

ID tímu nájdeš v Xcode (*Signing & Capabilities → Team*) alebo na developer.apple.com → Membership. Pri prvom builde Xcode vyžiada
povolenie makier z balíkov Point-Free – zvoľ *Trust & Enable*.

Testy balíka (28 testov – prehrávač, obľúbené, hľadanie, nastavenia, Siri, formát zálohy):

```bash
cd ios/RadioPackage && xcodebuild test -scheme RadioPackage-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation
```

## Štruktúra

| Cesta | Obsah |
| --- | --- |
| `Project.swift` | Tuist projekt – tenký app target, Info.plist (audio na pozadí, scéna CarPlay), entitlement |
| `App/Sources` | `@main`, `AppDelegate` so zdieľaným `Store`, `CarPlaySceneDelegate` |
| `RadioPackage/Sources/Models` | `Station` (JSON kompatibilný s webom aj Androidom), žánre, krajiny, `Playback` |
| `RadioPackage/Sources/RadioBrowserClient` | `@DependencyClient` pre radio-browser.info so striedaním zrkadiel |
| `RadioPackage/Sources/AudioPlayerClient` | `@DependencyClient` nad AVPlayer – audio session, Now Playing, ovládanie zo zamknutej obrazovky, ICY názvy skladieb |
| `RadioPackage/Sources/StationImages` | Načítanie log rádií (favicon → https → apple-touch-icon → favicon služba) s cache |
| `RadioPackage/Sources/DesignSystem` | Neutrálna paleta z `design/tokens.json`, logo, ekvalizér, prázdne stavy |
| `RadioPackage/Sources/AppFeature` | TCA features: `AppFeature`, `Favorites`, `Search`, `Settings`, `Player` + SwiftUI views |
| `RadioPackage/Sources/L10n` | Preklady (generované z `localization/strings.json`) a typované `L10n.*` |
| `RadioPackage/Sources/SiriClient` | Povolenie Siri a „darovanie“ prehratých rádií, aby ich Siri ponúkala |
| `RadioPackage/Sources/SiriFeature` | `VoiceControl` – spracuje `INPlayMediaIntent` („Siri, pusti … v Airwaves“) |
| `RadioPackage/Sources/CarPlayFeature` | `CarPlayController` – karty Obľúbené / Populárne / Žánre a Now Playing s hviezdičkou |

Zdieľaný stav: obľúbené a posledné rádio sú `@Shared(.fileStorage)`, aktuálne prehrávanie je
`@Shared(.inMemory("playback"))`. Telefón aj CarPlay používajú jeden `Store`, takže appka funguje
aj keď sa spustí priamo z auta.

## Siri

Appka podporuje `INPlayMediaIntent` priamo v aplikácii (bez Intents extension). Siri vyhľadá rádio
(obľúbené → žáner → databáza) a appka ho prehrá cez zdieľaný `Store`. V CarPlay je na vrchu zoznamov
tlačidlo „Pustiť cez Siri“ – CarPlay audio appkám klávesnicu nepovoľuje, vyhľadáva sa hlasom.
Povolenie Siri si používateľ udelí v Nastaveniach appky. Na reálnom zariadení musí mať App ID zapnutú
schopnosť **Siri**.

## CarPlay

- Lokálne v simulátore: *I/O → External Displays → CarPlay* (okno zariadenia musí byť aktívne).
  V simulátore iOS 26.1 systémový CarPlay pri štarte padá – použi novší runtime (napr. iOS 26.5).
- Na reálnom zariadení musí mať tím od Apple schválený entitlement **CarPlay Audio**
  (`com.apple.developer.carplay-audio`) – žiadosť cez developer.apple.com/carplay.
