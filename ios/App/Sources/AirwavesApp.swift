import AppFeature
import ComposableArchitecture
@preconcurrency import Intents
import SiriFeature
import SwiftUI
import UIKit

@main
struct AirwavesApp: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup {
      AppView(store: AppDelegate.store)
    }
  }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
  /// Jeden store pre telefón aj CarPlay – appka sa môže spustiť priamo z auta bez okna v telefóne.
  @MainActor static let store = Store(initialState: AppFeature.State()) {
    AppFeature()
  }

  /// „Siri, pusti … v Airwaves“ – v telefóne aj v CarPlay.
  @MainActor static let voiceControl = VoiceControl(store: store)

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    Self.store.send(.appDidLaunch)
    return true
  }

  func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
    intent is INPlayMediaIntent ? Self.voiceControl : nil
  }

  func application(
    _ application: UIApplication,
    handle intent: INIntent,
    completionHandler: @escaping (INIntentResponse) -> Void
  ) {
    guard let intent = intent as? INPlayMediaIntent else {
      completionHandler(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
      return
    }
    Task {
      completionHandler(await Self.voiceControl.play(intent))
    }
  }
}
