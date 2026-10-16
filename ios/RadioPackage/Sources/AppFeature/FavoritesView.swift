import ComposableArchitecture
import DesignSystem
import L10n
import Models
import SwiftUI

struct FavoritesView: View {
  @Bindable var store: StoreOf<Favorites>

  var body: some View {
    Group {
      if store.favorites.isEmpty {
        EmptyStateView(
          symbol: "star",
          title: L10n.favoritesEmptyTitle,
          message: L10n.favoritesEmptyMessage
        ) {
          Button(L10n.favoritesEmptyAction) { store.send(.findStationsButtonTapped) }
            .buttonStyle(.rpPrimary)
        }
        .frame(maxHeight: .infinity)
      } else if store.isEditing {
        editingList
      } else {
        grid
      }
    }
    .background(Color.rpBackground)
    .navigationTitle(L10n.tabFavorites)
    .toolbar {
      if !store.favorites.isEmpty {
        ToolbarItem(placement: .topBarTrailing) {
          if store.isEditing {
            Button(L10n.actionDone) { store.send(.doneButtonTapped, animation: .default) }
              .fontWeight(.semibold)
          } else {
            Button(L10n.actionEdit) { store.send(.editButtonTapped, animation: .default) }
          }
        }
      }
    }
  }

  private var grid: some View {
    ScrollView {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 104, maximum: 180), spacing: Spacing.m)],
        spacing: Spacing.l
      ) {
        ForEach(store.favorites) { station in
          FavoriteTile(
            station: station,
            playback: store.playback
          ) {
            store.send(.tileTapped(station))
          }
          .contextMenu {
            Button(L10n.favoritesRemove, systemImage: "star.slash", role: .destructive) {
              store.send(.deleteButtonTapped(station.id), animation: .default)
            }
          }
        }
      }
      .padding(.horizontal, Spacing.m)
      .padding(.vertical, Spacing.s)
    }
    .scrollIndicators(.hidden)
  }

  private var editingList: some View {
    List {
      Section {
        ForEach(store.favorites) { station in
          HStack(spacing: Spacing.s) {
            StationArtwork(station: station, cornerRadius: Radius.small)
              .frame(width: 40, height: 40)
            Text(station.name)
              .font(.body)
              .foregroundStyle(Color.rpTextPrimary)
              .lineLimit(1)
          }
        }
        .onMove { store.send(.moved($0, $1)) }
        .onDelete { store.send(.removed($0), animation: .default) }
      } footer: {
        Text(L10n.favoritesReorderHint)
      }
    }
    .environment(\.editMode, .constant(.active))
    .scrollContentBackground(.hidden)
  }
}

private struct FavoriteTile: View {
  let station: Station
  let playback: Playback
  let action: () -> Void

  private var isCurrent: Bool { playback.isCurrent(station) }

  var body: some View {
    Button(action: action) {
      VStack(spacing: Spacing.xs) {
        StationArtwork(station: station, cornerRadius: Radius.tile)
          .overlay(alignment: .bottomTrailing) {
            if isCurrent {
              statusBadge
                .padding(Spacing.xs)
                .transition(.scale.combined(with: .opacity))
            }
          }
          .overlay {
            RoundedRectangle(cornerRadius: Radius.tile)
              .strokeBorder(Color.rpAccent, lineWidth: isCurrent ? 2 : 0)
          }
        Text(station.name)
          .font(.footnote.weight(isCurrent ? .semibold : .regular))
          .foregroundStyle(Color.rpTextPrimary)
          .lineLimit(2, reservesSpace: true)
          .multilineTextAlignment(.center)
      }
    }
    .buttonStyle(.rpPressable)
    .animation(.snappy, value: isCurrent)
    .accessibilityLabel(station.name)
    .accessibilityValue(isCurrent ? playback.statusText : "")
    .accessibilityHint(isCurrent && playback.isActive ? L10n.playerHintPause : L10n.playerHintPlay)
  }

  @ViewBuilder
  private var statusBadge: some View {
    Group {
      switch playback.status {
      case .loading:
        ProgressView()
          .controlSize(.small)
          .tint(Color.rpOnAccent)
      case .playing:
        EqualizerBars(isAnimating: true, color: .rpOnAccent)
      case .failed:
        Image(systemName: "exclamationmark")
          .font(.caption.weight(.bold))
          .foregroundStyle(Color.rpOnAccent)
      case .idle, .paused:
        Image(systemName: "pause.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(Color.rpOnAccent)
      }
    }
    .frame(width: 30, height: 30)
    .background(Color.rpAccent, in: .circle)
  }
}

#Preview {
  let _ = prepareDependencies {
    $0.defaultFileStorage = .inMemory
  }
  let _ = Shared(.favorites).withLock { $0 = IdentifiedArray(uniqueElements: Station.previews) }
  NavigationStack {
    FavoritesView(store: Store(initialState: Favorites.State()) { Favorites() })
  }
}
