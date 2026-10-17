import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Intents
import Models
import Testing

@testable import AppFeature
@testable import SiriFeature

@Suite(
  .dependencies {
    $0.defaultFileStorage = .inMemory
  }
)
struct StationResolverTests {
  let expres = Station(id: "expres", name: "Rádio Expres", url: URL(string: "https://a.example")!)
  let fm = Station(id: "fm", name: "Rádio FM", url: URL(string: "https://b.example")!)

  func intent(name: String? = nil, genre: String? = nil, itemID: String? = nil) -> INPlayMediaIntent {
    INPlayMediaIntent(
      mediaItems: itemID.map { [INMediaItem(identifier: $0, title: nil, type: .radioStation, artwork: nil)] },
      mediaContainer: nil,
      playShuffled: nil,
      playbackRepeatMode: .unknown,
      resumePlayback: nil,
      playbackQueueLocation: .unknown,
      playbackSpeed: nil,
      mediaSearch: INMediaSearch(mediaType: .radioStation, mediaName: name, genreNames: genre.map { [$0] })
    )
  }

  @Test func spokenFavoriteWinsWithoutNetwork() async {
    @Shared(.favorites) var favorites
    $favorites.withLock { $0 = [expres, fm] }

    let match = await withDependencies {
      $0.radioBrowser.search = { _ in Issue.record("Obľúbené rádio sa nemá hľadať v databáze"); return [] }
    } operation: {
      await StationResolver().resolve(intent(name: "expres"))
    }
    #expect(match.stations.map(\.id) == ["expres"])
    #expect(match.queue.map(\.id) == ["expres", "fm"])
  }

  @Test func genreSearchesByTag() async {
    let jazz = Station(id: "jazz", name: "Jazz Radio", url: URL(string: "https://c.example")!)
    let queries = LockIsolated<[StationQuery]>([])
    let match = await withDependencies {
      $0.radioBrowser.search = { query in
        queries.withValue { $0.append(query) }
        return [jazz]
      }
    } operation: {
      await StationResolver().resolve(intent(genre: "Jazz"))
    }
    #expect(match.stations == [jazz])
    #expect(queries.value.map(\.tag) == ["jazz"])
  }

  @Test func genreBeatsPartialFavoriteMatch() async {
    let smoothJazz = Station(id: "smooth", name: "101 Smooth Jazz", url: URL(string: "https://e.example")!)
    let jazz = Station(id: "jazz", name: "Jazz Radio", url: URL(string: "https://c.example")!)
    @Shared(.favorites) var favorites
    $favorites.withLock { $0 = [smoothJazz] }

    let match = await withDependencies {
      $0.radioBrowser.search = { query in query.tag == "jazz" ? [jazz] : [] }
    } operation: {
      await StationResolver().resolve(intent(name: "jazz"))
    }
    #expect(match.stations == [jazz])
  }

  @Test func unknownNameSearchesDatabase() async {
    let bbc = Station(id: "bbc", name: "BBC Radio 1", url: URL(string: "https://d.example")!)
    let match = await withDependencies {
      $0.radioBrowser.search = { query in query.name == "BBC Radio 1" ? [bbc] : [] }
    } operation: {
      await StationResolver().resolve(intent(name: "BBC Radio 1"))
    }
    #expect(match.stations == [bbc])
  }

  @Test func emptyRequestResumesLastStation() async {
    @Shared(.favorites) var favorites
    @Shared(.lastStation) var lastStation
    $favorites.withLock { $0 = [expres, fm] }
    $lastStation.withLock { $0 = fm }

    let match = await StationResolver().resolve(intent())
    #expect(match.stations == [fm])
  }

  @Test func selectedItemIsReusedFromPreviousSearch() async {
    let bbc = Station(id: "bbc", name: "BBC Radio 1", url: URL(string: "https://d.example")!)
    let resolver = withDependencies {
      $0.radioBrowser.search = { _ in [bbc] }
      $0.radioBrowser.stations = { _ in Issue.record("Rádio z hľadania sa nemá znova načítavať"); return [] }
    } operation: {
      StationResolver()
    }
    _ = await resolver.resolve(intent(name: "BBC"))
    let match = await resolver.resolve(intent(itemID: "bbc"))
    #expect(match.stations == [bbc])
  }
}
