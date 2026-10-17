import ComposableArchitecture
import Foundation
import L10n
import Models
import SiriClient

@Reducer
public struct Settings: Sendable {
  @ObservableState
  public struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    @Shared(.favorites) var favorites
    var isImporterPresented = false
    var manualName = ""
    var manualURL = ""
    var siriAuthorization: SiriAuthorization = .notDetermined

    public init() {}

    var isManualFormValid: Bool {
      !manualName.trimmingCharacters(in: .whitespaces).isEmpty && Self.streamURL(manualURL) != nil
    }

    static func streamURL(_ text: String) -> URL? {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard let url = URL(string: trimmed),
        let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
        url.host() != nil
      else { return nil }
      return url
    }
  }

  public enum Action: BindableAction {
    case addManualButtonTapped
    case allowSiriButtonTapped
    case alert(PresentationAction<Alert>)
    case binding(BindingAction<State>)
    case importButtonTapped
    case importFileSelected(Result<URL, any Error>)
    case importResponse(Result<[Station], any Error>)
    case onAppear
    case siriAuthorizationResponse(SiriAuthorization)

    public enum Alert: Equatable {}
  }

  @Dependency(\.siri) var siri
  @Dependency(\.uuid) var uuid

  public init() {}

  public var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .addManualButtonTapped:
        guard state.isManualFormValid, let url = State.streamURL(state.manualURL) else {
          return .none
        }
        let station = Station(
          id: "manual-\(uuid().uuidString.lowercased())",
          name: state.manualName.trimmingCharacters(in: .whitespaces),
          url: url
        )
        state.$favorites.withLock { _ = $0.append(station) }
        state.manualName = ""
        state.manualURL = ""
        state.alert = AlertState {
          TextState(L10n.favoritesAddedTitle)
        } message: {
          TextState(L10n.favoritesAddedMessage(station.name))
        }
        return .none

      case .alert, .binding:
        return .none

      case .allowSiriButtonTapped:
        return .run { send in
          await send(.siriAuthorizationResponse(await siri.requestAuthorization()))
        }

      case .onAppear:
        state.siriAuthorization = siri.authorizationStatus()
        return .none

      case .siriAuthorizationResponse(let authorization):
        state.siriAuthorization = authorization
        return .none

      case .importButtonTapped:
        state.isImporterPresented = true
        return .none

      case .importFileSelected(.success(let url)):
        return .run { send in
          await send(
            .importResponse(
              Result {
                let isScoped = url.startAccessingSecurityScopedResource()
                defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
                return try FavoritesBackup.decode(Data(contentsOf: url))
              }
            )
          )
        }

      case .importFileSelected(.failure):
        return .none

      case .importResponse(.success(let stations)):
        let added = state.$favorites.withLock { $0.merge(stations) }
        state.alert = AlertState {
          TextState(L10n.backupImportedTitle)
        } message: {
          TextState(added == 0 ? L10n.backupImportedNone : L10n.backupImportedCount("\(added)"))
        }
        return .none

      case .importResponse(.failure):
        state.alert = AlertState {
          TextState(L10n.backupInvalidTitle)
        } message: {
          TextState(L10n.backupInvalidMessage)
        }
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
