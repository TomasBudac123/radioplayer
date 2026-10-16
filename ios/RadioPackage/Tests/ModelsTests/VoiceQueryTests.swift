import Foundation
import Models
import Testing

@Suite struct VoiceQueryTests {
  let favorites = [
    Station(id: "expres", name: "Rádio Expres", url: URL(string: "https://a.example")!),
    Station(id: "fm", name: "Rádio FM", url: URL(string: "https://b.example")!),
    Station(id: "bbc", name: "BBC Radio 1", url: URL(string: "https://c.example")!),
  ]

  @Test func normalizeFoldsDiacriticsAndFillerWords() {
    #expect(VoiceQuery.normalize("Rádio Expres!") == "expres")
    #expect(VoiceQuery.normalize("Rádio FM") == "fm")
    #expect(VoiceQuery.normalize("  BBC   Radio 1 ") == "bbc 1")
  }

  @Test func matchesFavoritesBySpokenName() {
    #expect(VoiceQuery.bestFavorite(for: "expres", in: favorites)?.id == "expres")
    #expect(VoiceQuery.bestFavorite(for: "radio expres", in: favorites)?.id == "expres")
    #expect(VoiceQuery.bestFavorite(for: "Rádio FM", in: favorites)?.id == "fm")
    #expect(VoiceQuery.bestFavorite(for: "BBC Radio One", in: favorites) == nil)
    #expect(VoiceQuery.bestFavorite(for: "bbc", in: favorites)?.id == "bbc")
    #expect(VoiceQuery.bestFavorite(for: "Jazz", in: favorites) == nil)
  }

  @Test func matchesGenresByTag() {
    #expect(VoiceQuery.genre(matching: "jazz")?.tag == "jazz")
    #expect(VoiceQuery.genre(matching: "Classic Rock")?.tag == "classic rock")
    #expect(VoiceQuery.genre(matching: "Expres") == nil)
  }
}
