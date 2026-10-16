import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import L10n
import Models
import SiriClient
import Testing

@testable import AppFeature

@Suite(
  .dependencies {
    $0.defaultFileStorage = .inMemory
  }
)
@MainActor
struct FeatureTests {
  @Test func favoritesTileTapPlaysOrToggles() async {
    let station = Station.previews[0]
    var state = Favorites.State()
    state.$favorites.withLock { $0 = IdentifiedArray(uniqueElements: Station.previews) }
    let store = TestStore(initialState: state) {
      Favorites()
    }

    await store.send(.tileTapped(station))
    await store.receive(\.delegate.play)

    store.state.$playback.withLock { $0 = Playback(station: station, status: .playing) }
    await store.send(.tileTapped(station))
    await store.receive(\.delegate.togglePlayPause)
  }

  @Test func favoritesRefreshKeepsUserOrderAndName() async {
    var renamed = Station.previews[0]
    renamed.name = "Môj Expres"
    let fresh = {
      var station = Station.previews[0]
      station.favicon = "https://cdn.example/expres.png"
      return station
    }()
    var state = Favorites.State()
    state.$favorites.withLock { $0 = [Station.previews[1], renamed] }
    let store = TestStore(initialState: state) {
      Favorites()
    } withDependencies: {
      $0.radioBrowser.stations = { _ in [fresh] }
    }

    await store.send(.startRefreshing)
    await store.receive(\.refreshResponse) {
      $0.$favorites.withLock { $0[id: renamed.id]?.favicon = "https://cdn.example/expres.png" }
    }
  }

  @Test func searchDebouncesTyping() async {
    let clock = TestClock()
    let queries = LockIsolated<[String]>([])
    let store = TestStore(initialState: Search.State()) {
      Search()
    } withDependencies: {
      $0.continuousClock = clock
      $0.radioBrowser.search = { query in
        queries.withValue { $0.append(query.name) }
        return [Station.previews[0]]
      }
    }

    await store.send(\.binding.query, "ex") { $0.query = "ex" }
    await clock.advance(by: .milliseconds(200))
    await store.send(\.binding.query, "expres") { $0.query = "expres" }
    await clock.advance(by: .milliseconds(450))
    await store.receive(\.queryDebounced) { $0.isLoading = true }
    await store.receive(\.searchResponse) {
      $0.isLoading = false
      $0.results = [Station.previews[0]]
      $0.nextOffset = Search.pageSize
    }
    #expect(queries.value == ["expres"])
  }

  @Test func settingsAddsManualStation() async {
    let store = TestStore(initialState: Settings.State()) {
      Settings()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(\.binding.manualName, "Moje rádio") { $0.manualName = "Moje rádio" }
    await store.send(\.binding.manualURL, "nie je adresa") { $0.manualURL = "nie je adresa" }
    #expect(!store.state.isManualFormValid)
    await store.send(\.binding.manualURL, "https://example.com/live") {
      $0.manualURL = "https://example.com/live"
    }
    await store.send(.addManualButtonTapped) {
      $0.$favorites.withLock {
        $0 = [
          Station(
            id: "manual-00000000-0000-0000-0000-000000000000",
            name: "Moje rádio",
            url: URL(string: "https://example.com/live")!
          )
        ]
      }
      $0.manualName = ""
      $0.manualURL = ""
      $0.alert = AlertState {
        TextState(L10n.favoritesAddedTitle)
      } message: {
        TextState(L10n.favoritesAddedMessage("Moje rádio"))
      }
    }
  }

  @Test func settingsAsksForSiriPermission() async {
    let store = TestStore(initialState: Settings.State()) {
      Settings()
    } withDependencies: {
      $0.siri.authorizationStatus = { .notDetermined }
      $0.siri.requestAuthorization = { .authorized }
    }

    await store.send(.onAppear)
    await store.send(.allowSiriButtonTapped)
    await store.receive(\.siriAuthorizationResponse) {
      $0.siriAuthorization = .authorized
    }
  }

  @Test func emptyFavoritesStartOnSearch() {
    #expect(AppFeature.State().selectedTab == .search)
  }
}
