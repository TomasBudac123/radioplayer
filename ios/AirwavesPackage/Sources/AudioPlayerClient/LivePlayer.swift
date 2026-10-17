@preconcurrency import AVFoundation
import Combine
import MediaPlayer
import Models
import StationImages
import UIKit

/// AVPlayer + systémové integrácie (audio session, Now Playing, vzdialené ovládanie).
@MainActor
final class LivePlayer: NSObject {
  static let shared = LivePlayer()

  private let player = AVPlayer()
  private var continuations: [UUID: AsyncStream<PlayerEvent>.Continuation] = [:]
  private var cancellables: Set<AnyCancellable> = []
  private var itemCancellables: Set<AnyCancellable> = []
  private var metadataOutput: AVPlayerItemMetadataOutput?
  private lazy var metadataDelegate = MetadataDelegate { title in
    LivePlayer.shared.send(.trackTitle(title))
  }
  /// Zastavenie, ktoré sme si vyžiadali sami – nehlásime ho ako „pozastavené systémom“.
  private var isStopping = false
  private var artworkTask: Task<Void, Never>?
  private var artworkStationID: String?
  private var artwork: MPMediaItemArtwork?
  private var isConfigured = false

  func events() -> AsyncStream<PlayerEvent> {
    configureIfNeeded()
    let (stream, continuation) = AsyncStream<PlayerEvent>.makeStream(bufferingPolicy: .unbounded)
    let id = UUID()
    continuations[id] = continuation
    continuation.onTermination = { _ in
      Task { @MainActor in LivePlayer.shared.continuations[id] = nil }
    }
    return stream
  }

  func play(url: URL, station: Station) {
    configureIfNeeded()
    activateSession()
    isStopping = false
    let asset = AVURLAsset(url: url)
    let item = AVPlayerItem(asset: asset)
    observe(item)
    player.replaceCurrentItem(with: item)
    player.play()
    send(.buffering)
  }

  func stop() {
    isStopping = true
    player.pause()
    player.replaceCurrentItem(with: nil)
    itemCancellables.removeAll()
    metadataOutput = nil
  }

  func updateNowPlaying(_ playback: Playback) {
    let center = MPNowPlayingInfoCenter.default()
    guard let station = playback.station else {
      center.nowPlayingInfo = nil
      return
    }
    var info: [String: Any] = [
      MPNowPlayingInfoPropertyIsLiveStream: true,
      MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
      MPNowPlayingInfoPropertyPlaybackRate: playback.status == .playing ? 1.0 : 0.0,
    ]
    if let title = playback.trackTitle {
      info[MPMediaItemPropertyTitle] = title
      info[MPMediaItemPropertyArtist] = station.name
    } else {
      info[MPMediaItemPropertyTitle] = station.name
      info[MPMediaItemPropertyArtist] = playback.statusText
    }
    if artworkStationID == station.id, let artwork {
      info[MPMediaItemPropertyArtwork] = artwork
    } else {
      loadArtwork(for: station, playback: playback)
    }
    center.nowPlayingInfo = info
  }

  // MARK: - Private

