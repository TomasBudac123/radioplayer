import AppFeature
import CarPlay
import ComposableArchitecture
import L10n
import Models
import RadioBrowserClient
import StationImages
import UIKit
import UIKitNavigation

/// CarPlay rozhranie: Obľúbené, Populárne a Žánre + systémová obrazovka „Teraz hrá“.
/// Zdieľa jeden `Store` s telefónom, takže obľúbené aj prehrávanie sú všade rovnaké.
@MainActor
public final class CarPlayController: NSObject {
  private let interfaceController: CPInterfaceController
  private let store: StoreOf<AppFeature>
  @Dependency(\.radioBrowser) private var radioBrowser

  private let favoritesTemplate: CPListTemplate
  private let popularTemplate: CPListTemplate
  private let genresTemplate: CPListTemplate
  private var observations: [ObserveToken] = []
  /// Všetky zobrazené položky podľa ID rádia – kvôli indikátoru prehrávania.
  private var items: [String: [WeakItem]] = [:]
  private var renderedFavorites: [Station] = []
  private var renderedIsFavorite: Bool?
  private var imageTasks: [Task<Void, Never>] = []

  public init(interfaceController: CPInterfaceController, store: StoreOf<AppFeature>) {
    self.interfaceController = interfaceController
    self.store = store

    favoritesTemplate = CPListTemplate(title: L10n.tabFavorites, sections: [])
    favoritesTemplate.tabTitle = L10n.tabFavorites
    favoritesTemplate.tabImage = UIImage(systemName: "star.fill")
    favoritesTemplate.emptyViewTitleVariants = [L10n.favoritesEmptyTitle]
    favoritesTemplate.emptyViewSubtitleVariants = [L10n.carFavoritesEmptySubtitle]

    popularTemplate = CPListTemplate(title: L10n.tabPopular, sections: [])
    popularTemplate.tabTitle = L10n.tabPopular
    popularTemplate.tabImage = UIImage(systemName: "chart.bar.fill")
    popularTemplate.emptyViewTitleVariants = [L10n.carLoading]

    genresTemplate = CPListTemplate(title: L10n.tabGenres, sections: [])
    genresTemplate.tabTitle = L10n.tabGenres
    genresTemplate.tabImage = UIImage(systemName: "music.note.list")

    super.init()

    // Tlačidlo „Pustiť cez Siri“ na vrchu zoznamov – v aute sa hľadá hlasom, nie klávesnicou.
    for template in [favoritesTemplate, popularTemplate, genresTemplate] {
      template.assistantCellConfiguration = Self.assistantCell
    }
  }

  private static var assistantCell: CPAssistantCellConfiguration {
    CPAssistantCellConfiguration(position: .top, visibility: .always, assistantAction: .playMedia)
  }

  public func connect() {
    genresTemplate.updateSections([CPListSection(items: genreItems())])

    let tabBar = CPTabBarTemplate(templates: [favoritesTemplate, popularTemplate, genresTemplate])
    interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)

