import Foundation

struct iTunesArtworkProvider: ArtworkProvider {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetchArtwork(for identity: NormalizedTrackIdentity) async throws -> Data? {
    guard let searchURL = buildSearchURL(for: identity) else { return nil }

    let (data, response) = try await session.data(from: searchURL)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      return nil
    }

    guard let artworkURLString = parseArtworkURLString(from: data) else { return nil }

    let highResURLString = artworkURLString
      .replacingOccurrences(of: "100x100bb", with: "600x600bb")
    guard let artworkURL = URL(string: highResURLString) else { return nil }

    let (artworkData, artworkResponse) = try await session.data(from: artworkURL)
    guard let artworkHTTP = artworkResponse as? HTTPURLResponse,
          artworkHTTP.statusCode == 200,
          !artworkData.isEmpty else {
      return nil
    }

    return artworkData
  }

  private func buildSearchURL(for identity: NormalizedTrackIdentity) -> URL? {
    var components = URLComponents(string: "https://itunes.apple.com/search")
    let term: String
    if let album = identity.album, !album.isEmpty {
      term = "\(identity.artist) \(album)"
    } else {
      term = "\(identity.artist) \(identity.title)"
    }
    components?.queryItems = [
      URLQueryItem(name: "term", value: term),
      URLQueryItem(name: "entity", value: "album"),
      URLQueryItem(name: "limit", value: "5")
    ]
    return components?.url
  }

  private func parseArtworkURLString(from data: Data) -> String? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let results = json["results"] as? [[String: Any]],
          let first = results.first,
          let artworkURLString = first["artworkUrl100"] as? String else {
      return nil
    }
    return artworkURLString
  }
}
