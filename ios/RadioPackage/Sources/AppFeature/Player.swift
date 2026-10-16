import AudioPlayerClient
import ComposableArchitecture
import Foundation
import L10n
import Models
import RadioBrowserClient
import SiriClient

@Reducer
public struct Player: Sendable {
  @ObservableState
  public struct State: Equatable {
    /// Adresy streamu, ktoré ešte môžeme skúsiť, ak aktuálna nefunguje.
    var candidates: [URL] = []
    @Shared(.favorites) var favorites
    @Shared(.lastStation) var lastStation
    @Shared(.playback) public var playback
    /// Zoznam, v ktorom sa prepína dopredu/dozadu, ak hrajúce rádio nie je v obľúbených.
    var queue: [Station] = []

    public init() {}

    public var isFavorite: Bool {
      playback.station.map { favorites[id: $0.id] != nil } ?? false
    }

    /// Prepínanie dopredu/dozadu má zmysel len, ak je kam.
    public var canSkip: Bool {
      skipList.count > 1
    }

    var skipList: [Station] {
      guard let station = playback.station else { return Array(favorites) }
      if favorites[id: station.id] != nil { return Array(favorites) }
      if queue.contains(where: { $0.id == station.id }) { return queue }
      return Array(favorites)
    }
  }

  public enum Action {
    case audioEvent(PlayerEvent)
    case favoriteButtonTapped
    case nextButtonTapped
    case playRequested(Station, queue: [Station])
    case previousButtonTapped
    case startListening
    case togglePlayPauseButtonTapped
    case watchdogFired
  }

  enum CancelID {
    case events
    case watchdog
  }

  /// Ako dlho čakáme na pripojenie, kým skúsime ďalšiu adresu streamu.
  static let connectTimeout: Duration = .seconds(15)
  static var failureMessage: String { L10n.playerFailed }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.continuousClock) var clock
  @Dependency(\.radioBrowser) var radioBrowser
  @Dependency(\.siri) var siri

  public init() {}

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .audioEvent(let event):
        return handle(event, state: &state)

      case .favoriteButtonTapped:
        guard let station = state.playback.station else { return .none }
        state.$favorites.withLock {
          if $0.remove(id: station.id) == nil { $0.append(station) }
        }
        return .none

      case .nextButtonTapped:
        return skip(by: 1, state: &state)

      case .playRequested(let station, let queue):
        state.queue = queue
        return play(station, state: &state)

      case .previousButtonTapped:
        return skip(by: -1, state: &state)

      case .startListening:
        if state.playback.station == nil, let last = state.lastStation {
          state.$playback.withLock { $0 = Playback(station: last, status: .idle) }
        }
        return .run { [playback = state.playback] send in
          await audioPlayer.updateNowPlaying(playback)
          for await event in await audioPlayer.events() {
            await send(.audioEvent(event))
          }
        }
        .cancellable(id: CancelID.events, cancelInFlight: true)

      case .togglePlayPauseButtonTapped:
        return togglePlayPause(state: &state)

      case .watchdogFired:
        guard state.playback.status == .loading else { return .none }
        return connectNextCandidate(state: &state)
      }
    }
    .onChange(of: \.playback) { _, playback in
      Reduce { _, _ in
        .run { _ in await audioPlayer.updateNowPlaying(playback) }
      }
    }
  }

  private func handle(_ event: PlayerEvent, state: inout State) -> Effect<Action> {
    switch event {
    case .buffering:
      if state.playback.status == .playing {
        state.$playback.withLock { $0.status = .loading }
      }
      return .none

    case .failed:
      switch state.playback.status {
      case .loading:
        return connectNextCandidate(state: &state)
      case .playing:
        // Fungujúci stream sa prerušil – pripojíme sa znova od začiatku.
        guard let station = state.playback.station else { return .none }
        return play(station, state: &state)
      case .idle, .paused, .failed:
        return .none
      }

    case .playing:
      guard state.playback.isActive else { return .none }
      state.$playback.withLock { $0.status = .playing }
      return .cancel(id: CancelID.watchdog)

    case .remoteCommand(let command):
      switch command {
      case .nextTrack:
        return skip(by: 1, state: &state)
      case .pause:
        return pause(state: &state)
      case .play:
        guard !state.playback.isActive, let station = state.playback.station else { return .none }
        return play(station, state: &state)
      case .previousTrack:
        return skip(by: -1, state: &state)
      case .togglePlayPause:
        return togglePlayPause(state: &state)
      }

    case .stoppedBySystem:
      guard state.playback.isActive else { return .none }
      return pause(state: &state)

    case .trackTitle(let title):
      guard state.playback.isActive else { return .none }
      let title = title == state.playback.station?.name ? nil : title
      state.$playback.withLock { $0.trackTitle = title }
      return .none
    }
  }

  private func play(_ station: Station, state: inout State) -> Effect<Action> {
    state.$playback.withLock { $0 = Playback(station: station, status: .loading) }
    state.$lastStation.withLock { $0 = station }
    state.candidates = station.streamCandidates
    return .merge(
      // Nahlásime klik – pomáha rebríčku popularity v Radio Browser.
      station.isManual ? .none : .run { _ in await radioBrowser.reportClick(station.id) },
      // Siri sa tak naučí názvy rádií a ponúkne ich v návrhoch.
      .run { _ in await siri.donatePlay(station) },
      connectNextCandidate(state: &state)
    )
  }

  private func connectNextCandidate(state: inout State) -> Effect<Action> {
    guard let station = state.playback.station, !state.candidates.isEmpty else {
      state.$playback.withLock {
        $0.status = .failed(Self.failureMessage)
        $0.trackTitle = nil
      }
      return .merge(
        .cancel(id: CancelID.watchdog),
        .run { _ in await audioPlayer.stop() }
      )
    }
    let url = state.candidates.removeFirst()
    return .merge(
      .run { _ in await audioPlayer.play(url, station) },
      .run { send in
        try await clock.sleep(for: Self.connectTimeout)
        await send(.watchdogFired)
      }
      .cancellable(id: CancelID.watchdog, cancelInFlight: true)
    )
  }

  private func pause(state: inout State) -> Effect<Action> {
    guard state.playback.station != nil else { return .none }
    state.$playback.withLock {
      $0.status = .paused
      $0.trackTitle = nil
    }
    state.candidates = []
    return .merge(
      .cancel(id: CancelID.watchdog),
      .run { _ in await audioPlayer.stop() }
    )
  }

  private func togglePlayPause(state: inout State) -> Effect<Action> {
    if state.playback.isActive {
      return pause(state: &state)
    }
    // Živé rádio – po pauze sa pripojíme nanovo, aby sme boli „naživo“.
    guard let station = state.playback.station else { return .none }
    return play(station, state: &state)
  }

  private func skip(by offset: Int, state: inout State) -> Effect<Action> {
    let list = state.skipList
    guard !list.isEmpty else { return .none }
    let index = list.firstIndex { $0.id == state.playback.station?.id }
    let next: Station
    if let index {
      next = list[(index + offset + list.count) % list.count]
    } else {
      next = offset > 0 ? list[0] : list[list.count - 1]
    }
    return play(next, state: &state)
  }
}
