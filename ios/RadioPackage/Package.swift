// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "RadioPackage",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v18)
  ],
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "CarPlayFeature", targets: ["CarPlayFeature"]),
    .library(name: "SiriFeature", targets: ["SiriFeature"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.20.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0"),
    .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.0"),
    .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.0.0"),
  ],
  targets: [
    .target(
      name: "AppFeature",
      dependencies: [
        "AudioPlayerClient",
        "DesignSystem",
        "L10n",
        "Models",
        "RadioBrowserClient",
        "SiriClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "AudioPlayerClient",
      dependencies: [
        "Models",
        "StationImages",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "CarPlayFeature",
      dependencies: [
        "AppFeature",
        "L10n",
        "StationImages",
        .product(name: "UIKitNavigation", package: "swift-navigation"),
      ]
    ),
    .target(
      name: "DesignSystem",
      dependencies: [
        "L10n",
        "Models",
        "StationImages",
      ]
    ),
    .target(
      name: "L10n",
      resources: [.process("Resources")]
    ),
    .target(
      name: "Models",
      dependencies: [
        "L10n",
        .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
      ]
    ),
    .target(
      name: "RadioBrowserClient",
      dependencies: [
        "L10n",
        "Models",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "SiriClient",
      dependencies: [
        "Models",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "SiriFeature",
      dependencies: [
        "AppFeature"
      ]
    ),
    .target(
      name: "StationImages",
      dependencies: [
        "Models"
      ]
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "SiriFeatureTests",
      dependencies: [
        "SiriFeature",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "ModelsTests",
      dependencies: [
        "Models"
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
