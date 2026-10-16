import ComposableArchitecture
import Foundation
import Models

extension SharedKey where Self == FileStorageKey<IdentifiedArrayOf<Station>>.Default {
  /// Obľúbené rádiá v poradí, ktoré si určil používateľ.
  public static var favorites: Self {
    Self[.fileStorage(.documentsDirectory.appending(component: "favorites.json")), default: []]
  }
}

extension SharedKey where Self == FileStorageKey<Station?>.Default {
  /// Naposledy hrané rádio – po spustení je pripravené v prehrávači.
  public static var lastStation: Self {
    Self[.fileStorage(.documentsDirectory.appending(component: "last-station.json")), default: nil]
  }
}

extension SharedKey where Self == InMemoryKey<Playback>.Default {
  /// Čo práve hrá. Zapisuje len `Player`, ostatné obrazovky a CarPlay čítajú.
  public static var playback: Self {
    Self[.inMemory("playback"), default: Playback()]
  }
}
