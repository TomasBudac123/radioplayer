import Dependencies
import DependenciesMacros
import Foundation
import L10n
import Models

/// Verejná databáza ~60 000 rádií z celého sveta – https://www.radio-browser.info
@DependencyClient
public struct RadioBrowserClient: Sendable {
  public var countries: @Sendable () async throws -> [Country]
  public var reportClick: @Sendable (_ stationID: String) async -> Void
  public var search: @Sendable (_ query: StationQuery) async throws -> [Station]
  public var stations: @Sendable (_ ids: [String]) async throws -> [Station]
}

extension RadioBrowserClient: DependencyKey {
  public static var liveValue: Self {
    let api = RadioBrowserAPI()
    return Self(
      countries: { try await api.countries() },
      reportClick: { id in _ = try? await api.get("url/\(id)") },
      search: { try await api.search($0) },
      stations: { try await api.stations(ids: $0) }
    )
  }

  public static var previewValue: Self {
    Self(
      countries: { [Country(code: "SK", name: "Slovakia", stationCount: 220)] },
      reportClick: { _ in },
      search: { _ in Station.previews },
      stations: { _ in Station.previews }
    )
  }
}

extension DependencyValues {
  public var radioBrowser: RadioBrowserClient {
    get { self[RadioBrowserClient.self] }
    set { self[RadioBrowserClient.self] = newValue }
  }
}

// MARK: - Live

/// Radio Browser beží na viacerých zrkadlách – ak jedno neodpovedá, skúsime ďalšie
/// a úspešné si zapamätáme ako prvé.
actor RadioBrowserAPI {
  private static let fallbackServers = [
    "de1.api.radio-browser.info", "de2.api.radio-browser.info", "fi1.api.radio-browser.info",
  ]
  private var servers: [String]?
  private let session: URLSession

  init() {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 10
    configuration.httpAdditionalHeaders = ["User-Agent": "Airwaves-iOS/1.0"]
    session = URLSession(configuration: configuration)
  }

  func search(_ query: StationQuery) async throws -> [Station] {
    var items = [
      "hidebroken": "true", "order": "clickcount", "reverse": "true",
      "limit": "\(query.limit)", "offset": "\(query.offset)",
    ]
    let name = query.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty { items["name"] = name }
    if let tag = query.tag { items["tag"] = tag }
    if let code = query.countryCode { items["countrycode"] = code }
    let data = try await get("stations/search", items)
    return try decodeStations(data)
  }

  func stations(ids: [String]) async throws -> [Station] {
    guard !ids.isEmpty else { return [] }
    let data = try await get("stations/byuuid", ["uuids": ids.joined(separator: ",")])
    return try decodeStations(data)
  }

  func countries() async throws -> [Country] {
    let data = try await get("countries", ["hidebroken": "true"])
    let raw = try JSONDecoder().decode([RawCountry].self, from: data)
    let locale = Locale.current
    // Tá istá krajina môže byť v dátach viackrát – zlúčime.
    var merged: [String: Country] = [:]
    for country in raw where country.stationcount > 0 && country.iso_3166_1.count == 2 {
      let code = country.iso_3166_1.uppercased()
      if merged[code] != nil {
        merged[code]?.stationCount += country.stationcount
      } else {
        let name = locale.localizedString(forRegionCode: code) ?? country.name
        merged[code] = Country(code: code, name: name, stationCount: country.stationcount)
      }
    }
    return merged.values.sorted {
      $0.name.compare($1.name, locale: locale) == .orderedAscending
    }
  }

  @discardableResult
  func get(_ path: String, _ items: [String: String] = [:]) async throws -> Data {
    let list = await resolveServers()
    var lastError: any Error = URLError(.cannotFindHost)
    for (index, server) in list.enumerated() {
      var components = URLComponents()
      components.scheme = "https"
      components.host = server
      components.path = "/json/\(path)"
      if !items.isEmpty {
        components.queryItems = items.sorted { $0.key < $1.key }.map(URLQueryItem.init)
      }
      guard let url = components.url else { throw URLError(.badURL) }
      do {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { throw URLError(.badServerResponse) }
        if index > 0 {
          servers = [server] + list.filter { $0 != server }
        }
        return data
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        lastError = error
      }
    }
    throw lastError
  }

  private func resolveServers() async -> [String] {
    if let servers { return servers }
    var resolved = Self.fallbackServers.shuffled()
    if let url = URL(string: "https://all.api.radio-browser.info/json/servers"),
      let (data, _) = try? await session.data(from: url),
      let list = try? JSONDecoder().decode([RawServer].self, from: data),
      !list.isEmpty
    {
      resolved = Array(Set(list.map(\.name))).shuffled()
    }
    servers = resolved
    return resolved
  }

  private func decodeStations(_ data: Data) throws -> [Station] {
    try JSONDecoder().decode([RawStation].self, from: data).compactMap(\.station)
  }
}

private struct RawServer: Decodable {
  let name: String
}

private struct RawCountry: Decodable {
  let name: String
  let iso_3166_1: String
  let stationcount: Int
}

private struct RawStation: Decodable {
  let stationuuid: String
  let name: String?
  let url: String?
  let url_resolved: String?
  let favicon: String?
  let homepage: String?
  let country: String?
  let countrycode: String?
  let tags: String?
  let codec: String?
  let bitrate: Int?
  let hls: Int?

  var station: Station? {
    let resolved = (url_resolved?.isEmpty == false ? url_resolved : url).flatMap(URL.init(string:))
    guard let resolved else { return nil }
    let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return Station(
      id: stationuuid,
      name: trimmedName.isEmpty ? L10n.stationUntitled : trimmedName,
      url: resolved,
      url2: url.flatMap(URL.init(string:)),
      favicon: favicon ?? "",
      homepage: homepage ?? "",
      country: country ?? "",
      countrycode: countrycode ?? "",
      tags: (tags ?? "").split(separator: ",").prefix(3).joined(separator: ", "),
      codec: codec ?? "",
      bitrate: bitrate ?? 0,
      hls: hls == 1
    )
  }
}
