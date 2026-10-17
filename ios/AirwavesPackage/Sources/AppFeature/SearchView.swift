import ComposableArchitecture
import DesignSystem
import L10n
import Models
import SwiftUI

struct SearchView: View {
  @Bindable var store: StoreOf<Search>

  var body: some View {
    List {
      Section {
        filters
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }

      Section {
        content
      } header: {
        if !store.results.isEmpty {
          Text(store.resultsTitle)
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color.awBackground)
    .navigationTitle(L10n.tabSearch)
    .searchable(
      text: $store.query,
      placement: .navigationBarDrawer(displayMode: .always),
      prompt: L10n.searchPrompt
    )
    .autocorrectionDisabled()
    .onSubmit(of: .search) { store.send(.queryDebounced) }
    .refreshable { await store.send(.refreshPulled).finish() }
    .onAppear { store.send(.onAppear) }
    .sheet(item: $store.filterPicker) { kind in
      FilterPicker(kind: kind, store: store)
    }
  }

  @ViewBuilder
  private var content: some View {
    if let message = store.errorMessage, store.results.isEmpty {
      EmptyStateView(symbol: "wifi.slash", title: L10n.searchOfflineTitle, message: message) {
        Button(L10n.actionRetry) { store.send(.refreshPulled) }
          .buttonStyle(.awPrimary)
      }
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
    } else if store.isLoading && store.results.isEmpty {
      ForEach(0..<8, id: \.self) { _ in
        StationRow(
          station: .placeholder, playback: Playback(), isFavorite: false,
          playAction: {}, favoriteAction: {}
        )
        .redacted(reason: .placeholder)
        .listRowBackground(Color.clear)
      }
    } else if store.results.isEmpty {
      EmptyStateView(
        symbol: "magnifyingglass",
        title: L10n.searchNoResultsTitle,
        message: L10n.searchNoResultsMessage
      )
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
    } else {
      ForEach(store.results) { station in
        StationRow(
          station: station,
          playback: store.playback,
          isFavorite: store.favorites[id: station.id] != nil,
          playAction: { store.send(.resultTapped(station)) },
          favoriteAction: { store.send(.favoriteButtonTapped(station)) }
        )
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(Color.awBorder)
        .onAppear {
          if station.id == store.results.last?.id { store.send(.loadMore) }
        }
      }
      if store.isLoadingMore {
        ProgressView()
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }
    }
  }

  private var filters: some View {
    ScrollView(.horizontal) {
      HStack(spacing: Spacing.xs) {
        FilterChip(
          title: store.selectedCountry.map { "\($0.flag) \($0.name)" } ?? L10n.searchWholeWorld,
          symbol: store.selectedCountry == nil ? "globe" : nil,
          isActive: store.countryCode != nil
        ) {
          store.send(.countryFilterTapped)
        }
        FilterChip(
          title: store.selectedGenre?.name ?? L10n.searchAllGenres,
          symbol: "music.note.list",
          isActive: store.genreTag != nil
        ) {
          store.send(.genreFilterTapped)
        }
        if store.countryCode != nil || store.genreTag != nil {
          Button(L10n.searchClearFilters) { store.send(.clearFiltersButtonTapped) }
            .font(.subheadline)
            .foregroundStyle(Color.awTextSecondary)
            .padding(.horizontal, Spacing.xs)
        }
      }
      .padding(.horizontal, Spacing.m)
      .padding(.vertical, Spacing.xs)
    }
    .scrollIndicators(.hidden)
  }
}

private struct FilterChip: View {
  let title: String
  let symbol: String?
  let isActive: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let symbol {
          Image(systemName: symbol)
        }
        Text(title)
          .lineLimit(1)
        Image(systemName: "chevron.down")
          .font(.caption2.weight(.semibold))
      }
      .font(.subheadline.weight(.medium))
      .foregroundStyle(isActive ? Color.awOnAccent : Color.awTextPrimary)
      .padding(.horizontal, Spacing.s)
      .frame(minHeight: 36)
      .background(isActive ? Color.awAccent : Color.awSurface, in: .capsule)
      .overlay {
        Capsule().strokeBorder(isActive ? Color.clear : Color.awBorder)
      }
    }
    .buttonStyle(.awPressable)
  }
}

/// Výber krajiny alebo žánru s vyhľadávaním.
private struct FilterPicker: View {
  let kind: Search.FilterKind
  let store: StoreOf<Search>
  @State private var filterText = ""
  @Environment(\.dismiss) private var dismiss

  private struct Option: Identifiable {
    let id: String?
    let title: String
    let detail: String?
  }

  private var options: [Option] {
    let all: [Option]
    switch kind {
    case .country:
      all =
        [Option(id: nil, title: "🌍 \(L10n.searchWholeWorld)", detail: nil)]
        + store.countries.map {
          Option(id: $0.code, title: "\($0.flag) \($0.name)", detail: "\($0.stationCount)")
        }
    case .genre:
      all =
        [Option(id: nil, title: L10n.searchAllGenres, detail: nil)]
        + Genre.all.map { Option(id: $0.tag, title: $0.name, detail: nil) }
    }
    let text = filterText.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else { return all }
    return all.filter {
      $0.title.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
  }

  private var selectedID: String? {
    kind == .country ? store.countryCode : store.genreTag
  }

  var body: some View {
    NavigationStack {
      List(options) { option in
        Button {
          optionTapped(option)
        } label: {
          HStack {
            Text(option.title)
              .foregroundStyle(Color.awTextPrimary)
            Spacer()
            if let detail = option.detail {
              Text(detail)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Color.awTextTertiary)
            }
            if option.id == selectedID {
              Image(systemName: "checkmark")
                .fontWeight(.semibold)
                .foregroundStyle(Color.awAccent)
            }
          }
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
      }
      .listStyle(.plain)
      .searchable(
        text: $filterText,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: kind == .country ? L10n.searchFindCountry : L10n.searchFindGenre
      )
      .navigationTitle(kind == .country ? L10n.searchCountry : L10n.searchGenre)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.actionClose) { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  private func optionTapped(_ option: Option) {
    switch kind {
    case .country: store.send(.countrySelected(option.id))
    case .genre: store.send(.genreSelected(option.id))
    }
  }
}

extension Station {
  static let placeholder = Station(
    id: "placeholder", name: L10n.stationLoading, url: URL(string: "https://example.com")!,
    countrycode: "SK", tags: "pop, rock", bitrate: 128
  )
}

#Preview {
  NavigationStack {
    SearchView(store: Store(initialState: Search.State()) { Search() })
  }
}
