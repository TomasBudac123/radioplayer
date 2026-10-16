import ProjectDescription

/// Tenký app target – všetka logika je v SPM balíku `RadioPackage`.
let project = Project(
  name: "Radio",
  options: .options(
    defaultKnownRegions: ["en", "sk", "cs", "de", "es", "fr", "it", "pl", "hu", "pt"],
    developmentRegion: "en"
  ),
  packages: [
    .local(path: "RadioPackage")
  ],
  settings: .settings(
    base: [
      "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
      "SWIFT_VERSION": "6.0",
    ]
  ),
  targets: [
    .target(
      name: "Radio",
      destinations: [.iPhone, .iPad],
      product: .app,
      bundleId: "sk.radioplayer.app",
      deploymentTargets: .iOS("18.0"),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Radio",
        "CFBundleDevelopmentRegion": "en",
        "CFBundleAllowMixedLocalizations": true,
        // Siri: „pusti … v Rádiu“ (aj v CarPlay).
        "INIntentsSupported": ["INPlayMediaIntent"],
        "INSupportedMediaCategories": ["INMediaCategoryRadio"],
        "NSSiriUsageDescription": "Siri plays your stations when you ask, for example in the car.",
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "1",
        "ITSAppUsesNonExemptEncryption": false,
        "LSApplicationCategoryType": "public.app-category.music",
        // Mnohé rádiá vysielajú a majú logá len cez http://.
        "NSAppTransportSecurity": [
          "NSAllowsArbitraryLoads": true
        ],
        "UIBackgroundModes": ["audio"],
        "UILaunchScreen": [
          "UIColorName": "LaunchBackground"
        ],
        "UIApplicationSceneManifest": [
          "UIApplicationSupportsMultipleScenes": true,
          "UISceneConfigurations": [
            "CPTemplateApplicationSceneSessionRoleApplication": [
              [
                "UISceneConfigurationName": "CarPlay",
                "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate",
              ]
            ]
          ],
        ],
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "UISupportedInterfaceOrientations~ipad": [
          "UIInterfaceOrientationPortrait",
          "UIInterfaceOrientationPortraitUpsideDown",
          "UIInterfaceOrientationLandscapeLeft",
          "UIInterfaceOrientationLandscapeRight",
        ],
      ]),
      sources: ["App/Sources/**"],
      resources: ["App/Resources/**"],
      entitlements: .file(path: "App/Radio.entitlements"),
      dependencies: [
        .package(product: "AppFeature"),
        .package(product: "CarPlayFeature"),
        .package(product: "SiriFeature"),
      ]
    )
  ]
)
