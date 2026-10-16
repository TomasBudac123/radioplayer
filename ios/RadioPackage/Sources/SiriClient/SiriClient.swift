import Dependencies
import DependenciesMacros
import Foundation
@preconcurrency import Intents
import Models

public enum SiriAuthorization: Equatable, Sendable {
  case authorized
  case denied
  case notDetermined
}

/// Prístup k Siri: povolenie a „darovanie“ prehratých rádií, aby ich Siri lepšie rozpoznávala
/// a ponúkala v návrhoch.
@DependencyClient
public struct SiriClient: Sendable {
  public var authorizationStatus: @Sendable () -> SiriAuthorization = { .notDetermined }
  public var donatePlay: @Sendable (_ station: Station) async -> Void
  public var requestAuthorization: @Sendable () async -> SiriAuthorization = { .notDetermined }
}

extension SiriClient: DependencyKey {
  public static var liveValue: Self {
    Self(
      authorizationStatus: { SiriAuthorization(INPreferences.siriAuthorizationStatus()) },
      donatePlay: { station in
        let item = INMediaItem(station)
        let intent = INPlayMediaIntent(
          mediaItems: [item],
          mediaContainer: nil,
          playShuffled: false,
          playbackRepeatMode: .none,
          resumePlayback: false,
          playbackQueueLocation: .now,
          playbackSpeed: nil,
          mediaSearch: INMediaSearch(mediaType: .radioStation, mediaName: station.name)
        )
        let interaction = INInteraction(
          intent: intent,
          response: INPlayMediaIntentResponse(code: .success, userActivity: nil)
        )
        try? await interaction.donate()
      },
      requestAuthorization: {
        await withCheckedContinuation { continuation in
          INPreferences.requestSiriAuthorization { status in
            continuation.resume(returning: SiriAuthorization(status))
          }
        }
      }
    )
  }

  public static var previewValue: Self {
    Self(
      authorizationStatus: { .notDetermined },
      donatePlay: { _ in },
      requestAuthorization: { .authorized }
    )
  }
}

extension DependencyValues {
  public var siri: SiriClient {
    get { self[SiriClient.self] }
    set { self[SiriClient.self] = newValue }
  }
}

extension SiriAuthorization {
  init(_ status: INSiriAuthorizationStatus) {
    switch status {
    case .authorized: self = .authorized
    case .denied, .restricted: self = .denied
    case .notDetermined: self = .notDetermined
    @unknown default: self = .notDetermined
    }
  }
}

extension INMediaItem {
  /// Rádio ako položka pre Siri; identifikátor je ID z Radio Browser (alebo `manual-…`).
  public convenience init(_ station: Station) {
    self.init(
      identifier: station.id,
      title: station.name,
      type: .radioStation,
      artwork: nil,
      artist: station.countryName.isEmpty ? nil : station.countryName
    )
  }
}
