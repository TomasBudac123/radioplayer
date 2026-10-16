import Foundation
import L10n

/// Čo práve hrá – zdieľané medzi obrazovkami telefónu a CarPlay.
public struct Playback: Equatable, Sendable {
  public enum Status: Equatable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case failed(String)
  }

  public var station: Station?
  public var status: Status = .idle
  /// Názov skladby zo streamu (ICY metadáta), ak ho rádio posiela.
  public var trackTitle: String?

  public init(station: Station? = nil, status: Status = .idle, trackTitle: String? = nil) {
    self.station = station
    self.status = status
    self.trackTitle = trackTitle
  }

  /// Rádio je „aktívne“ – načítava sa alebo hrá.
  public var isActive: Bool {
    status == .loading || status == .playing
  }

  public func isCurrent(_ station: Station) -> Bool {
    self.station?.id == station.id && status != .idle
  }

  public var statusText: String {
    switch status {
    case .idle: station?.countryName ?? ""
    case .loading: L10n.playerConnecting
    case .playing: [L10n.playerLive, station?.details ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    case .paused: L10n.playerPaused
    case .failed(let message): message
    }
  }
}