    configureNowPlaying()
    observations.append(observe { [weak self] in self?.render() })
    loadPopular()
  }

  public func disconnect() {
    observations.removeAll()
    imageTasks.forEach { $0.cancel() }
    imageTasks.removeAll()
  }

  // MARK: - Rendering

  private func render() {
    let favorites = Array(store.favorites.favorites)
    let playback = store.player.playback
    let isFavorite = store.player.isFavorite

    if favorites != renderedFavorites {
      renderedFavorites = favorites
      let items = favorites.map { station in
        stationItem(station, queue: favorites)
      }
      favoritesTemplate.updateSections([CPListSection(items: items)])
    }
    updatePlayingIndicators(playback)

    if renderedIsFavorite != isFavorite {
      renderedIsFavorite = isFavorite
      let symbol = isFavorite ? "star.fill" : "star"
      let button = CPNowPlayingImageButton(image: UIImage(systemName: symbol)!) { [weak self] _ in
        self?.store.send(.player(.favoriteButtonTapped))
      }
      CPNowPlayingTemplate.shared.updateNowPlayingButtons([button])
    }
  }

  private func updatePlayingIndicators(_ playback: Playback) {
    for (id, entries) in items {
      let isPlaying = playback.station?.id == id && playback.isActive
      for entry in entries {
        guard let item = entry.item else { continue }
        if item.isPlaying != isPlaying { item.isPlaying = isPlaying }
      }
    }
    items = items.mapValues { $0.filter { $0.item != nil } }.filter { !$0.value.isEmpty }
  }

  private func stationItem(_ station: Station, queue: [Station]) -> CPListItem {
    let placeholder = Self.placeholderImage(for: station)
    let cached = StationImageLoader.shared.cached(station) ?? nil
    let item = CPListItem(text: station.name, detailText: station.subtitle, image: cached ?? placeholder)
    item.playingIndicatorLocation = .trailing
    item.isPlaying = store.player.playback.station?.id == station.id && store.player.playback.isActive
    item.handler = { [weak self] _, completion in
      self?.stationSelected(station, queue: queue)
      completion()
    }
    items[station.id, default: []].append(WeakItem(item: item))
    if cached == nil {
      imageTasks.append(
        Task { [weak item] in
          guard let image = await StationImageLoader.shared.image(for: station) else { return }
          item?.setImage(Self.resized(image))
        }
      )
    }
    return item
  }

  private func stationSelected(_ station: Station, queue: [Station]) {
    let playback = store.player.playback
    if playback.station?.id == station.id, playback.isActive {
      // Rovnaké rádio už hrá – len ukážeme prehrávač.
    } else {
      store.send(.player(.playRequested(station, queue: queue)))
    }
    showNowPlaying()
  }

  private func showNowPlaying() {
    guard !(interfaceController.topTemplate is CPNowPlayingTemplate) else { return }
    interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
  }

  private func configureNowPlaying() {
    let template = CPNowPlayingTemplate.shared
    template.isUpNextButtonEnabled = false
    template.isAlbumArtistButtonEnabled = false
  }

  // MARK: - Popular & genres

  private func loadPopular() {
    let region = Locale.current.region?.identifier
    let countryName = region.flatMap { Locale.current.localizedString(forRegionCode: $0) }
    imageTasks.append(
      Task { [weak self, radioBrowser] in
        async let local = Self.popular(in: region, radioBrowser: radioBrowser)
        async let world = Self.popular(in: nil, radioBrowser: radioBrowser)
        let (localStations, worldStations) = await (region == nil ? [] : local, world)
        guard let self else { return }
        var sections: [CPListSection] = []
        if !localStations.isEmpty {
          sections.append(
            CPListSection(
              items: localStations.map { self.stationItem($0, queue: localStations) },
              header: countryName ?? L10n.carYourCountry,
              sectionIndexTitle: nil
            )
          )
        }
        if !worldStations.isEmpty {
          sections.append(
            CPListSection(
              items: worldStations.map { self.stationItem($0, queue: worldStations) },
              header: L10n.searchWholeWorld,
              sectionIndexTitle: nil
            )
          )
        }
        self.popularTemplate.emptyViewTitleVariants = [L10n.carLoadFailed]
        self.popularTemplate.emptyViewSubtitleVariants = [L10n.carCheckConnection]
        self.popularTemplate.updateSections(sections)
      }
    )
  }

  private nonisolated static func popular(
    in countryCode: String?,
    radioBrowser: RadioBrowserClient
  ) async -> [Station] {
    (try? await radioBrowser.search(StationQuery(countryCode: countryCode, limit: 25))) ?? []
  }

  private func genreItems() -> [CPListItem] {
    Genre.all.map { genre in
      let item = CPListItem(
        text: genre.name,
        detailText: nil,
        image: UIImage(systemName: genre.symbol),
        accessoryImage: nil,
        accessoryType: .disclosureIndicator
      )
      item.handler = { [weak self] _, completion in
        self?.genreSelected(genre, completion: completion)
      }
      return item
    }
  }

  private func genreSelected(_ genre: Genre, completion: @escaping () -> Void) {
    Task { [radioBrowser] in
      let stations = (try? await radioBrowser.search(StationQuery(tag: genre.tag, limit: 50))) ?? []
      let template = CPListTemplate(
        title: genre.name,
        sections: [CPListSection(items: stations.map { self.stationItem($0, queue: stations) })]
      )
      template.emptyViewTitleVariants = [L10n.carLoadFailed]
      template.assistantCellConfiguration = Self.assistantCell
      self.interfaceController.pushTemplate(template, animated: true, completion: nil)
      completion()
    }
  }

  // MARK: - Images

  private static func placeholderImage(for station: Station) -> UIImage {
    let size = CPListItem.maximumImageSize
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      UIColor(white: 0.22, alpha: 1).setFill()
      UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6).fill()
      let text = station.initials as NSString
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: size.height * 0.36, weight: .semibold),
        .foregroundColor: UIColor(white: 0.85, alpha: 1),
      ]
      let textSize = text.size(withAttributes: attributes)
      text.draw(
        at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
        withAttributes: attributes
      )
    }
  }

  private static func resized(_ image: UIImage) -> UIImage {
    let size = CPListItem.maximumImageSize
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      let scale = min(size.width / image.size.width, size.height / image.size.height)
      let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
      image.draw(
        in: CGRect(
          x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
          width: drawn.width, height: drawn.height
        )
      )
    }
  }
}

private struct WeakItem {
  weak var item: CPListItem?
}
