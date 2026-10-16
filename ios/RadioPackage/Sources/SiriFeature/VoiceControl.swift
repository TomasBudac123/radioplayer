import AppFeature
import ComposableArchitecture
import Foundation
@preconcurrency import Intents
import Models
import RadioBrowserClient
import SiriClient

/// Spracuje „Siri, pusti … v Rádiu“ – v telefóne aj v CarPlay.
///
/// Siri najprv vyhľadá rádio (`resolveMediaItems`), potom aplikácia dostane príkaz
/// `.handleInApp` a spustí prehrávanie vo svojom procese cez zdieľaný `Store`.
public final class VoiceControl: NSObject, INPlayMediaIntentHandling, Sendable {
  private let store: StoreOf<AppFeature>
  private let resolver = StationResolver()

  @MainActor
  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  public func resolveMediaItems(for intent: INPlayMediaIntent) async -> [INPlayMediaMediaItemResolutionResult] {
    let match = await resolver.resolve(intent)
    guard let station = match.stations.first else {
      return [.unsupported()]
    }
    return INPlayMediaMediaItemResolutionResult.successes(with: [INMediaItem(station)])
  }

  public func handle(intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse {
    INPlayMediaIntentResponse(code: .handleInApp, userActivity: nil)
  }

  /// Volá `AppDelegate` z `application(_:handle:completionHandler:)`.
  public func play(_ intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse {
    let match = await resolver.resolve(intent)
    guard let station = match.stations.first else {
      return INPlayMediaIntentResponse(code: .failureUnknownMediaType, userActivity: nil)
    }
    await MainActor.run {
      _ = store.send(.player(.playRequested(station, queue: match.queue)))
    }
    return INPlayMediaIntentResponse(code: .success, userActivity: nil)
  }
}

/// Výsledok hľadania: nájdené rádiá a zoznam pre prepínanie dopredu/dozadu.
struct VoiceMatch: Sendable {
  var stations: [Station]
  var queue: [Station]
}

actor StationResolver {
  @Dependency(\.radioBrowser) private var radioBrowser
  @Shared(.favorites) private var favorites
  @Shared(.lastStation) private var lastStation
  /// Rádiá z posledného hľadania – Siri ich potom pošle späť len ako identifikátor.
  private var recent: [String: VoiceMatch] = [:]

  func resolve(_ intent: INPlayMediaIntent) async -> VoiceMatch {
    let favorites = Array(self.favorites)

    // Siri už rádio vybrala (napr. z návrhov alebo po prvom kroku hľadania).
    if let id = intent.mediaItems?.first?.identifier {
      if let cached = recent[id] { return cached }
      if let favorite = favorites.first(where: { $0.id == id }) {
        return VoiceMatch(stations: [favorite], queue: favorites)
      }
      if let station = try? await radioBrowser.stations([id]).first {
        return VoiceMatch(stations: [station], queue: [])
      }
    }

    let mediaSearch = intent.mediaSearch
    let query = mediaSearch?.mediaName ?? mediaSearch?.genreNames?.first ?? ""
    let match = await stations(matching: query, favorites: favorites)
    if let first = match.stations.first { recent[first.id] = match }
    return match
  }

  private func stations(matching query: String, favorites: [Station]) async -> VoiceMatch {
    // „Siri, pusti Rádio“ bez názvu – pokračuj tam, kde si skončil.
    guard !VoiceQuery.normalize(query).isEmpty else {
      let station = lastStation ?? favorites.first
      return VoiceMatch(stations: station.map { [$0] } ?? [], queue: favorites)
    }
    // Presný názov obľúbeného rádia má prednosť, „jazz“ je však žáner, nie „101 Smooth Jazz“.
    let favorite = VoiceQuery.bestFavoriteMatch(for: query, in: favorites)
    if let favorite, favorite.score == VoiceQuery.exact {
      return VoiceMatch(stations: [favorite.station], queue: favorites)
    }
    let genre = VoiceQuery.genre(matching: query)
    if genre == nil, let favorite {
      return VoiceMatch(stations: [favorite.station], queue: favorites)
    }
    if let genre {
      let stations = (try? await radioBrowser.search(StationQuery(tag: genre.tag, limit: 30))) ?? []
      return VoiceMatch(stations: stations, queue: stations)
    }
    let stations = (try? await radioBrowser.search(StationQuery(name: query, limit: 10))) ?? []
    return VoiceMatch(stations: stations, queue: stations)
  }
}
