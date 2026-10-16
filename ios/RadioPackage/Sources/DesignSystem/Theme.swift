import SwiftUI
import UIKit

/// Neutrálna paleta zdieľaná s Android aplikáciou (`design/tokens.json`).
/// Farbu do rozhrania prinášajú len logá rádií.
extension Color {
  public static let rpBackground = Color(light: 0xF6F6F7, dark: 0x0D0D0F)
  public static let rpSurface = Color(light: 0xFFFFFF, dark: 0x17171A)
  public static let rpSurfaceMuted = Color(light: 0xEDEDEF, dark: 0x222226)
  public static let rpBorder = Color(light: 0xE2E2E5, dark: 0x2D2D32)
  public static let rpTextPrimary = Color(light: 0x17171A, dark: 0xF3F3F5)
  public static let rpTextSecondary = Color(light: 0x62626B, dark: 0xA3A3AB)
  public static let rpTextTertiary = Color(light: 0x9C9CA4, dark: 0x6C6C74)
  public static let rpAccent = Color(light: 0x17171A, dark: 0xF3F3F5)
  public static let rpOnAccent = Color(light: 0xFFFFFF, dark: 0x0D0D0F)
  public static let rpDanger = Color(light: 0xB42318, dark: 0xF97066)
}

extension UIColor {
  public static let rpAccent = UIColor(light: 0x17171A, dark: 0xF3F3F5)
  public static let rpBackground = UIColor(light: 0xF6F6F7, dark: 0x0D0D0F)
  public static let rpTextPrimary = UIColor(light: 0x17171A, dark: 0xF3F3F5)
  public static let rpTextSecondary = UIColor(light: 0x62626B, dark: 0xA3A3AB)
  public static let rpSurfaceMuted = UIColor(light: 0xEDEDEF, dark: 0x222226)

  convenience init(light: UInt32, dark: UInt32) {
    self.init { traits in
      UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
    }
  }

  convenience init(hex: UInt32) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}

extension Color {
  init(light: UInt32, dark: UInt32) {
    self.init(uiColor: UIColor(light: light, dark: dark))
  }
}

public enum Spacing {
  public static let xxs: CGFloat = 4
  public static let xs: CGFloat = 8
  public static let s: CGFloat = 12
  public static let m: CGFloat = 16
  public static let l: CGFloat = 24
  public static let xl: CGFloat = 32
}

public enum Radius {
  public static let small: CGFloat = 8
  public static let control: CGFloat = 12
  public static let card: CGFloat = 16
  public static let tile: CGFloat = 20
  public static let artworkLarge: CGFloat = 28
}

/// Plné tlačidlo v neutrálnej akcentovej farbe.
public struct PrimaryButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.body.weight(.semibold))
      .foregroundStyle(Color.rpOnAccent)
      .padding(.horizontal, Spacing.l)
      .padding(.vertical, Spacing.s)
      .frame(minHeight: 44)
      .background(Color.rpAccent, in: .capsule)
      .opacity(configuration.isPressed ? 0.8 : 1)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.snappy(duration: 0.15), value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
  public static var rpPrimary: Self { PrimaryButtonStyle() }
}

/// Jemné zmenšenie pri stlačení dlaždice.
public struct PressableButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.snappy(duration: 0.18), value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == PressableButtonStyle {
  public static var rpPressable: Self { PressableButtonStyle() }
}