  private func configureIfNeeded() {
    guard !isConfigured else { return }
    isConfigured = true
    player.automaticallyWaitsToMinimizeStalling = true

    player.publisher(for: \.timeControlStatus)
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] status in
        MainActor.assumeIsolated { self?.timeControlStatusChanged(status) }
      }
      .store(in: &cancellables)

    NotificationCenter.default
      .publisher(for: AVAudioSession.interruptionNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] notification in
        let info = notification.userInfo
        MainActor.assumeIsolated { self?.interruption(info) }
      }
      .store(in: &cancellables)

    configureRemoteCommands()
  }

  private func activateSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, policy: .longFormAudio)
    try? session.setActive(true)
  }

  private func observe(_ item: AVPlayerItem) {
    itemCancellables.removeAll()

    item.publisher(for: \.status)
      .receive(on: DispatchQueue.main)
      .sink { [weak self, weak item] status in
        MainActor.assumeIsolated {
          guard status == .failed else { return }
          self?.send(.failed(item?.error?.localizedDescription ?? "Stream failed"))
        }
      }
      .store(in: &itemCancellables)

    NotificationCenter.default
      .publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
      .merge(with: NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item))
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        MainActor.assumeIsolated { self?.send(.failed("Stream ended")) }
      }
      .store(in: &itemCancellables)

    let output = AVPlayerItemMetadataOutput(identifiers: nil)
    output.setDelegate(metadataDelegate, queue: .main)
    item.add(output)
    metadataOutput = output
  }

  private func timeControlStatusChanged(_ status: AVPlayer.TimeControlStatus) {
    switch status {
    case .playing:
      send(.playing)
    case .waitingToPlayAtSpecifiedRate:
      if player.currentItem != nil { send(.buffering) }
    case .paused:
      if !isStopping, player.currentItem?.status == .readyToPlay {
        send(.stoppedBySystem)
      }
    @unknown default:
      break
    }
  }

  private func interruption(_ userInfo: [AnyHashable: Any]?) {
    guard let rawType = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType)
    else { return }
    switch type {
    case .began:
      send(.stoppedBySystem)
    case .ended:
      let rawOptions = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
      if AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) {
        // Po hovore sa rádio samo pripojí znova.
        send(.remoteCommand(.play))
      }
    @unknown default:
      break
    }
  }

  private func configureRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()
    let commands: [(MPRemoteCommand, RemoteCommand)] = [
      (center.playCommand, .play),
      (center.pauseCommand, .pause),
      (center.stopCommand, .pause),
      (center.togglePlayPauseCommand, .togglePlayPause),
      (center.nextTrackCommand, .nextTrack),
      (center.previousTrackCommand, .previousTrack),
    ]
    for (command, remote) in commands {
      command.isEnabled = true
      command.addTarget { _ in
        MainActor.assumeIsolated { LivePlayer.shared.send(.remoteCommand(remote)) }
        return .success
      }
    }
    for command in [
      center.seekForwardCommand, center.seekBackwardCommand, center.skipForwardCommand,
      center.skipBackwardCommand, center.changePlaybackPositionCommand,
    ] {
      command.isEnabled = false
    }
  }

  private func loadArtwork(for station: Station, playback: Playback) {
    guard artworkStationID != station.id else { return }
    artworkStationID = station.id
    artwork = nil
    artworkTask?.cancel()
    artworkTask = Task { [weak self] in
      let image = await StationImageLoader.shared.image(for: station)
        ?? UIImage(named: "AppIcon")
      guard !Task.isCancelled, let image, let self else { return }
      self.artwork = Self.artwork(image)
      var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
      info[MPMediaItemPropertyArtwork] = self.artwork
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
  }

  /// MediaPlayer volá blok z pozadia – nesmie zdediť izoláciu hlavného vlákna.
  private nonisolated static func artwork(_ image: UIImage) -> MPMediaItemArtwork {
    MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
  }

  fileprivate func send(_ event: PlayerEvent) {
    for continuation in continuations.values {
      continuation.yield(event)
    }
  }
}

/// Číta ICY metadáta (názov skladby) zo streamu.
private final class MetadataDelegate: NSObject, AVPlayerItemMetadataOutputPushDelegate, Sendable {
  private let onTitle: @Sendable @MainActor (String?) -> Void

  init(onTitle: @escaping @Sendable @MainActor (String?) -> Void) {
    self.onTitle = onTitle
  }

  func metadataOutput(
    _ output: AVPlayerItemMetadataOutput,
    didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
    from track: AVPlayerItemTrack?
  ) {
    let items = groups.flatMap(\.items)
    let item =
      items.first { $0.identifier == .icyMetadataStreamTitle }
      ?? items.first { $0.commonKey == .commonKeyTitle }
    guard let item else { return }
    Task { [onTitle] in
      let value = try? await item.load(.stringValue)
      let title = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-– "))
      await onTitle(title?.isEmpty == false ? title : nil)
    }
  }
}
