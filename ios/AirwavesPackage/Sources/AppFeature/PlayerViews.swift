import AVKit
import ComposableArchitecture
import DesignSystem
import L10n
import Models
import SwiftUI

/// Kompaktný prehrávač nad panelom kariet.
struct MiniPlayerView: View {
  enum Style {
    /// Obsah `tabViewBottomAccessory` – pozadie kreslí systém.
    case accessory
    /// Plávajúca karta pre staršie systémy.
    case card
  }

  let store: StoreOf<Player>
  let style: Style
  let openAction: () -> Void

  var body: some View {
    if let station = store.playback.station {
      HStack(spacing: Spacing.s) {
        Button(action: openAction) {
          HStack(spacing: Spacing.s) {
            StationArtwork(station: station, cornerRadius: Radius.small)
              .frame(width: style == .card ? 40 : 32, height: style == .card ? 40 : 32)
            VStack(alignment: .leading, spacing: 1) {
              Text(station.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.awTextPrimary)
                .lineLimit(1)
              Text(store.playback.trackTitle ?? store.playback.statusText)
                .font(.caption)
                .foregroundStyle(store.playback.isFailed ? Color.awDanger : Color.awTextSecondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
          }
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.playerNowPlaying(station.name))
        .accessibilityHint(L10n.playerOpensPlayer)

        PlayPauseButton(playback: store.playback, size: .small) {
          store.send(.togglePlayPauseButtonTapped)
        }
      }
      .padding(.leading, style == .card ? Spacing.xs : Spacing.s)
      .padding(.trailing, Spacing.xxs)
      .padding(.vertical, style == .card ? Spacing.xs : 0)
      .background {
        if style == .card {
          RoundedRectangle(cornerRadius: Radius.card)
            .fill(.regularMaterial)
            .overlay {
              RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.awBorder, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
      }
    }
  }
}

struct PlayPauseButton: View {
  enum Size {
    case small
    case large

    var diameter: CGFloat { self == .small ? 44 : 76 }
    var iconFont: Font { self == .small ? .title3 : .system(size: 30, weight: .semibold) }
  }

  let playback: Playback
  let size: Size
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        if size == .large {
          Circle().fill(Color.awAccent)
        }
        if playback.status == .loading {
          ProgressView()
            .tint(size == .large ? Color.awOnAccent : Color.awTextPrimary)
        } else {
          Image(systemName: playback.isActive ? "pause.fill" : "play.fill")
            .font(size.iconFont)
            .foregroundStyle(size == .large ? Color.awOnAccent : Color.awTextPrimary)
            .contentTransition(.symbolEffect(.replace))
        }
      }
      .frame(width: size.diameter, height: size.diameter)
      .contentShape(.circle)
    }
    .buttonStyle(.awPressable)
    .sensoryFeedback(.impact(weight: .light), trigger: playback.isActive)
    .accessibilityLabel(playback.isActive ? L10n.playerPause : L10n.playerPlay)
  }
}

/// Celoobrazovkový prehrávač.
struct NowPlayingView: View {
  let store: StoreOf<Player>
  let dismissAction: () -> Void

  var body: some View {
    if let station = store.playback.station {
      VStack(spacing: 0) {
        Capsule()
          .fill(Color.awBorder)
          .frame(width: 40, height: 5)
          .padding(.top, Spacing.xs)
          .accessibilityHidden(true)

        HStack {
          Button(action: dismissAction) {
            Image(systemName: "chevron.down")
              .font(.body.weight(.semibold))
              .foregroundStyle(Color.awTextPrimary)
              .frame(width: 44, height: 44)
          }
          .accessibilityLabel(L10n.playerClosePlayer)
          Spacer()
          Text(L10n.playerLive)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(Color.awTextSecondary)
          Spacer()
          RoutePicker()
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, Spacing.s)

        Spacer(minLength: Spacing.l)

        StationArtwork(station: station, cornerRadius: Radius.artworkLarge)
          .frame(maxWidth: 320)
          .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
          .scaleEffect(store.playback.status == .playing ? 1 : 0.94)
          .animation(.spring(duration: 0.45, bounce: 0.25), value: store.playback.status)
          .padding(.horizontal, Spacing.xl)

        Spacer(minLength: Spacing.l)

        HStack(alignment: .top, spacing: Spacing.m) {
          VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(station.name)
              .font(.title2.weight(.bold))
              .foregroundStyle(Color.awTextPrimary)
              .lineLimit(2)
            Text(store.playback.trackTitle ?? station.tags.capitalized)
              .font(.body)
              .foregroundStyle(Color.awTextSecondary)
              .lineLimit(2)
              .contentTransition(.opacity)
              .animation(.default, value: store.playback.trackTitle)
            Text(store.playback.statusText)
              .font(.footnote)
              .foregroundStyle(store.playback.isFailed ? Color.awDanger : Color.awTextTertiary)
              .lineLimit(1)
          }
          Spacer(minLength: 0)
          Button {
            store.send(.favoriteButtonTapped)
          } label: {
            Image(systemName: store.isFavorite ? "star.fill" : "star")
              .font(.title2)
              .foregroundStyle(store.isFavorite ? Color.awAccent : Color.awTextSecondary)
              .frame(width: 44, height: 44)
              .contentTransition(.symbolEffect(.replace))
          }
          .sensoryFeedback(.selection, trigger: store.isFavorite)
          .accessibilityLabel(store.isFavorite ? L10n.favoritesRemove : L10n.favoritesAdd)
        }
        .padding(.horizontal, Spacing.l)

        HStack(spacing: Spacing.xl) {
          Button {
            store.send(.previousButtonTapped)
          } label: {
            Image(systemName: "backward.fill")
              .font(.title)
              .frame(width: 64, height: 64)
          }
          .disabled(!store.canSkip)
          .opacity(store.canSkip ? 1 : 0.3)
          .accessibilityLabel(L10n.playerPrevious)

          PlayPauseButton(playback: store.playback, size: .large) {
            store.send(.togglePlayPauseButtonTapped)
          }

          Button {
            store.send(.nextButtonTapped)
          } label: {
            Image(systemName: "forward.fill")
              .font(.title)
              .frame(width: 64, height: 64)
          }
          .disabled(!store.canSkip)
          .opacity(store.canSkip ? 1 : 0.3)
          .accessibilityLabel(L10n.playerNext)
        }
        .buttonStyle(.awPressable)
        .foregroundStyle(Color.awTextPrimary)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.xl)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.awBackground)
      .presentationDragIndicator(.hidden)
    }
  }
}

/// AirPlay / Bluetooth výber výstupu.
private struct RoutePicker: UIViewRepresentable {
  func makeUIView(context: Context) -> AVRoutePickerView {
    let view = AVRoutePickerView()
    view.tintColor = .awTextPrimary
    view.activeTintColor = .awAccent
    view.prioritizesVideoDevices = false
    return view
  }

  func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
