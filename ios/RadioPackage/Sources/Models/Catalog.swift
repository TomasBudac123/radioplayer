import Foundation
import L10n

/// Žáner – surové tagy v Radio Browser sú nejednotné, preto ponúkame overený zoznam (rovnaký ako web).
public struct Genre: Equatable, Hashable, Identifiable, Sendable {
  public var id: String { tag }
  public let tag: String
  public let symbol: String

  public init(tag: String, symbol: String = "music.note") {
    self.tag = tag
    self.symbol = symbol
  }

  /// Názov v jazyku zariadenia.
  public var name: String { L10n.genre(tag) }

  public static let all: [Genre] = [
    Genre(tag: "alternative", symbol: "guitars"),
    Genre(tag: "pop", symbol: "music.mic"),
    Genre(tag: "rock", symbol: "guitars"),
    Genre(tag: "hits", symbol: "star"),
    Genre(tag: "top 40", symbol: "chart.bar"),
    Genre(tag: "news", symbol: "newspaper"),
    Genre(tag: "talk", symbol: "bubble.left.and.bubble.right"),
    Genre(tag: "sport", symbol: "sportscourt"),
    Genre(tag: "dance", symbol: "figure.dance"),
    Genre(tag: "electronic", symbol: "waveform"),
    Genre(tag: "house", symbol: "waveform"),
    Genre(tag: "techno", symbol: "waveform"),
    Genre(tag: "trance", symbol: "waveform"),
    Genre(tag: "chillout", symbol: "leaf"),
    Genre(tag: "lounge", symbol: "sofa"),
    Genre(tag: "ambient", symbol: "cloud"),
    Genre(tag: "jazz", symbol: "music.quarternote.3"),
    Genre(tag: "blues", symbol: "music.quarternote.3"),
    Genre(tag: "soul", symbol: "music.quarternote.3"),
    Genre(tag: "funk", symbol: "music.quarternote.3"),
    Genre(tag: "rnb", symbol: "music.mic"),
    Genre(tag: "hip hop", symbol: "music.mic"),
    Genre(tag: "classical", symbol: "pianokeys"),
    Genre(tag: "soundtrack", symbol: "film"),
    Genre(tag: "oldies", symbol: "clock.arrow.circlepath"),
    Genre(tag: "60s", symbol: "clock.arrow.circlepath"),
    Genre(tag: "70s", symbol: "clock.arrow.circlepath"),
    Genre(tag: "80s", symbol: "clock.arrow.circlepath"),
    Genre(tag: "90s", symbol: "clock.arrow.circlepath"),
    Genre(tag: "2000s", symbol: "clock.arrow.circlepath"),
    Genre(tag: "disco", symbol: "sparkles"),
    Genre(tag: "classic rock", symbol: "guitars"),
    Genre(tag: "metal", symbol: "bolt"),
    Genre(tag: "punk", symbol: "bolt"),
    Genre(tag: "indie", symbol: "guitars"),
    Genre(tag: "country", symbol: "music.note"),
    Genre(tag: "folk", symbol: "music.note"),
    Genre(tag: "reggae", symbol: "sun.max"),
    Genre(tag: "latin", symbol: "sun.max"),
    Genre(tag: "world", symbol: "globe"),
    Genre(tag: "christian", symbol: "music.note"),
    Genre(tag: "kids", symbol: "teddybear"),
    Genre(tag: "comedy", symbol: "face.smiling"),
    Genre(tag: "public radio", symbol: "building.columns"),
  ]

  public static func named(_ tag: String) -> Genre? {
    all.first { $0.tag == tag }
  }
}

public struct Country: Equatable, Hashable, Identifiable, Sendable {
  public var id: String { code }
  public let code: String
  public let name: String
  public var stationCount: Int

  public init(code: String, name: String, stationCount: Int) {
    self.code = code
    self.name = name
    self.stationCount = stationCount
  }

  /// Vlajka z ISO kódu krajiny, napr. „SK“ → 🇸🇰.
  public var flag: String {
    guard code.count == 2, code.allSatisfy(\.isASCII) else { return "" }
    return String(
      String.UnicodeScalarView(
        code.uppercased().unicodeScalars.compactMap { Unicode.Scalar(0x1F1A5 + $0.value) }
      )
    )
  }
}

/// Parametre hľadania v databáze rádií.
public struct StationQuery: Equatable, Hashable, Sendable {
  public var name = ""
  public var countryCode: String?
  public var tag: String?
  public var offset = 0
  public var limit = 40

  public init(name: String = "", countryCode: String? = nil, tag: String? = nil, offset: Int = 0, limit: Int = 40) {
    self.name = name
    self.countryCode = countryCode
    self.tag = tag
    self.offset = offset
    self.limit = limit
  }

  public var isFiltered: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty || tag != nil
  }
}
