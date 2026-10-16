import Dependencies
import DependenciesMacros
import Foundation
import Models

/// Udalosti prehrávača a systému (zamknutá obrazovka, slúchadlá, CarPlay, prerušenia).
public enum PlayerEvent: Equatable, Sendable {
  /// Stream sa načítava alebo dobieha vyrovnávaciu pamäť.
  case buffering
  /// Stream sa nepodarilo prehrať (alebo skončil).
  case failed(String)
  case playing
  /// Systém pozastavil prehrávanie (hovor, odpojené slúchadlá…).
  case stoppedBySystem
  /// Ovládanie zo zamknutej obrazovky, Control Center, slúchadiel alebo auta.
  case remoteCommand(RemoteCommand)
  /// Názov skladby z ICY metadát streamu.
  case trackTitle(String?)
}

public enum RemoteCommand: Equatable, Sendable {
  case nextTrack
  case pause
  case play
  case previousTrack
  case togglePlayPause
}

@DependencyClient
public struct AudioPlayerClient: Sendable {
  /// Prúd udalostí prehrávača. Volá sa raz pri štarte aplikácie.
  public var events: @Sendable () async -> AsyncStream<PlayerEvent> = { .finished }
  public var play: @Sendable (_ url: URL, _ station: Station) async -> Void
  public var stop: @Sendable () async -> Void
  /// Aktualizuje informácie na zamknutej obrazovke, v Control Center a v CarPlay.
  public var updateNowPlaying: @Sendable (_ playback: Playback) async -> Void
}

extension AudioPlayerClient: DependencyKey {
  public static var liveValue: Self {
    Self(
      events: { await LivePlayer.shared.events() },
      play: { url, station in await LivePlayer.shared.play(url: url, station: station) },
      stop: { await LivePlayer.shared.stop() },
      updateNowPlaying: { await LivePlayer.shared.updateNowPlaying($0) }
    )
  }

  public static var previewValue: Self {
    let continuation = LockIsolatedContinuation()
    return Self(
      events: {
        AsyncStream { continuation.set($0) }
      },
      play: { _, _ in
        continuation.yield(.buffering)
        try? await Task.sleep(for: .milliseconds(600))
        continuation.yield(.playing)
        continuation.yield(.trackTitle("Daft Punk – One More Time"))
      },
      stop: {},
      updateNowPlaying: { _ in }
    )
  }
}

extension DependencyValues {
  public var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClient.self] }
    set { self[AudioPlayerClient.self] = newValue }
  }
}

private final class LockIsolatedContinuation: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: AsyncStream<PlayerEvent>.Continuation?

  func set(_ continuation: AsyncStream<PlayerEvent>.Continuation) {
    lock.withLock { self.continuation = continuation }
  }

  func yield(_ event: PlayerEvent) {
    _ = lock.withLock { continuation?.yield(event) }
  }
}
