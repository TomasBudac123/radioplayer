import DesignSystem
import L10n
import Models
import SwiftUI

/// Riadok rádia vo výsledkoch hľadania.
struct StationRow: View {
  let station: Station
  let playback: Playback
  let isFavorite: Bool
  let playAction: () -> Void
  let favoriteAction: () -> Void

  private var isCurrent: Bool { playback.isCurrent(station) }

  var body: some View {
    HStack(spacing: Spacing.s) {
      Button(action: playAction) {
        HStack(spacing: Spacing.s) {
          StationArtwork(station: station, cornerRadius: Radius.control)
            .frame(width: 48, height: 48)
          VStack(alignment: .leading, spacing: 2) {
            Text(station.name)
              .font(.body.weight(isCurrent ? .semibold : .regular))
              .foregroundStyle(Color.rpTextPrimary)
              .lineLimit(1)
            Text(isCurrent ? playback.statusText : station.subtitle)
              .font(.footnote)
              .foregroundStyle(playback.isFailed && isCurrent ? Color.rpDanger : Color.rpTextSecondary)
              .lineLimit(1)
          }
          Spacer(minLength: 0)
          if isCurrent {
            indicator
          }
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(station.name)
      .accessibilityValue(isCurrent ? playback.statusText : station.subtitle)

      Button(action: favoriteAction) {
        Image(systemName: isFavorite ? "star.fill" : "star")
          .font(.body.weight(.medium))
          .foregroundStyle(isFavorite ? Color.rpAccent : Color.rpTextTertiary)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
          .contentTransition(.symbolEffect(.replace))
      }
      .buttonStyle(.plain)
      .sensoryFeedback(.selection, trigger: isFavorite)
      .accessibilityLabel(isFavorite ? L10n.favoritesRemove : L10n.favoritesAdd)
    }
    .padding(.vertical, Spacing.xxs)
  }

  @ViewBuilder
  private var indicator: some View {
    switch playback.status {
    case .loading:
      ProgressView().controlSize(.small)
    case .playing:
      EqualizerBars(isAnimating: true)
    case .paused, .idle:
      EqualizerBars(isAnimating: false, color: .rpTextTertiary)
    case .failed:
      Image(systemName: "exclamationmark.circle")
        .foregroundStyle(Color.rpDanger)
    }
  }
}
