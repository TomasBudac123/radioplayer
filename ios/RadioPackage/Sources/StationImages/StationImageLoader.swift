import Foundation
import Models
import UIKit

/// Načíta logo rádia. Skúša postupne ikonu z databázy, jej https verziu, ikonu z webu rádia
/// a nakoniec favicon službu. Výsledok (aj neúspech) si pamätá, aby sa nezisťoval opakovane.
public actor StationImageLoader {
  public static let shared = StationImageLoader()

  /// Menšie ikony (napr. 16px favicon) by boli rozmazané.
  private static let minimumSide: CGFloat = 40

  private let session: URLSession
  private var cache: [String: UIImage?] = [:]
  private var pending: [String: Task<UIImage?, Never>] = [:]

  init() {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 8
    configuration.requestCachePolicy = .returnCacheDataElseLoad
    configuration.urlCache = URLCache(
      memoryCapacity: 8 * 1024 * 1024,
      diskCapacity: 64 * 1024 * 1024,
      directory: URL.cachesDirectory.appending(component: "StationImages")
    )
    session = URLSession(configuration: configuration)
  }

  /// Okamžite dostupný výsledok z pamäte; `nil` = ešte nevieme.
  public nonisolated func cached(_ station: Station) -> UIImage?? {
    SnapshotCache.shared.value(for: Self.key(station))
  }

  public func image(for station: Station) async -> UIImage? {
    let key = Self.key(station)
    if let hit = cache[key] { return hit }
    if let task = pending[key] { return await task.value }
    let task = Task { await self.resolve(station) }
    pending[key] = task
    let image = await task.value
    pending[key] = nil
    cache[key] = image
    SnapshotCache.shared.store(image, for: key)
    return image
  }

  private func resolve(_ station: Station) async -> UIImage? {
    for url in Self.candidates(for: station) {
      guard !Task.isCancelled else { return nil }
      if let image = await download(url) { return image }
    }
    return nil
  }

  private func download(_ url: URL) async -> UIImage? {
    guard let (data, response) = try? await session.data(from: url),
      (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
      let image = UIImage(data: data),
      min(image.size.width * image.scale, image.size.height * image.scale) >= Self.minimumSide
    else { return nil }
    return image.preparingForDisplay() ?? image
  }

  static func key(_ station: Station) -> String {
    "\(station.id)|\(station.favicon)|\(station.homepage)"
  }

  static func candidates(for station: Station) -> [URL] {
    var urls: [URL] = []
    let favicon = station.favicon.trimmingCharacters(in: .whitespaces)
    if let url = URL(string: favicon), let scheme = url.scheme?.lowercased() {
      if scheme == "https" {
        urls.append(url)
      } else if scheme == "http" {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        if let secure = components?.url { urls.append(secure) }
        urls.append(url)
      }
    }
    let base = URL(string: station.homepage) ?? station.url
    if let host = base.host(), !host.isEmpty, host.contains(where: \.isLetter) {
      if !station.homepage.isEmpty,
        let touchIcon = URL(string: "https://\(host)/apple-touch-icon.png")
      {
        urls.append(touchIcon)
      }
      let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
      if let favicon = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=256") {
        urls.append(favicon)
      }
    }
    return urls
  }
}

/// Synchrónne čitateľná kópia cache pre prvé vykreslenie bez blikania iniciál.
final class SnapshotCache: @unchecked Sendable {
  static let shared = SnapshotCache()
  private let lock = NSLock()
  private var storage: [String: UIImage?] = [:]

  func value(for key: String) -> UIImage?? {
    lock.withLock { storage[key] }
  }

  func store(_ image: UIImage?, for key: String) {
    lock.withLock { storage[key] = image }
  }
}
