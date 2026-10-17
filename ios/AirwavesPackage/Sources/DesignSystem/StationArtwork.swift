import Models
import StationImages
import SwiftUI

/// Logo rádia. Kým sa nenačíta (alebo ak žiadne nie je), ukazuje iniciály na neutrálnom pozadí.
public struct StationArtwork: View {
  let station: Station
  let cornerRadius: CGFloat

  @State private var image: UIImage?

  public init(station: Station, cornerRadius: CGFloat = Radius.control) {
    self.station = station
    self.cornerRadius = cornerRadius
    if case .some(.some(let cached)) = StationImageLoader.shared.cached(station) {
      _image = State(initialValue: cached)
    }
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack {
        Color.awSurfaceMuted
        if let image {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .padding(proxy.size.width * 0.12)
            .transition(.opacity)
        } else {
          Text(station.initials)
            .font(.system(size: proxy.size.width * 0.34, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.awTextSecondary)
            .minimumScaleFactor(0.5)
        }
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(.rect(cornerRadius: cornerRadius))
    .overlay {
      RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(Color.awBorder, lineWidth: 0.5)
    }
    .task(id: station.id) { await task() }
    .accessibilityHidden(true)
  }

  private func task() async {
    guard image == nil else { return }
    let loaded = await StationImageLoader.shared.image(for: station)
    withAnimation(.easeOut(duration: 0.2)) { image = loaded }
  }
}

/// Animovaný ekvalizér – znak, že rádio práve hrá.
public struct EqualizerBars: View {
  let isAnimating: Bool
  let color: Color

  public init(isAnimating: Bool, color: Color = .awAccent) {
    self.isAnimating = isAnimating
    self.color = color
  }

  public var body: some View {
    TimelineView(.animation(paused: !isAnimating)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      HStack(alignment: .bottom, spacing: 2) {
        ForEach(0..<4, id: \.self) { index in
          Capsule()
            .fill(color)
            .frame(width: 3)
            .frame(height: barHeight(index: index, time: time))
        }
      }
      .frame(width: 18, height: 14, alignment: .bottom)
    }
    .accessibilityHidden(true)
  }

  private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
    guard isAnimating else { return [6, 10, 8, 5][index] }
    let speeds = [5.1, 6.7, 4.3, 7.9]
    let value = (sin(time * speeds[index] + Double(index)) + 1) / 2
    return 3 + value * 11
  }
}

/// Prázdny stav s ikonou, textom a voliteľnou akciou.
public struct EmptyStateView<Action: View>: View {
  let symbol: String
  let title: String
  let message: String
  let action: Action

  public init(
    symbol: String,
    title: String,
    message: String,
    @ViewBuilder action: () -> Action = { EmptyView() }
  ) {
    self.symbol = symbol
    self.title = title
    self.message = message
    self.action = action()
  }

  public var body: some View {
    VStack(spacing: Spacing.m) {
      Image(systemName: symbol)
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(Color.awTextTertiary)
      VStack(spacing: Spacing.xs) {
        Text(title)
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.awTextPrimary)
        Text(message)
          .font(.subheadline)
          .foregroundStyle(Color.awTextSecondary)
          .multilineTextAlignment(.center)
      }
      action
        .padding(.top, Spacing.xs)
    }
    .padding(Spacing.xl)
    .frame(maxWidth: .infinity)
  }
}
