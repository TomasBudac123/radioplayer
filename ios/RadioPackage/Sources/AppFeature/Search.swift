import ComposableArchitecture
import Foundation
import L10n
import Models
import RadioBrowserClient

@Reducer
public struct Search: Sendable {
  @ObservableState
  public struct State: Equatable {
    var countries: [Country] = []
    var countryCode: String?
    var errorMessage: String?
    @Shared(.favorites) var favorites
    var filterPicker: FilterKind?
    var genreTag: String?
    var hasLoaded = false
    var isLoading = false
    var isLoadingMore = false
    var nextOffset = 0
    @Shared(.playback) var playback
    var query = ""
    var results: IdentifiedArrayOf<Station> = []
    var canLoadMore = false

    public init() {}

    var stationQuery: StationQuery {
      StationQuery(name: query, countryCode: countryCode, tag: genreTag, offset: 0)
    }

    var selectedCountry: Country? {
      countries.first { $0.code == countryCode }
    }

    var selectedGenre: Genre? {
      genreTag.flatMap(Genre.named)
    }

    var resultsTitle: String {
      stationQuery.isFiltered || countryCode != nil ? L10n.searchResults : L10n.searchMostPopular
    }
  }

  public enum FilterKind: String, Identifiable, Sendable {
    case country
    case genre
    public var id: Self { self }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case clearFiltersButtonTapped
    case countriesResponse([Country])
    case countryFilterTapped
    case countrySelected(String?)
    case delegate(Delegate)
    case favoriteButtonTapped(Station)
    case genreFilterTapped
    case genreSelected(String?)
    case loadMore
    case onAppear
    case queryDebounced
    case refreshPulled
    case resultTapped(Station)
    case searchResponse(Result<[Station], any Error>, append: Bool)

    @CasePathable
    public enum Delegate {
      case play(Station, queue: [Station])
      case togglePlayPause
    }
  }

  enum CancelID {
    case debounce
    case search
  }

  static let pageSize = 40

  @Dependency(\.continuousClock) var clock
  @Dependency(\.radioBrowser) var radioBrowser

  public init() {}

  public var body: some Reducer<State, Action> {
    BindingReducer()
      .onChange(of: \.query) { _, _ in
        Reduce { _, _ in
          .run { send in
            try await clock.sleep(for: .milliseconds(450))
            await send(.queryDebounced)
          }
          .cancellable(id: CancelID.debounce, cancelInFlight: true)
        }
      }
    Reduce { state, action in
      switch action {
      case .binding, .delegate:
        return .none

      case .clearFiltersButtonTapped:
        state.countryCode = nil
        state.genreTag = nil
        return search(state: &state)

      case .countriesResponse(let countries):
        state.countries = countries
        return .none

      case .countryFilterTapped:
        state.filterPicker = .country
        return .none

      case .countrySelected(let code):
        state.filterPicker = nil
        state.countryCode = code
        return search(state: &state)

      case .favoriteButtonTapped(let station):
        state.$favorites.withLock {
          if $0.remove(id: station.id) == nil { $0.append(station) }
        }
        return .none

      case .genreFilterTapped:
        state.filterPicker = .genre
        return .none

      case .genreSelected(let tag):
        state.filterPicker = nil
        state.genreTag = tag
        return search(state: &state)

      case .loadMore:
        guard state.canLoadMore, !state.isLoading, !state.isLoadingMore else { return .none }
        state.isLoadingMore = true
        var query = state.stationQuery
        query.offset = state.nextOffset
        return .run { [query] send in
          await send(.searchResponse(Result { try await radioBrowser.search(query) }, append: true))
        }
        .cancellable(id: CancelID.search)

      case .onAppear:
        guard !state.hasLoaded else { return .none }
        state.hasLoaded = true
        return .merge(
          search(state: &state),
          .run { send in
            await send(.countriesResponse(try await radioBrowser.countries()))
          } catch: { _, _ in
            // Bez zoznamu krajín sa dá hľadať aj tak – len bez filtra.
          }
        )

      case .queryDebounced:
        return search(state: &state)

      case .refreshPulled:
        return search(state: &state)

      case .resultTapped(let station):
        if state.playback.isCurrent(station), !state.playback.isFailed {
          return .send(.delegate(.togglePlayPause))
        }
        return .send(.delegate(.play(station, queue: Array(state.results))))

      case .searchResponse(.success(let stations), let append):
        state.isLoading = false
        state.isLoadingMore = false
        state.errorMessage = nil
        // Odstránime duplicity (rovnaký stream pod viacerými záznamami).
        var seenURLs = Set(append ? state.results.map(\.url) : [])
        let fresh = stations.filter { seenURLs.insert($0.url).inserted }
        if append {
          state.results.append(contentsOf: fresh.filter { state.results[id: $0.id] == nil })
        } else {
          state.results = IdentifiedArray(fresh, uniquingIDsWith: { first, _ in first })
        }
        state.nextOffset += Self.pageSize
        state.canLoadMore = stations.count == Self.pageSize
        return .none

      case .searchResponse(.failure(let error), _):
        state.isLoading = false
        state.isLoadingMore = false
        guard !(error is CancellationError) else { return .none }
        state.errorMessage = L10n.searchOfflineMessage
        return .none
      }
    }
  }

  private func search(state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil
    state.nextOffset = 0
    let query = state.stationQuery
    return .merge(
      .cancel(id: CancelID.debounce),
      .run { send in
        await send(.searchResponse(Result { try await radioBrowser.search(query) }, append: false))
      }
      .cancellable(id: CancelID.search, cancelInFlight: true)
    )
  }
}
