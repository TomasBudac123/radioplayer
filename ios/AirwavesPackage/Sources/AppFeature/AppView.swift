import ComposableArchitecture
import DesignSystem
import L10n
import Models
import SwiftUI

public struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>

  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  public var body: some View {
    TabView(selection: $store.selectedTab) {
      Tab(L10n.tabFavorites, systemImage: "star.fill", value: AppFeature.Tab.favorites) {
        NavigationStack {
          FavoritesView(store: store.scope(state: \.favorites, action: \.favorites))
            .modifier(LegacyMiniPlayerInset(store: store))
        }
      }
      Tab(L10n.tabSearch, systemImage: "magnifyingglass", value: AppFeature.Tab.search) {
        NavigationStack {
          SearchView(store: store.scope(state: \.search, action: \.search))
            .modifier(LegacyMiniPlayerInset(store: store))
        }
      }
      Tab(L10n.tabSettings, systemImage: "gearshape", value: AppFeature.Tab.settings) {
        NavigationStack {
          SettingsView(store: store.scope(state: \.settings, action: \.settings))
            .modifier(LegacyMiniPlayerInset(store: store))
        }
      }
    }
    .modifier(BottomAccessoryMiniPlayer(store: store))
    .tint(Color.awAccent)
    .sheet(isPresented: $store.isNowPlayingPresented) {
      NowPlayingView(store: store.scope(state: \.player, action: \.player)) {
        store.send(.nowPlayingDismissButtonTapped)
      }
    }
  }
}

/// iOS 26+: mini prehrávač nad panelom kariet (Liquid Glass), ako v Hudbe či Podcastoch.
private struct BottomAccessoryMiniPlayer: ViewModifier {
  let store: StoreOf<AppFeature>

  func body(content: Content) -> some View {
    if #available(iOS 26.1, *) {
      content
        .tabViewBottomAccessory(isEnabled: store.player.playback.station != nil) {
          MiniPlayerView(store: store.scope(state: \.player, action: \.player), style: .accessory) {
            store.send(.miniPlayerTapped)
          }
        }
    } else {
      content
    }
  }
}

/// Staršie systémy: mini prehrávač ako plávajúca karta nad obsahom každej karty.
private struct LegacyMiniPlayerInset: ViewModifier {
  let store: StoreOf<AppFeature>

  func body(content: Content) -> some View {
    if #available(iOS 26.1, *) {
      content
    } else {
      content.safeAreaInset(edge: .bottom) {
        if store.player.playback.station != nil {
          MiniPlayerView(store: store.scope(state: \.player, action: \.player), style: .card) {
            store.send(.miniPlayerTapped)
          }
          .padding(.horizontal, Spacing.xs)
          .padding(.bottom, Spacing.xxs)
        }
      }
    }
  }
}

#Preview {
  let _ = prepareDependencies {
    $0.defaultFileStorage = .inMemory
  }
  let store = Store(initialState: AppFeature.State()) { AppFeature() }
  AppView(store: store)
    .task { store.send(.appDidLaunch) }
}
