import Foundation
import IdentifiedCollections

/// Internetové rádio. Kódovanie (JSON kľúče) je zhodné s webovou aplikáciou, aby sa dali
/// prenášať zálohy obľúbených medzi webom, iOS a Androidom.
public struct Station: Codable, Equatable, Hashable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var url: URL
  public var url2: URL?
  public var favicon: String
  public var homepage: String
  public var country: String
  public var countrycode: String
  public var tags: String
  public var codec: String
  public var bitrate: Int
  public var hls: Bool

  public init(
    id: String,
    name: String,
    url: URL,
    url2: URL? = nil,
    favicon: String = "",
    homepage: String = "",
    country: String = "",
    countrycode: String = "",
    tags: String = "",
    codec: String = "",
    bitrate: Int = 0,
    hls: Bool = false
  ) {
    self.id = id
    self.name = name
    self.url = url
    self.url2 = url2
    self.favicon = favicon
    self.homepage = homepage
    self.country = country
    self.countrycode = countrycode
    self.tags = tags
    self.codec = codec
    self.bitrate = bitrate
    self.hls = hls
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    self.url = try container.decode(URL.self, forKey: .url)
    // Web ukladá prázdny reťazec namiesto chýbajúcej adresy.
    self.url2 = (try? container.decodeIfPresent(URL.self, forKey: .url2)) ?? nil
    self.favicon = try container.decodeIfPresent(String.self, forKey: .favicon) ?? ""
    self.homepage = try container.decodeIfPresent(String.self, forKey: .homepage) ?? ""
    self.country = try container.decodeIfPresent(String.self, forKey: .country) ?? ""
    self.countrycode = try container.decodeIfPresent(String.self, forKey: .countrycode) ?? ""
    self.tags = try container.decodeIfPresent(String.self, forKey: .tags) ?? ""
    self.codec = try container.decodeIfPresent(String.self, forKey: .codec) ?? ""
    self.bitrate = try container.decodeIfPresent(Int.self, forKey: .bitrate) ?? 0
    self.hls = try container.decodeIfPresent(Bool.self, forKey: .hls) ?? false
  }

  /// Ručne pridané rádio nemá záznam v databáze Radio Browser.
  public var isManual: Bool { id.hasPrefix("manual-") }

  /// Adresy streamu v poradí, v akom ich skúšame prehrať.
  public var streamCandidates: [URL] {
    var seen = Set<URL>()
    return [url, url2].compactMap { $0 }.filter { seen.insert($0).inserted }
  }

  /// Iniciály pre náhradné logo, napr. „Rádio Expres“ → „RE“.
  public var initials: String {
    let words = name
      .unicodeScalars
      .filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
      .reduce(into: "") { $0.unicodeScalars.append($1) }
      .split(separator: " ")
    let letters = words.prefix(2).compactMap(\.first).map(String.init).joined()
    return letters.isEmpty ? "?" : letters.uppercased()
  }

  /// Názov krajiny v jazyku zariadenia, ak ho systém pozná.
  public var countryName: String {
    if !countrycode.isEmpty,
      let name = Locale.current.localizedString(forRegionCode: countrycode)
    {
      return name
    }
    return country
  }

  /// Krátky popis do zoznamov: „SK · pop, rock · 128 kbps“.
  public var subtitle: String {
    [countrycode, tags, bitrate > 0 ? "\(bitrate) kbps" : ""]
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
  }

  /// Popis pod názvom v prehrávači.
  public var details: String {
    [countryName, bitrate > 0 ? "\(bitrate) kbps" : ""]
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
  }
}

extension Station {
  /// Aktualizuje údaje, ktoré sa v databáze môžu meniť (adresy, ikony), a ponechá názov,
  /// ktorý si mohol používateľ upraviť.
  public func refreshed(from fresh: Station) -> Station {
    var copy = self
    copy.url = fresh.url
    copy.url2 = fresh.url2
    copy.favicon = fresh.favicon
    copy.homepage = fresh.homepage
    copy.bitrate = fresh.bitrate
    copy.codec = fresh.codec
    copy.hls = fresh.hls
    return copy
  }
}

/// Formát zálohy, kompatibilný s webovou aplikáciou.
public struct FavoritesBackup: Codable, Equatable, Sendable {
  public var app = "radio"
  public var version = 1
  public var favorites: [Station]

  public init(favorites: [Station]) {
    self.favorites = favorites
  }

  /// Web akceptuje objekt `{ favorites: [...] }` aj holé pole staníc.
  public static func decode(_ data: Data) throws -> [Station] {
    let decoder = JSONDecoder()
    if let backup = try? decoder.decode(FavoritesBackup.self, from: data) {
      return backup.favorites
    }
    return try decoder.decode([LossyStation].self, from: data).compactMap(\.station)
  }

  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(self)
  }

  private enum CodingKeys: String, CodingKey {
    case app, version, favorites
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.app = try container.decodeIfPresent(String.self, forKey: .app) ?? "radio"
    self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    self.favorites = try container.decode([LossyStation].self, forKey: .favorites)
      .compactMap(\.station)
  }
}

/// Pokazený záznam v zálohe nesmie zhodiť celý import.
private struct LossyStation: Decodable {
  let station: Station?
  init(from decoder: any Decoder) throws {
    station = try? Station(from: decoder)
  }
}

extension IdentifiedArray where Element == Station, ID == String {
  /// Pridá stanice, ktoré ešte nie sú v obľúbených, a vráti ich počet.
  @discardableResult
  public mutating func merge(_ stations: [Station]) -> Int {
    var added = 0
    for station in stations where self[id: station.id] == nil {
      append(station)
      added += 1
    }
    return added
  }
}

extension Station {
  public static let previews: [Station] = [
    Station(
      id: "preview-expres", name: "Rádio Expres", url: URL(string: "https://example.com/expres")!,
      homepage: "https://www.expres.sk", country: "Slovakia", countrycode: "SK", tags: "pop, hits",
      bitrate: 128
    ),
    Station(
      id: "preview-fm", name: "Rádio FM", url: URL(string: "https://example.com/fm")!,
      homepage: "https://fm.rtvs.sk", country: "Slovakia", countrycode: "SK", tags: "alternative",
      bitrate: 192
    ),
    Station(
      id: "preview-bbc", name: "BBC Radio 1", url: URL(string: "https://example.com/bbc")!,
      homepage: "https://www.bbc.co.uk", country: "United Kingdom", countrycode: "GB",
      tags: "pop, news", bitrate: 320
    ),
  ]
}
