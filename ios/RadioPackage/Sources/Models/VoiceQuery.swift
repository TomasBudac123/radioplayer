import Foundation

/// Porovnávanie hlasových príkazov („pusti Expres“, „jazz“) s rádiami a žánrami.
/// Rovnaké pravidlá používa aj Android aplikácia.
public enum VoiceQuery {
  /// Malé písmená bez diakritiky a bez slov ako „rádio“, ktoré Siri často pridá.
  public static func normalize(_ text: String) -> String {
    let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    let words = folded
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
    let meaningful = words.filter { !fillerWords.contains($0) }
    // Rádio s názvom „Rádio FM“ nesmie skončiť ako prázdny reťazec.
    return (meaningful.isEmpty ? words : meaningful).joined(separator: " ")
  }

  /// Sila zhody pre presne zhodný názov.
  public static let exact = 3

  /// Najlepšie zodpovedajúce obľúbené rádio, ak je zhoda dostatočne istá.
  public static func bestFavorite(for query: String, in favorites: [Station]) -> Station? {
    bestFavoriteMatch(for: query, in: favorites)?.station
  }

  /// Obľúbené rádio aj sila zhody (3 = presná, 2 = čiastočná, 1 = slová).
  public static func bestFavoriteMatch(for query: String, in favorites: [Station]) -> (station: Station, score: Int)? {
    let needle = normalize(query)
    guard !needle.isEmpty else { return nil }
    return favorites
      .map { (station: $0, score: score(needle, normalize($0.name))) }
      .filter { $0.score > 0 }
      .max { $0.score < $1.score }
  }

  /// Žáner, ktorého názov (v jazyku zariadenia alebo anglický tag) zodpovedá príkazu.
  public static func genre(matching query: String) -> Genre? {
    let needle = normalize(query)
    guard !needle.isEmpty else { return nil }
    return Genre.all.first { normalize($0.name) == needle || normalize($0.tag) == needle }
  }

  /// 3 = presná zhoda, 2 = jeden názov obsahuje druhý, 1 = všetky slová príkazu sú v názve.
  static func score(_ needle: String, _ name: String) -> Int {
    guard !name.isEmpty else { return 0 }
    if needle == name { return 3 }
    if name.contains(needle) || needle.contains(name) { return 2 }
    let nameWords = Set(name.split(separator: " "))
    let needleWords = needle.split(separator: " ")
    return needleWords.allSatisfy(nameWords.contains) ? 1 : 0
  }

  private static let fillerWords: Set<String> = [
    "radio", "radia", "radiu", "radiom", "station", "stanica", "stanicu", "sender", "emisora", "stazione",
    "stacja", "stacje", "allomas", "the",
  ]
}
