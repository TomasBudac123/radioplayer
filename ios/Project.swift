import ProjectDescription

/// Bundle ID musí byť unikátny v celom App Store; iný sa dá nastaviť cez `TUIST_BUNDLE_ID=…`.
let bundleID = Environment.bundleId.getString(default: "sk.tomasbudac.radio")

/// Tím na podpisovanie, napr. `TUIST_TEAM_ID=ABCDE12345 tuist generate`.
let teamID = Environment.teamId.getString(default: "")

/// Bezplatný osobný tím (Personal Team) nepodporuje Siri ani CarPlay:
/// `TUIST_PERSONAL_TEAM=1 tuist generate` ich vynechá, aby sa appka dala nahrať na iPhone.
let isPersonalTeam = Environment.personalTeam.getBoolean(default: false)

/// Siri vyžaduje platený tím: `TUIST_SIRI=0` ju vypne.
let isSiriEnabled = !isPersonalTeam && Environment.siri.getBoolean(default: true)

/// CarPlay Audio musí tímu najprv schváliť Apple. Kým nie je schválené, na iPhone podpisuj
/// s `TUIST_CARPLAY=0`; v simulátore CarPlay funguje aj bez schválenia.
let isCarPlayEnabled = !isPersonalTeam && Environment.carplay.getBoolean(default: true)

let entitlements: [String: Plist.Value] =
  (isSiriEnabled ? ["com.apple.developer.siri": true] : [:])
    .merging(isCarPlayEnabled ? ["com.apple.developer.carplay-audio": true] : [:]) { $1 }

/// Siri: „Siri, play BBC 1 on Airwaves“ (aj v CarPlay). Bez oprávnenia Siri appka sekciu Siri skryje.
let siriInfoPlist: [String: Plist.Value] = !isSiriEnabled ? [:] : [
  "INIntentsSupported": ["INPlayMediaIntent"],
  "INSupportedMediaCategories": ["INMediaCategoryRadio"],
  "NSSiriUsageDescription": "Siri plays your stations when you ask, for example in the car.",
  // Iné spôsoby, ako môže Siri názov appky počuť alebo ho niekto vysloví.
  "INAlternativeAppNames": [
    ["INAlternativeAppName": "Air Waves", "INAlternativeAppNamePronunciationHint": "air waves"],
    ["INAlternativeAppName": "Airwave", "INAlternativeAppNamePronunciationHint": "air wave"],
    ["INAlternativeAppName": "Airwaves Radio", "INAlternativeAppNamePronunciationHint": "air waves radio"],
  ],
]

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
      bundleId: bundleID,
      deploymentTargets: .iOS("18.0"),
      infoPlist: .extendingDefault(with: siriInfoPlist.merging([
        "CFBundleDisplayName": "Airwaves",
        "CFBundleDevelopmentRegion": "en",
        "CFBundleAllowMixedLocalizations": true,
        // Verzia a build sa nastavujú v build settings nižšie (Xcode ich ukazuje na karte General).
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
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
      ]) { $1 }),
      sources: ["App/Sources/**"],
      resources: ["App/Resources/**"],
      // Oprávnenia Siri a CarPlay Audio vyžadujú platený tím (CarPlay navyše schválenie od Apple).
      entitlements: entitlements.isEmpty ? nil : .dictionary(entitlements),
      dependencies: [
        .package(product: "AppFeature"),
        .package(product: "CarPlayFeature"),
        .package(product: "SiriFeature"),
      ],
      settings: .settings(
        base: [
          // Verzia v App Store; zvyšuj pri každom vydaní.
          "MARKETING_VERSION": "1.0.0",
          // Číslo buildu; pri každom nahratí do App Store Connect / TestFlight musí byť vyššie.
          "CURRENT_PROJECT_VERSION": "1",
        ].merging(teamID.isEmpty ? [:] : ["DEVELOPMENT_TEAM": .string(teamID)]) { $1 }
      )
    )
  ]
)
