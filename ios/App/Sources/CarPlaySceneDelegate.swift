import CarPlay
import CarPlayFeature
import UIKit

/// Scéna CarPlay – registrovaná v Info.plist (`CPTemplateApplicationSceneSessionRoleApplication`).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  private var controller: CarPlayController?

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    let controller = CarPlayController(interfaceController: interfaceController, store: AppDelegate.store)
    controller.connect()
    self.controller = controller
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnectInterfaceController interfaceController: CPInterfaceController
  ) {
    controller?.disconnect()
    controller = nil
  }
}
