import AudioPlayerClient
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Models
import SiriClient
import Testing

@testable import AppFeature

@Suite(
  .dependencies {
    $0.audioPlayer.updateNowPlaying = { _ in }
    $0.defaultFileStorage = .inMemory
    $0.radioBrowser.reportClick = { _ in }
    $0.siri.donatePlay = { _ in }
  }
)
@MainActor
struct PlayerTests {
  let primary = URL(string: "https://stream.example/hi.mp3")!
  let backup = URL(string: "http://stream.example/hi.mp3")!
  var station: Station {
    Station(id: "expres", name: "Expres", url: primary, url2: backup)
  }

  @Test func playConnectsAndPlays() async {
    let clock = TestClock()
    let played = LockIsolated<[URL]>([])
    let store = TestStore(initialState: Player.State()) {
      Player()
    } withDependencies: {
      $0.audioPlayer.play = { url, _ in played.withValue { $0.append(url) } }
      $0.continuousClock = clock
    }

    await store.send(.playRequested(station, queue: [])) {
      $0.$playback.withLock { $0 = Playback(station: station, status: .loading) }
      $0.$lastStation.withLock { $0 = station }
      $0.candidates = [backup]
    }
    await store.send(.audioEvent(.playing)) {
      $0.$playback.withLock { $0.status = .playing }
    }
    await store.send(.audioEvent(.trackTitle("Daft Punk – One More Time"))) {
      $0.$playback.withLock { $0.trackTitle = "Daft Punk – One More Time" }
    }
    // Po pripojení už watchdog nesmie preskočiť na ďalšiu adresu.
    await clock.advance(by: .seconds(30))
    #expect(played.value == [primary])
  }

  @Test func failedStreamFallsBackToNextURLThenFails() async {
    let clock = TestClock()
    let played = LockIsolated<[URL]>([])
    let stopped = LockIsolated(0)
    let store = TestStore(initialState: Player.State()) {
      Player()
    } withDependencies: {
      $0.audioPlayer.play = { url, _ in played.withValue { $0.append(url) } }
      $0.audioPlayer.stop = { stopped.withValue { $0 += 1 } }
      $0.continuousClock = clock
    }

    await store.send(.playRequested(station, queue: [])) {
      $0.$playback.withLock { $0 = Playback(station: station, status: .loading) }
      $0.$lastStation.withLock { $0 = station }
      $0.candidates = [backup]
    }
    await store.send(.audioEvent(.failed("403"))) {
      $0.candidates = []
    }
    await store.send(.audioEvent(.failed("403"))) {
      $0.$playback.withLock { $0.status = .failed(Player.failureMessage) }
    }
    await store.finish()
    #expect(played.value == [primary, backup])
    #expect(stopped.value == 1)
  }

  @Test func watchdogTriesNextURLWhenConnectingHangs() async {
    let clock = TestClock()
    let played = LockIsolated<[URL]>([])
    let store = TestStore(initialState: Player.State()) {
      Player()
    } withDependencies: {
      $0.audioPlayer.play = { url, _ in played.withValue { $0.append(url) } }
      $0.continuousClock = clock
    }

    await store.send(.playRequested(station, queue: [])) {
      $0.$playback.withLock { $0 = Playback(station: station, status: .loading) }
      $0.$lastStation.withLock { $0 = station }
      $0.candidates = [backup]
    }
    await clock.advance(by: Player.connectTimeout)
    await store.receive(\.watchdogFired) {
      $0.candidates = []
    }
    await store.send(.audioEvent(.playing)) {
      $0.$playback.withLock { $0.status = .playing }
    }
    #expect(played.value == [primary, backup])
  }

  @Test func togglePauseStopsAndResumeReconnects() async {
    let clock = TestClock()
    let stopped = LockIsolated(0)
    var state = Player.State()
    state.$playback.withLock { $0 = Playback(station: station, status: .playing, trackTitle: "Song") }
    let store = TestStore(initialState: state) {
      Player()
    } withDependencies: {
      $0.audioPlayer.play = { _, _ in }
      $0.audioPlayer.stop = { stopped.withValue { $0 += 1 } }
      $0.continuousClock = clock
    }

    await store.send(.togglePlayPauseButtonTapped) {
      $0.$playback.withLock {
        $0.status = .paused
        $0.trackTitle = nil
      }
    }
    await store.send(.togglePlayPauseButtonTapped) {
      $0.$playback.withLock { $0.status = .loading }
      $0.$lastStation.withLock { $0 = station }
      $0.candidates = [backup]
    }
    await store.send(.audioEvent(.playing)) {
      $0.$playback.withLock { $0.status = .playing }
    }
    #expect(stopped.value == 1)
  }

  @Test func nextCyclesThroughFavorites() async {
    let other = Station(id: "fm", name: "FM", url: URL(string: "https://fm.example")!)
    let clock = TestClock()
    var state = Player.State()
    state.$favorites.withLock { $0 = [station, other] }
    state.$playback.withLock { $0 = Playback(station: other, status: .playing) }
    let store = TestStore(initialState: state) {
      Player()
    } withDependencies: {
      $0.audioPlayer.play = { _, _ in }
      $0.continuousClock = clock
    }
    store.exhaustivity = .off

    await store.send(.audioEvent(.remoteCommand(.nextTrack))) {
      $0.$playback.withLock { $0 = Playback(station: station, status: .loading) }
    }
    await store.send(.previousButtonTapped) {
      $0.$playback.withLock { $0 = Playback(station: other, status: .loading) }
    }
    await store.skipInFlightEffects()
  }

  @Test func favoriteButtonTogglesCurrentStation() async {
    var state = Player.State()
    state.$playback.withLock { $0 = Playback(station: station, status: .playing) }
    let store = TestStore(initialState: state) {
      Player()
    }

    await store.send(.favoriteButtonTapped) {
      $0.$favorites.withLock { $0 = [station] }
    }
    #expect(store.state.isFavorite)
    await store.send(.favoriteButtonTapped) {
      $0.$favorites.withLock { $0 = [] }
    }
  }
}
