import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct AppFeature: Sendable {
  @ObservableState
  public struct State: Equatable {
    public var favorites = Favorites.State()
    var isNowPlayingPresented = false
    public var player = Player.State()
    public var search = Search.State()
    var selectedTab: Tab
    public var settings = Settings.State()

    public init() {
      @Shared(.favorites) var favorites
      // Bez obľúbených začíname hľadaním, rovnako ako web.
      selectedTab = favorites.isEmpty ? .search : .favorites
    }
  }

  public enum Tab: Hashable, Sendable {
    case favorites
    case search
    case settings
  }

  public enum Action: BindableAction {
    case appDidLaunch
    case binding(BindingAction<State>)
    case favorites(Favorites.Action)
    case miniPlayerTapped
    case nowPlayingDismissButtonTapped
    case player(Player.Action)
    case search(Search.Action)
    case settings(Settings.Action)
  }

  public init() {}

  public var body: some Reducer<State, Action> {
    BindingReducer()
    Scope(state: \.favorites, action: \.favorites) {
      Favorites()
    }
    Scope(state: \.player, action: \.player) {
      Player()
    }
    Scope(state: \.search, action: \.search) {
      Search()
    }
    Scope(state: \.settings, action: \.settings) {
      Settings()
    }
    Reduce { state, action in
      switch action {
      case .appDidLaunch:
        return .merge(
          .send(.player(.startListening)),
          .send(.favorites(.startRefreshing))
        )

      case .favorites(.delegate(.findStations)):
        state.selectedTab = .search
        return .none

      case .favorites(.delegate(.play(let station, let queue))),
        .search(.delegate(.play(let station, let queue))):
        return .send(.player(.playRequested(station, queue: queue)))

      case .favorites(.delegate(.togglePlayPause)), .search(.delegate(.togglePlayPause)):
        return .send(.player(.togglePlayPauseButtonTapped))

      case .miniPlayerTapped:
        guard state.player.playback.station != nil else { return .none }
        state.isNowPlayingPresented = true
        return .none

      case .nowPlayingDismissButtonTapped:
        state.isNowPlayingPresented = false
        return .none

      case .binding, .favorites, .player, .search, .settings:
        return .none
      }
    }
  }
}
