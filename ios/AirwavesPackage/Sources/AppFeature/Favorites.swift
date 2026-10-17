import ComposableArchitecture
import Foundation
import Models
import RadioBrowserClient

@Reducer
public struct Favorites: Sendable {
  @ObservableState
  public struct State: Equatable {
    @Shared(.favorites) public var favorites
    var isEditing = false
    @Shared(.playback) var playback

    public init() {}
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case deleteButtonTapped(Station.ID)
    case doneButtonTapped
    case editButtonTapped
    case findStationsButtonTapped
    case moved(IndexSet, Int)
    case refreshResponse([Station])
    case removed(IndexSet)
    case startRefreshing
    case tileTapped(Station)

    @CasePathable
    public enum Delegate {
      case findStations
      case play(Station, queue: [Station])
      case togglePlayPause
    }
  }

  @Dependency(\.radioBrowser) var radioBrowser

  public init() {}

  public var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding, .delegate:
        return .none

      case .deleteButtonTapped(let id):
        _ = state.$favorites.withLock { $0.remove(id: id) }
        if state.favorites.isEmpty { state.isEditing = false }
        return .none

      case .doneButtonTapped:
        state.isEditing = false
        return .none

      case .editButtonTapped:
        state.isEditing = true
        return .none

      case .findStationsButtonTapped:
        return .send(.delegate(.findStations))

      case .moved(let source, let destination):
        state.$favorites.withLock { $0.move(fromOffsets: source, toOffset: destination) }
        return .none

      case .refreshResponse(let fresh):
        let byID = Dictionary(fresh.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        state.$favorites.withLock { favorites in
          for station in favorites {
            guard let update = byID[station.id] else { continue }
            let refreshed = station.refreshed(from: update)
            if refreshed != station { favorites[id: station.id] = refreshed }
          }
        }
        return .none

      case .removed(let offsets):
        state.$favorites.withLock { $0.remove(atOffsets: offsets) }
        if state.favorites.isEmpty { state.isEditing = false }
        return .none

      case .startRefreshing:
        // Obnoví údaje obľúbených z databázy (nové ikony, zmenené adresy streamov).
        let ids = state.favorites.filter { !$0.isManual }.map(\.id)
        guard !ids.isEmpty else { return .none }
        return .run { send in
          let fresh = try await radioBrowser.stations(ids)
          await send(.refreshResponse(fresh))
        } catch: { _, _ in
          // Bez siete ponecháme uložené údaje.
        }

      case .tileTapped(let station):
        guard !state.isEditing else { return .none }
        if state.playback.isCurrent(station), !state.playback.isFailed {
          return .send(.delegate(.togglePlayPause))
        }
        return .send(.delegate(.play(station, queue: Array(state.favorites))))
      }
    }
  }
}

extension Playback {
  var isFailed: Bool {
    if case .failed = status { return true }
    return false
  }
}
