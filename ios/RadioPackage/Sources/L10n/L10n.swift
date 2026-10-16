// Vygenerované z localization/strings.json (tools/gen-strings.py) – neupravuj ručne.

import Foundation

/// Lokalizované texty aplikácie (rovnaké ako v Android aplikácii).
public enum L10n {
  /// Airwaves
  public static var appName: String { tr("app.name") }
  /// Favorites
  public static var tabFavorites: String { tr("tab.favorites") }
  /// Search
  public static var tabSearch: String { tr("tab.search") }
  /// Settings
  public static var tabSettings: String { tr("tab.settings") }
  /// Popular
  public static var tabPopular: String { tr("tab.popular") }
  /// Genres
  public static var tabGenres: String { tr("tab.genres") }
  /// Edit
  public static var actionEdit: String { tr("action.edit") }
  /// Done
  public static var actionDone: String { tr("action.done") }
  /// OK
  public static var actionOk: String { tr("action.ok") }
  /// Close
  public static var actionClose: String { tr("action.close") }
  /// Try again
  public static var actionRetry: String { tr("action.retry") }
  /// No favorites yet
  public static var favoritesEmptyTitle: String { tr("favorites.empty.title") }
  /// Find your stations and add them with the star. Then play them here with one tap.
  public static var favoritesEmptyMessage: String { tr("favorites.empty.message") }
  /// Search stations
  public static var favoritesEmptyAction: String { tr("favorites.empty.action") }
  /// Add to favorites
  public static var favoritesAdd: String { tr("favorites.add") }
  /// Remove from favorites
  public static var favoritesRemove: String { tr("favorites.remove") }
  /// This order also sets next and previous on the lock screen and in the car.
  public static var favoritesReorderHint: String { tr("favorites.reorderHint") }
  /// Move up
  public static var favoritesMoveUp: String { tr("favorites.moveUp") }
  /// Move down
  public static var favoritesMoveDown: String { tr("favorites.moveDown") }
  /// Remove {1}
  public static func favoritesRemoveStation(_ p1: String) -> String { tr("favorites.removeStation", p1) }
  /// Added to favorites
  public static var favoritesAddedTitle: String { tr("favorites.added.title") }
  /// You’ll find “{1}” in Favorites.
  public static func favoritesAddedMessage(_ p1: String) -> String { tr("favorites.added.message", p1) }
  /// Station name, e.g. BBC, Capital, Jazz…
  public static var searchPrompt: String { tr("search.prompt") }
  /// Whole world
  public static var searchWholeWorld: String { tr("search.wholeWorld") }
  /// All genres
  public static var searchAllGenres: String { tr("search.allGenres") }
  /// Clear filters
  public static var searchClearFilters: String { tr("search.clearFilters") }
  /// Results
  public static var searchResults: String { tr("search.results") }
  /// Most popular
  public static var searchMostPopular: String { tr("search.mostPopular") }
  /// Nothing found
  public static var searchNoResultsTitle: String { tr("search.noResults.title") }
  /// Try a different name, genre or country.
  public static var searchNoResultsMessage: String { tr("search.noResults.message") }
  /// No connection
  public static var searchOfflineTitle: String { tr("search.offline.title") }
  /// Couldn’t load stations. Check your connection.
  public static var searchOfflineMessage: String { tr("search.offline.message") }
  /// Country
  public static var searchCountry: String { tr("search.country") }
  /// Genre
  public static var searchGenre: String { tr("search.genre") }
  /// Search country
  public static var searchFindCountry: String { tr("search.findCountry") }
  /// Search genre
  public static var searchFindGenre: String { tr("search.findGenre") }
  /// Selected
  public static var searchSelected: String { tr("search.selected") }
  /// Clear
  public static var searchClear: String { tr("search.clear") }
  /// Search by voice
  public static var searchVoice: String { tr("search.voice") }
  /// Untitled
  public static var stationUntitled: String { tr("station.untitled") }
  /// Loading station
  public static var stationLoading: String { tr("station.loading") }
  /// Live
  public static var playerLive: String { tr("player.live") }
  /// Connecting…
  public static var playerConnecting: String { tr("player.connecting") }
  /// Paused
  public static var playerPaused: String { tr("player.paused") }
  /// Couldn’t play the stream
  public static var playerFailed: String { tr("player.failed") }
  /// Play
  public static var playerPlay: String { tr("player.play") }
  /// Pause
  public static var playerPause: String { tr("player.pause") }
  /// Next station
  public static var playerNext: String { tr("player.next") }
  /// Previous station
  public static var playerPrevious: String { tr("player.previous") }
  /// Close player
  public static var playerClosePlayer: String { tr("player.closePlayer") }
  /// Now playing {1}
  public static func playerNowPlaying(_ p1: String) -> String { tr("player.nowPlaying", p1) }
  /// Opens the player
  public static var playerOpensPlayer: String { tr("player.opensPlayer") }
  /// Plays the station
  public static var playerHintPlay: String { tr("player.hintPlay") }
  /// Pauses playback
  public static var playerHintPause: String { tr("player.hintPause") }
  /// Backup
  public static var settingsBackupHeader: String { tr("settings.backup.header") }
  /// Export favorites
  public static var settingsExport: String { tr("settings.export") }
  /// Import from backup
  public static var settingsImport: String { tr("settings.import") }
  /// The backup works with the web, iOS and Android versions of the app.
  public static var settingsBackupFooter: String { tr("settings.backup.footer") }
  /// Favorite stations
  public static var settingsBackupShareTitle: String { tr("settings.backup.shareTitle") }
  /// Add a station manually
  public static var settingsManualHeader: String { tr("settings.manual.header") }
  /// Name
  public static var settingsManualName: String { tr("settings.manual.name") }
  /// Stream URL (https://…)
  public static var settingsManualUrl: String { tr("settings.manual.url") }
  /// For stations that aren’t in the database. You can usually find the stream URL on the station’s website.
  public static var settingsManualFooter: String { tr("settings.manual.footer") }
  /// About
  public static var settingsAboutHeader: String { tr("settings.about.header") }
  /// Station database
  public static var settingsDatabase: String { tr("settings.database") }
  /// Version
  public static var settingsVersion: String { tr("settings.version") }
  /// Import complete
  public static var backupImportedTitle: String { tr("backup.imported.title") }
  /// All stations from the backup are already in your favorites.
  public static var backupImportedNone: String { tr("backup.imported.none") }
  /// Stations added: {1}
  public static func backupImportedCount(_ p1: String) -> String { tr("backup.imported.count", p1) }
  /// Invalid backup file
  public static var backupInvalidTitle: String { tr("backup.invalid.title") }
  /// Choose a file exported from the Airwaves app (iPhone, Android or web).
  public static var backupInvalidMessage: String { tr("backup.invalid.message") }
  /// Backup saved
  public static var backupExportedTitle: String { tr("backup.exported.title") }
  /// Restore it in the Airwaves app on Android, iPhone or the web.
  public static var backupExportedMessage: String { tr("backup.exported.message") }
  /// Couldn’t save the backup
  public static var backupExportFailedTitle: String { tr("backup.exportFailed.title") }
  /// Try a different location.
  public static var backupExportFailedMessage: String { tr("backup.exportFailed.message") }
  /// Voice control
  public static var voiceHeader: String { tr("voice.header") }
  /// BBC Radio 1
  public static var voiceExample: String { tr("voice.example") }
  /// Say, for example, “Siri, play {1} on {2}”, or name a genre. It also works in CarPlay.
  public static func voiceSiriFooter(_ p1: String, _ p2: String) -> String { tr("voice.siri.footer", p1, p2) }
  /// Allow Siri
  public static var voiceSiriAllow: String { tr("voice.siri.allow") }
  /// Siri is allowed
  public static var voiceSiriAllowed: String { tr("voice.siri.allowed") }
  /// Siri is turned off for this app in Settings
  public static var voiceSiriDenied: String { tr("voice.siri.denied") }
  /// Siri plays your stations when you ask, for example in the car.
  public static var voiceSiriUsage: String { tr("voice.siri.usage") }
  /// Add stations on your phone with the star.
  public static var carFavoritesEmptySubtitle: String { tr("car.favorites.emptySubtitle") }
  /// Loading…
  public static var carLoading: String { tr("car.loading") }
  /// Couldn’t load stations
  public static var carLoadFailed: String { tr("car.loadFailed") }
  /// Check your phone’s connection.
  public static var carCheckConnection: String { tr("car.checkConnection") }
  /// Your country
  public static var carYourCountry: String { tr("car.yourCountry") }

  /// Názov žánru podľa tagu z Radio Browser, napr. „top 40“.
  public static func genre(_ tag: String) -> String {
    tr("genre." + tag.replacingOccurrences(of: " ", with: ""))
  }

  /// Jazyky, do ktorých je aplikácia preložená.
  public static let languages = ["en", "sk", "cs", "de", "es", "fr", "it", "pl", "hu", "pt"]

  private static func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: nil, table: nil)
    return args.isEmpty ? format : String(format: format, locale: .current, arguments: args)
  }
}
