import Foundation
import Models
import Testing

@Suite struct StationTests {
  @Test func decodesWebBackup() throws {
    let json = """
      {
        "app": "radio",
        "version": 1,
        "favorites": [
          {
            "id": "960e57c5-0601-11e8-ae97-52543be04c81",
            "name": "Rádio Expres",
            "url": "https://stream.bauermedia.sk/expres-hi.mp3",
            "url2": "http://stream.bauermedia.sk/expres-hi.mp3",
            "favicon": "https://www.expres.sk/favicon.png",
            "homepage": "https://www.expres.sk",
            "country": "Slovakia",
            "countrycode": "SK",
            "tags": "pop, hits",
            "codec": "MP3",
            "bitrate": 128,
            "hls": false
          },
          {
            "id": "manual-1712345678901",
            "name": "Moje rádio",
            "url": "https://example.com/stream",
            "favicon": "",
            "country": "",
            "countrycode": "",
            "tags": "",
            "codec": "",
            "bitrate": 0
          },
          { "id": "broken" }
        ]
      }
      """
    let stations = try FavoritesBackup.decode(Data(json.utf8))

    #expect(stations.map(\.id) == ["960e57c5-0601-11e8-ae97-52543be04c81", "manual-1712345678901"])
    #expect(stations[0].url2 == URL(string: "http://stream.bauermedia.sk/expres-hi.mp3"))
    #expect(stations[1].isManual)
    #expect(stations[1].url2 == nil)
  }

  @Test func decodesBareArray() throws {
    let json = #"[{"id":"a","name":"A","url":"https://a.example/stream","url2":""}]"#
    let stations = try FavoritesBackup.decode(Data(json.utf8))
    #expect(stations.count == 1)
    #expect(stations[0].url2 == nil)
  }

  @Test func backupRoundTrip() throws {
    let backup = FavoritesBackup(favorites: Station.previews)
    let stations = try FavoritesBackup.decode(backup.encoded())
    #expect(stations == Station.previews)
  }

  @Test func streamCandidatesSkipDuplicates() {
    let url = URL(string: "https://a.example/stream")!
    let station = Station(id: "a", name: "A", url: url, url2: url)
    #expect(station.streamCandidates == [url])
  }

  @Test func initials() {
    let station = Station(id: "a", name: "Rádio Expres!", url: URL(string: "https://a.example")!)
    #expect(station.initials == "RE")
    let empty = Station(id: "b", name: "***", url: URL(string: "https://a.example")!)
    #expect(empty.initials == "?")
  }

  @Test func countryFlag() {
    #expect(Country(code: "SK", name: "Slovensko", stationCount: 1).flag == "🇸🇰")
  }
}
